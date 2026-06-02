## Why

A 2026-06-01 measurement of `/claudboard:claudboard-analyse` against a real-world monorepo (craftsphere.cloud, 19 services) came to **$417.66** in 13 minutes on Opus 4.7 — verified via `compute-cost.sh` with proper `requestId` dedup ($122 orchestrator + $296 across 19 sub-agents). The earlier `speed-up-analyse` change (2026-05-30) characterised the same skill at a "$1-2 single-project baseline" assuming Sonnet pricing and no large-scale fan-out. The measured Opus + fan-out run came in **~250× over** that baseline.

Two empirical findings from the post-run analysis reshape what the fix should look like:

1. **Claude Code does not auto-load `.claude/reports/*.md` during normal feature-workflow sessions.** Only CLAUDE.md, `.claude/rules/*.md` (gated on `paths:` globs), `.claude/skills/*/SKILL.md` (when invoked), and `.claude/memories/*.md` are loaded. The per-service reports — which produced $296 of the $417 — are only read by `/generate`, `/refresh`, `/techdebt`, and humans. They are not on the runtime context surface; they are intermediate build state.

2. **`/generate` consumes ~20% of what per-service reports contain.** Walking the generate SKILL.md and its `references/skill-generation.md`, the actual inputs used are: a deduplicated convention/pattern catalog, one "best-example" file path per detected skill trigger, and an adaptive-depth signal. Per-service Watch findings, quality dimension breakdowns, call-path tracing detail, and cross-service Kafka graphs are not consumed by generation at all. They are audit outputs, served to a different audience (humans reviewing monorepo health) on a different cadence.

Today the skill conflates these two products — audit and generative input — and bills audit-grade cost for every onboarding run. The fix is structural, not just an optimisation: promote the convention catalog to a primary first-class artifact on the analyse→generate path, demote the per-service reports to opt-in audit output, and tier model usage so that only true synthesis stages run on Opus.

## What Changes

- **NEW** primary artifact `.claudboard/catalog.json` — strict-JSON convention catalog with versioned schema. Contains the deduplicated set of detected patterns, the canonical exemplar file per pattern, project-wide conventions (DI style, logging, error handling), proposed artifacts (rules + skills with type, name, target paths), the adaptive-depth signal per stack, and a top-level stack inventory. The catalog is the **single structural artifact** on the analyse→generate path.
- **NEW** capability `convention-catalog` — defines the catalog's JSON schema, contract semantics, location, regeneration rules, and consumer protocol. Single source of truth for what `/generate` reads.
- **MODIFIED** `analyse-performance` — `/analyse` default behaviour produces only the convention catalog (plus a thin human-readable `claudboard-analysis.md` summary). Per-service deep analysis is gated behind a new `--audit` flag. Default-mode cost on a 19-service monorepo drops to ~$100-150 (vs the measured $417).
- **MODIFIED** `per-service-analysis` — per-service deep reports (`claudboard-analysis-<svc>.md`) and the cross-service Kafka graph are produced **only when `--audit` is passed**. Their structural content is unchanged; only their production trigger changes. They move from `.claude/reports/` to `.claudboard/audits/` to make their "build-state, not runtime context" status visible.
- **MODIFIED** `monorepo-generation` — `/generate` consumes `.claudboard/catalog.json` as its primary input instead of walking N per-service report files. When the catalog is missing but per-service reports exist (legacy state from prior `/analyse` runs), `/generate` synthesises the catalog from those reports as a one-time migration, then proceeds normally. When neither is present, the existing "run `/analyse` first" message stands.
- **NEW** asymmetric model tiering as a documented contract in `/analyse` and `/generate` SKILL.md files:
  - Orchestrator catalog synthesis + outlier detection → **Opus tier**
  - Sub-agent extraction (during `--audit` fan-out) → **Sonnet tier**
  - `/generate` (template-fill from a structured catalog) → **Sonnet tier**
  - `discover.sh` and other bash steps → unchanged (deterministic, zero model cost)
  - Haiku is intentionally **not** used; the quality risk on convention extraction was judged not worth the marginal cost saving.
- **No change** to: CLAUDE.md generation output format, rule-generation output format, skill-generation output format, the existing `analyse-performance` discover.sh pipeline, the existing reference-load gating, the existing `compute-cost.sh` script or pricing table, `/techdebt`, `/refresh` (a separate follow-up will redesign `/refresh` to diff against the catalog), `/claudboard-workflow`.

## Capabilities

### New Capabilities

- **`convention-catalog`** — the JSON catalog at `.claudboard/catalog.json` as a first-class artifact on the analyse→generate path. Owns: schema versioning, location, content contract (patterns, exemplars, proposed artifacts, conventions, stack inventory), consumer protocol (how `/generate` reads it), regeneration rules, and the catalog↔reports compatibility/migration contract.

### Modified Capabilities

- **`analyse-performance`** — `/analyse` default behaviour reduced to catalog production only. Per-service deep analysis (Phases 1c-1h × M services) moved behind explicit `--audit` flag. Cost-model claims updated to reflect catalog-default economics. Asymmetric model tiering documented as a performance contract (sub-agents and `/generate` Sonnet, orchestrator synthesis Opus).
- **`per-service-analysis`** — production gated behind `--audit` flag. Output location moved from `.claude/reports/` to `.claudboard/audits/` to clarify build-state vs runtime-context status. Per-service content shape unchanged.
- **`monorepo-generation`** — primary input source changes from `.claude/reports/claudboard-analysis*.md` to `.claudboard/catalog.json`. One-time migration path defined for projects whose only artifact is the legacy per-service reports.

## Impact

- **Affected files (new):**
  - `skills/claudboard/references/catalog-schema.json` — JSON schema for the catalog (validatable contract)
  - `skills/claudboard/references/catalog-format.md` — human-readable explanation of catalog fields, regeneration rules, and the migration path from per-service reports
  - `openspec/changes/2026-06-01-thin-analyse-catalog-primary/specs/convention-catalog/spec.md` — new capability spec
- **Affected files (modified):**
  - `skills/claudboard-analyse/SKILL.md` — Phase 1 produces catalog by default; per-service Phases 1c-1h gated behind `--audit`; Phase 3 writes catalog to `.claudboard/catalog.json` instead of per-service reports under `.claude/reports/`; sub-agent dispatch directive specifies Sonnet tier during `--audit` fan-out
  - `skills/claudboard-generate/SKILL.md` — Phase 1 reads catalog as primary input; legacy per-service report fallback path added with migration; generation runs on Sonnet tier; reference-load section updated to mention catalog schema
  - `skills/claudboard/references/report-template.md` — adds catalog-section requirement to the global report (the catalog is canonical in JSON; the report mirrors a human-readable summary)
- **Affected files (unchanged):**
  - `skills/claudboard/scripts/discover.sh` — unchanged; the script's per-service Pattern Inventory output is exactly the input the catalog synthesis stage consumes
  - `skills/claudboard/scripts/compute-cost.sh` — unchanged
  - `skills/claudboard/references/pricing.md` — unchanged
  - `skills/claudboard-refresh/SKILL.md` — unchanged in this proposal; a follow-up change will redesign `/refresh` around catalog-diff (called out in Out of Scope below)
  - `skills/claudboard-techdebt/SKILL.md` — unchanged; `/techdebt` operates on its own data sources and is not on the analyse→generate path
  - `skills/claudboard-workflow/**` — unchanged; the workflow generator does not consume per-service reports
- **Downstream consumers:**
  - Existing projects with `.claude/reports/claudboard-analysis*.md` from prior `/analyse` runs continue to work via the one-time migration path in `/generate`. The first post-change `/generate` run synthesises a catalog and writes it to `.claudboard/catalog.json`; subsequent runs use the catalog directly.
  - Human readers who have bookmarked per-service report paths will find that those reports only get regenerated when `--audit` is invoked. The migration path preserves any existing reports on disk.
- **Cost-model claims (Bosch Vertex rates — see `skills/claudboard/references/pricing.md`):**
  - Default `/analyse` on a 19-service monorepo (craftsphere.cloud baseline): **~$27 measured** (acceptance cap $150). Driven by single Opus orchestrator holding per-stack reference deep-pass context; no fan-out by default. ~90% of cost is cache_write_5m churn on the orchestrator prefix (full breakdown in design.md → Validation).
  - `/analyse --audit` on the same monorepo: **~$70-85 projected** with the asymmetric tier (acceptance cap $250). Projection scaled from the same craftsphere.cloud run with Sonnet sub-agent fan-out costs added; not yet measured (task 6.2 deferred).
  - `/generate` on the same monorepo, reading catalog: **$11.31 measured** (acceptance cap $25). Sonnet template-fill on small structured input.
  - Single-project repos: change is cost-neutral or modestly cheaper. Acceptance cap ≤$15 (task 6.5 deferred — needs target repo).
  - Pre-change baseline reconciled: the prior "$417 measured" claim was derived from Anthropic-direct list pricing in `compute-cost.sh`; with the Vertex pricing table (added 2026-06-02) the same all-Opus run reads as **~$140 measured** on actual Bosch billing. The structural fix in this change drops that to ~$27 default / ~$70-85 audit / ~$11 generate.
- **Risks:**
  - *Catalog completeness*: if `/generate` finds the catalog missing fields it needs (e.g. proposed-artifact entries with insufficient detail), generation degrades. Mitigation: catalog schema is strict-JSON with validation; `/generate` errors loudly on schema violations naming the missing field, rather than silently producing weaker output.
  - *Sonnet quality on `/generate`*: template-fill on a structured catalog is well within Sonnet's competence band, but creative SKILL.md authoring is the one place Opus arguably helps. Mitigation: explicit acceptance criterion in tasks.md that diffed output of `/generate` (Sonnet, catalog-driven) vs `/generate` (Opus, current full-reports-driven) on craftsphere.cloud must be substantively equivalent. If the test diverges, the tier decision for `/generate` is revisited before merge.
  - *Audit cadence drift*: with audit moved off the default path, teams may forget to run `--audit` and lose visibility into per-service quality. Mitigation: documented in CLAUDE.md as a recommended quarterly task; a follow-up change may add explicit reminders or staleness checks.
  - *Catalog schema versioning*: the catalog is now a contract between `/analyse`, `/generate`, and `/refresh` (future). Schema drift breaks consumers silently. Mitigation: catalog carries `schema_version` field; consumers assert version match and emit a clear error on mismatch, mirroring the pattern already used by `discover.sh`.
  - *Workspace mode is unaddressed in v1*: workspace mode (multi-repo) writes per-repo reports under `<workspace>/.claude/reports/`. The catalog approach extends naturally (one catalog per repo, plus an optional workspace-level rollup) but is explicitly deferred to a follow-up. Mitigation: `analyse-performance` modified spec is explicit that workspace mode retains its current behaviour until that follow-up lands.
- **Out of scope (deferred to follow-up changes):**
  - `/refresh` redesign to diff against catalog instead of re-scanning (separate change; this proposal's catalog makes that follow-up significantly cheaper to ship).
  - Cost preview in `/analyse`'s scope-confirmation `AskUserQuestion` ("Full: ~$X / Audit: ~$Y"). Requires either a static calibration table or a cost-history file; both are non-trivial and orthogonal to the catalog restructure.
  - Plugin-namespace gate fix for the `cost-reporting` stop hook (the `/claudboard:claudboard-analyse` form currently fails the `^\s*/(analyse|generate|refresh|techdebt)\b` regex). Independent change against the `cost-reporting` capability.
  - Workspace-mode catalog adaptation (per-repo catalogs + workspace rollup). Different invariants, deserves its own thinking.
  - Calibration table populated from post-run cost telemetry feeding back into scope-question previews.
  - Tier-aggressiveness configuration (`--tier=aggressive` to opt into Haiku stages). Single-tier ship now; revisit if the conservative tier delivers good enough cost/quality.
