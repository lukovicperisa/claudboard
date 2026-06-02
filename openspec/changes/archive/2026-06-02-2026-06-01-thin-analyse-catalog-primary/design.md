## Context

The 2026-05-30 `speed-up-analyse` change consolidated discovery into one `discover.sh` invocation, gated reference loading, made elastic phases truly elastic, and trimmed the analyse SKILL.md from 1035 → 724 lines. Those wins held on the workloads the proposal targeted (single-project Sonnet runs). But a 2026-06-01 measurement against craftsphere.cloud — 19 services, real-world monorepo, default Opus 4.7 tier — produced **$417.66 in 13 minutes** with the optimised pipeline.

Forensic breakdown verified by `compute-cost.sh` (requestId-deduped):
- Orchestrator: $122 (91% cache_write_5m churn driven by idle-wait between sub-agent returns)
- Sub-agents: $296 across 19 parallel Opus 4.7 agents, each writing its own ~70K prompt cache

The same forensic pass surfaced two findings that recast the problem from "make `/analyse` faster/cheaper" to "the analyse→generate value chain has the wrong shape":

1. **Claude Code does not auto-load `.claude/reports/*.md` during normal sessions.** They are read only by `/generate`, `/refresh`, `/techdebt`, and humans. Of the $417 spent, $0 contributes to feature-workflow runtime context. The reports are intermediate build state, not runtime artifacts.

2. **`/generate` consumes ~20% of per-service report content.** Walking `skills/claudboard-generate/SKILL.md` and `skills/claudboard/references/skill-generation.md`, the actually-used inputs are: deduplicated convention/pattern catalog, "best-example" file path per skill trigger, adaptive-depth signal per stack. Per-service Watch findings, cross-service Kafka maps, quality breakdowns, and call-path tracing are **not** consumed by generation — they are audit outputs served to a different audience on a different cadence.

The two products (generative input vs audit detail) have conflicting economics:

| | Generative use (→ `/generate`) | Audit use (→ human review) |
|---|---|---|
| Frequency | Every onboarding + refresh | Quarterly, per audit cycle |
| Depth | Representative samples + canonical patterns | Full breadth, all services |
| Cost ceiling | "Cheap enough per repo" — $50-150 | "Expensive but rare" — $200-500 |
| Right output shape | Convention catalog (1 entry per pattern) | Per-service report (1 per service) |
| Should it block onboarding? | YES (it IS the onboarding) | NO (separate skill, opt-in) |

Conflating them charges audit prices for every onboarding run. The fix is structural: split the products, name the primary artifact (the catalog), and tier model usage so that audit-grade work pays audit-grade compute.

## Goals / Non-Goals

**Goals:**
- Make default `/analyse` economically usable on real-world monorepos (~$100-150 on a 19-service repo vs measured $417).
- Promote the convention catalog from implicit aggregation to a first-class, validatable, version-pinned JSON artifact.
- Preserve all per-service audit value (the Quarkus / RTK / library-drift / PII-logging findings from the craftsphere.cloud run remain reachable via `--audit`).
- Reduce `/generate` cost by ~50% via Sonnet tier and a thinner input surface.
- Make the build-state vs runtime-context separation visible in the filesystem (catalog and audit outputs leave `.claude/`).

**Non-Goals:**
- Redesigning `/refresh` (separate follow-up; the catalog makes that work much smaller).
- Cost preview / cost-aware scope prompts in `AskUserQuestion`.
- Fixing the plugin-namespace gate bug in the `cost-reporting` stop hook (separate capability).
- Workspace-mode catalog adaptation (workspace has different invariants; deserves its own design).
- Calibration table or cost-history file for projecting costs ahead of run.
- Tier-aggressiveness configuration (`--tier=aggressive` for Haiku stages). Conservative tier ships now; iterate if measurements support.
- Auto-running `--audit` on any schedule. Opt-in only, like `/techdebt`.

## Decisions

### D1. The catalog is a strict JSON document with a versioned schema, not structured markdown

Two options considered:

- **(A) Strict JSON** at `.claudboard/catalog.json` with a published JSON Schema. Validatable. Consumers parse, never edit. Schema versioning makes drift detectable. Harder to hand-edit (intentionally — humans should edit upstream sources).
- **(B) Structured markdown section** inside `.claude/reports/claudboard-analysis.md`. Easier to read and hand-edit. Parsing is fuzzy; schema discipline is weaker. Encourages "just tweak the report" anti-patterns.

**Decision: Option A.** The catalog is the contract between three skills (`/analyse`, `/generate`, future `/refresh`); contract discipline matters more than hand-editability. The companion human-readable summary (`claudboard-analysis.md`) remains markdown — the catalog's job is to be machine-correct, the report's job is to be human-readable. Schema versioning follows the same pattern as `discover.sh` (`schema_version: "1"`, consumer asserts match).

### D2. Catalog location is `.claudboard/`, outside `.claude/`

Three options considered:

- **(A) `.claudboard/catalog.json`** — new sibling dir to `.claude/`. Makes "build-state, not runtime context" visible in the filesystem. Mirrors `openspec/` convention (also outside `.claude/`).
- **(B) `.claude/state/catalog.json`** — inside `.claude/` but under a `state/` subdirectory. Easier discoverability. Slightly muddies "what gets loaded vs what is build state."
- **(C) `.claude/reports/catalog.json`** — alongside existing reports. Minimal layout change. Encourages the conflation we're trying to break.

**Decision: Option A.** The filesystem layout signals the architectural distinction. `.claude/` becomes "what Claude Code loads at runtime" (CLAUDE.md, rules, skills, memories, settings); `.claudboard/` becomes "build state produced by claudboard skills" (catalog, audits, intermediate discovery output). Mirrors the established `openspec/` convention and reinforces the empirical finding that `.claude/reports/` was never auto-loaded anyway.

### D3. Per-service reports move from `.claude/reports/` to `.claudboard/audits/`

Audit detail is build state, not runtime context (same logic as D2). Co-locating audits with the catalog under `.claudboard/` keeps build state in one place. Renaming the directory from `reports/` to `audits/` underscores the change in semantics — these aren't reports anyone is reading on the runtime path; they're audit findings produced on opt-in cadence.

Path mapping during migration:
- Old: `.claude/reports/claudboard-analysis.md` → New: `.claude/reports/claudboard-analysis.md` (kept — this is the human-readable summary, still useful for the onboarding "what did /analyse find" recap)
- Old: `.claude/reports/claudboard-analysis-<svc>.md` → New: `.claudboard/audits/<svc>.md` (moved, only produced by `--audit`)
- New: `.claudboard/catalog.json` (catalog primary artifact)

### D4. Default `/analyse` produces catalog + thin global summary; `--audit` adds per-service reports

Two phasing options were considered:

- **(A) Hard split**: default mode produces only `.claudboard/catalog.json`; `--audit` is an entirely separate execution that produces per-service reports. No overlap.
- **(B) Soft split**: default mode produces catalog + a one-page human-readable global summary (`claudboard-analysis.md`); `--audit` additionally produces per-service reports.

**Decision: Option B.** The human-readable summary is cheap (the orchestrator already does the synthesis to build the catalog; emitting a markdown summary alongside costs essentially nothing) and provides a useful "what did /analyse find" artifact for the user's review before running `/generate`. Keeps the existing review checkpoint in the onboarding flow. The hard distinction is **per-service detail = `--audit`**, not "no human-readable output by default."

### D5. Asymmetric model tiering: orchestrator Opus, sub-agents Sonnet, /generate Sonnet, no Haiku

Three tier options were considered:

- **(A) Conservative two-tier**: orchestrator Opus, everything else Sonnet. Predictable. Sonnet on template-fill is well-understood. ~50% cost reduction with tier swap alone.
- **(B) Aggressive three-tier**: discovery/extraction Haiku, synthesis Opus, generation Sonnet. ~85% cost reduction. Quality risk on Haiku for convention extraction (the "useridentities-sidecar is Quarkus" type findings) is real and untested.
- **(C) Configurable `--tier=aggressive` flag**: ship conservative default, expose aggressive opt-in. Most flexibility, adds a knob.

**Decision: Option A.** The user-confirmed preference: no Haiku, Sonnet for sub-agent extraction. Rationale: convention extraction needs enough pattern-matching depth that Haiku's quality floor is uncomfortable without empirical validation; Sonnet is well-understood and cheap enough. The aggressive tier remains a future option (Out of Scope here) — once the catalog architecture lands, switching extraction to Haiku is a one-line SKILL.md edit. Ship the structural change first, then iterate on tiering with calibration data in hand.

Concrete tier assignments (documented in the modified `analyse-performance` spec):

| Stage | Tier | Why |
|---|---|---|
| `discover.sh` (bash) | n/a | Deterministic script, no model |
| Sub-agent per-service extraction (`--audit` only) | Sonnet | Template-fill on file contents; well within Sonnet's competence |
| Orchestrator catalog synthesis | Opus | Cross-service pattern dedup and outlier detection — actual intelligence work |
| Orchestrator outlier detection sweep | Opus | Pattern-recognition: "this service deviates from the canonical convention" |
| `/generate` rendering (CLAUDE.md, rules, skills) | Sonnet | Template-fill on structured catalog input |

### D6. Cost-model claims are stated explicitly in the proposal and tested before merge

Past proposals (notably `speed-up-analyse`) made cost claims grounded in a specific baseline (Sonnet, single-project) that did not generalise. Tasks.md includes explicit acceptance criteria:

- Default `/analyse` on craftsphere.cloud completes for **≤$150**.
- `/analyse --audit` on craftsphere.cloud completes for **≤$250** (down from measured $417).
- `/generate` on craftsphere.cloud completes for **≤$25**.
- Generated `.claude/` artifacts (CLAUDE.md, rules, skills) produced by catalog-driven `/generate` are substantively equivalent to those produced by full-reports-driven `/generate` (diff review).

Numbers are based on the asymmetric tier of D5 and the catalog input shape. If measured numbers exceed these caps at merge time, the proposal is revised, not shipped — claims must be honest at write time.

### D7. Catalog schema is published as a JSON Schema document, not inline-in-SKILL.md

The catalog is a contract. Contracts deserve formal specs. `skills/claudboard/references/catalog-schema.json` is the canonical schema; `skills/claudboard/references/catalog-format.md` is the human explainer. The analyse SKILL.md references both but does not duplicate the field list (a) to avoid drift and (b) to keep the SKILL.md size budget intact (the May 30 work brought it from 1035 → 724 lines; this change should not undo that).

### D8. Migration path is one-time, opportunistic, in `/generate`

Projects that already ran `/analyse` (legacy) have `.claude/reports/claudboard-analysis.md` plus optional `claudboard-analysis-<svc>.md` files. Without a migration path, these users get a "no catalog found" error.

**Decision: `/generate` synthesises a catalog from legacy reports on first invocation post-change.** Detection: `.claudboard/catalog.json` absent AND `.claude/reports/claudboard-analysis.md` present. Action: read the existing reports, extract the proposed-artifacts list and convention summaries, write a catalog, then proceed with normal catalog-driven generation. One log line tells the user the migration happened. Subsequent runs see the catalog and skip the migration.

Old per-service reports stay on disk untouched — the user can delete them manually or run `--audit` to refresh them under the new path. The migration writes the catalog only; it does not move or delete existing files.

### D9. `/techdebt` and `/claudboard-workflow` are not modified in this change

Both skills operate on their own data sources (`/techdebt` does its own scanning; `/claudboard-workflow` generates a workflow skill template, not consuming analyse output). Neither is on the analyse→generate hot path. Leaving them untouched keeps the change tightly scoped to the actual problem.

### D10. Workspace mode behaviour is preserved, with a marker for follow-up

Workspace mode (multi-repo, per-repo `.git/`) writes per-repo reports under `<workspace>/.claude/reports/`. The catalog approach extends naturally — one catalog per repo, plus an optional workspace-level rollup — but the design space is non-trivial (where does the rollup live? does the workspace report directory also move to `.claudboard/`? what's the per-repo orchestrator tier?). Rather than ship a half-considered workspace adaptation, this change explicitly preserves current workspace behaviour and marks the adaptation as a follow-up. The `analyse-performance` spec MODIFIED section calls this out.

## Risks / Trade-offs

- **[Catalog incompleteness for `/generate`]** If the catalog produced by default `/analyse` lacks fields `/generate` needs, generation degrades silently or errors opaquely. **→ Mitigation:** strict JSON Schema validation in both writer (`/analyse`) and reader (`/generate`); errors name the missing field and the producer; required-vs-optional fields explicitly marked in `catalog-format.md`. D7's published schema is the single source of truth.

- **[Sonnet quality drop on `/generate` SKILL.md authoring]** SKILL.md generation involves real creativity (architecture diagrams, prose explanations of canonical patterns). Sonnet handles template-fill well, but creative SKILL.md authoring is one place Opus arguably helps. **→ Mitigation:** D6's acceptance criterion — diff catalog-driven Sonnet generation vs current full-reports-driven generation on craftsphere.cloud must be substantively equivalent. If tests show meaningful degradation, the `/generate` tier decision is revisited before merge (could keep `/generate` on Opus for SKILL.md generation while moving rules + CLAUDE.md to Sonnet).

- **[Audit fades from default workflow → audit findings get stale]** With `--audit` opt-in, teams may run it once and never again, losing visibility into per-service quality drift (the gdpr-service PII issues, the Mailjet @Recover silent-failure, the library-version drift findings). **→ Mitigation:** documented in generated CLAUDE.md as a recommended quarterly task. Future change can add a staleness check or scheduled-reminder hook. Not in v1.

- **[Catalog vs report shape drift over time]** Two artifacts describing the same codebase can drift. Audit reports could say "service X uses convention Y" while the catalog says "all services use convention Z." **→ Mitigation:** when `--audit` runs, both the catalog and the audit reports are produced in the same orchestrator pass — the catalog is derived from the same data the audits draw on. Catalog has `generated_at` and `from_audit: bool` fields so consumers can detect "this catalog was synthesised without audit data" vs "this catalog and these audits are sibling outputs of the same run."

- **[Cache-write churn during `--audit` fan-out persists]** Even with Sonnet sub-agents, the orchestrator still suffers cache_write_5m churn during the multi-minute wait for sub-agents to return — exactly the dynamic that drove $111 of the original $122 orchestrator bill. **→ Mitigation:** acknowledged as residual; addressing it requires either harness-level cache-TTL configuration (currently not exposed in the Claude Code SDK) or wave-batched fan-out (more complex orchestration). Deferred to follow-up. The asymmetric tier already brings the audit-mode cost down to ~$200-250 from $417; further cache work is incremental optimisation on the smaller pie.

- **[Migration path requires legacy report content to be parseable]** D8's one-time migration extracts catalog content from existing `.claude/reports/claudboard-analysis*.md`. If reports were hand-edited or are from a much older claudboard version with different section structure, migration may fail. **→ Mitigation:** migration is best-effort. If parsing fails, `/generate` emits a clear message: "Could not migrate from legacy reports — run `/analyse` to produce a fresh catalog." The user re-runs `/analyse` (now cheap) and continues. Worst case is one extra command, not data loss.

- **[Filesystem layout change requires teammate communication]** Moving from `.claude/reports/claudboard-analysis-<svc>.md` to `.claudboard/audits/<svc>.md` breaks any teammate documentation, scripts, or bookmarks pointing at the old paths. **→ Mitigation:** changelog entry in CLAUDE.md after generation, documented in the change's tasks.md "Communication" section. Old reports are not deleted, so prior runs' artifacts remain at their old paths — only new outputs land at new paths.

- **[Test budget for the change itself]** Validating cost claims requires actually running `/analyse` (default + `--audit`) on craftsphere.cloud, plus running `/generate` against catalog-only vs full-reports inputs, plus diffing outputs. Each test run is real money (~$50-150 per analyse, ~$10-25 per generate). **→ Mitigation:** D6's acceptance criteria are tested with one full pass per scenario; total validation budget ~$300-500. This is the cost of proving the claims in the proposal hold — a small fraction of the $417 saved per future onboarding run.

## Validation (2026-06-02)

Measured on craftsphere.cloud (12 backend services + 7 frontend MFEs + 1 BFF + 1 shared library, 19 build roots). All cost figures are Bosch Vertex rates as billed (see `skills/claudboard/references/pricing.md`); `/cost` and `compute-cost.sh` agree to within rounding after the 2026-06-02 pricing update.

| Task | Acceptance | Measured | Status |
|---|---|---|---|
| 6.1 Default `/analyse` on craftsphere.cloud | ≤ $150 | **~$27** (Opus 4.7, 50 calls, 7-8 min, 35K out, 4.4M cw5, 3.7M cr) | ✓ PASS |
| 6.2 `/analyse --audit` on craftsphere.cloud | ≤ $250 | (deferred) | open |
| 6.3 `/generate` against catalog from 6.1 | ≤ $25 | **$11.31** (Sonnet 4.6) | ✓ PASS |
| 6.4 Catalog-driven vs full-audit `/generate` diff | substantively equivalent | (deferred — requires 6.2 first) | open |
| 6.5 Default `/analyse` on single-project repo | ≤ $15 | (deferred — needs target repo) | open |

**Default-mode cost driver.** Of the ~$27 spent on 6.1, ~90% was cache_write_5m tokens (4.4M × $6.25/MTok ≈ $27.50 nominal; rounding from per-turn pricing brings the script's reported total to ~$27). The cost is dominated by orchestrator prefix churn: the Opus orchestrator accumulates per-stack reference deep-pass context inline (file reads, discover.sh JSONs, `.github/` instruction reads) and re-caches the full 100K-217K prefix every ~3 turns. Of 50 deduped calls, ~26 were "healthy" delta-cache turns (`cw5 < 25K`, `cr ≈ 100-200K`); 19 were full re-cache events (`cr = 0`, `cw5 = 117K-217K`). The 19 full re-caches account for ~2.1M of the 4.4M cache-write tokens. Trigger events: (a) parallel tool-result batches landing in one turn (5 discover.sh JSONs at once), (b) system-reminder injections shifting byte offsets, (c) skill-body re-emission, (d) the 5-min cache TTL expiring during the final ~8.5-min `Write` gap. **This is below the residual-risk tolerance for this change** — the structural fix (catalog-mediated, per-stack reference only) hit its target; further cache reduction is incremental.

**Next opportunity (out of scope here; candidate follow-up `sonnet-default-fanout`).** Delegating each per-stack reference deep-pass to its own Sonnet sub-agent would shrink the orchestrator prefix to a thin synthesis context (~5K) and bound each sub-agent's cache write. Projection on craftsphere.cloud: orchestrator ~$1 + 5 Sonnet sub-agents at ~$2 each = **~$11** vs measured $27. Saves ~$16 absolute, ~60% relative. Not urgent — $27 onboarding is already well under cap — but should be the next-but-one cost work after `/refresh` redesign.

**Proposal cost-model claims reconciled.** The original `~$100-150` figure in proposal.md was derived from the same Anthropic-direct-list math that produced the `speed-up-analyse` $1-2 baseline and the post-run $417 measurement. With the script's pricing table corrected to Bosch Vertex (2026-06-02 update), the corrected reading of the original measurement is **~$140 for the all-Opus fan-out** (vs $417 reported then), and the corrected projection for this change is **~$30 default / ~$70 audit / ~$11 generate**. The proposal's Impact section has been updated to these numbers.
