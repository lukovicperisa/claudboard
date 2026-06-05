## Context

The `thin-analyse-catalog-primary` change (archived 2026-06-02) ended on two pieces of unfinished business that converge into the same architectural fix:

**Unfinished business 1 — workspace mode left alone.** That change's D10 explicitly preserved workspace-mode behaviour pending a follow-up, on the reasoning that the workspace-mode catalog adaptation had "non-trivial open invariants" (where does the rollup live? does the per-repo `.claude/` shape change?). Empirical evidence from a 2026-06-02 `/analyse` run against the MEAS workspace (14 service repos, mixed Java/React/Node/.NET) confirmed the deferral was costly: workspace mode re-triggered the exact $400-class Opus fan-out the monorepo restructure was meant to kill. Two products from one logical input shape.

**Unfinished business 2 — per-service `.claude/` artifacts were assumed to load.** A separate empirical thread surfaced after the change shipped: the docs ([sub-agents.md](https://code.claude.com/docs/en/sub-agents.md), [memory.md](https://code.claude.com/docs/en/memory.md), [large-codebases.md](https://code.claude.com/docs/en/large-codebases.md)) confirm that Claude Code discovers skills, rules, and memories by walking **up** from the session CWD, not down. Subagents spawned via the Agent tool re-discover from their own CWD, which by default is the parent session's CWD. When a feature-workflow session starts at the umbrella root (workspace or monorepo), per-service `<svc>/.claude/skills/`, `<svc>/.claude/rules/`, and `<svc>/.claude/memories/` directories are **down** from CWD and are never loaded. Only per-service `CLAUDE.md` participates in runtime context, via a documented dynamic down-walk that fires when an agent reads a file in that subdirectory. Everything else under per-service `.claude/` is dead weight.

Both threads point at the same architectural truth: there is one umbrella project, with N services beneath it. The architectural artifacts (skills, rules, memories, CLAUDE.md, catalog, audits) belong at the umbrella root. The per-service split that workspace mode currently produces — and the per-service split that monorepo `/generate` currently produces — is the wrong shape on two counts: it costs tokens to produce, and the produced files don't load at runtime.

The fix is one change because the root cause is one fact: the umbrella is the unit of loading. Workspace vs monorepo differs only in where the umbrella's `.git/` lives — at the umbrella for monorepo, or in a child meta-repo for workspace. That git-boundary detail affects exactly one thing: where on the filesystem the umbrella `.claude/` and `.claudboard/` directories are reachable. The pipeline that produces them, and the artifacts they contain, are identical.

## Goals / Non-Goals

**Goals:**
- Unify workspace and monorepo modes into a single pipeline. Same default behaviour, same `--audit` behaviour, same output shape. The detection step is the only place that distinguishes them.
- Eliminate the workspace-mode default per-repo fan-out. Bring workspace-mode default cost on a 14-repo project under $80 (vs the measured $400-class today).
- Remove all per-service `.claude/` write paths from `/generate`. Architectural artifacts live only at the umbrella root.
- Add ecosystem.md to monorepo mode. Workspace already produces it; monorepo currently does not. The dependency graph that feeds it is cheap and worth keeping.
- Document the loading semantics that justify the umbrella-only rule so future changes don't drift back to per-service writes.
- Establish Pattern A (dispatcher skill + per-service references) as the canonical way to package service-specific procedural content at the umbrella root.

**Non-Goals:**
- Pruning existing per-service `.claude/` directories produced by prior versions. Out of scope; left for a future `--prune-stale` flag. Stale dirs do no runtime harm.
- `/refresh` redesign to diff against the catalog. Still deferred from `thin-analyse-catalog-primary`; this change makes that follow-up smaller (one mode instead of two).
- Promotion logic for "this service warrants its own root-level skill instead of a reference." Pattern A uniformly in v1; Pattern B is documented as the escape hatch for v2.
- Cost preview / scope-confirmation calibration. Still deferred.
- Workspace meta-repo bootstrap UX (auto-detecting when `.claude/` symlink is missing and suggesting `/claudboard-workspace-init`). Adjacent improvement; not part of the unification.

## Decisions

### D1. Workspace and monorepo share one pipeline after detection

Two options considered:

- **(A) Unified post-detection pipeline.** Detection step distinguishes workspace from monorepo (per-repo `.git/` check). Both then route into the same default-mode codepath (reference-service-per-stack, no fan-out) and the same `--audit`-mode codepath (per-service Sonnet sub-agents).
- **(B) Keep separate pipelines but bring workspace closer to monorepo.** Apply the catalog primary rule to workspace but keep the workspace-specific parallelisation protocol, per-repo report writing, and ecosystem.md authorship boundary intact as separate logic.

**Decision: Option A.** The two pipelines are doing the same work on the same input shape; the only true difference is where the umbrella `.claude/` and `.claudboard/` live on disk, and that's a one-line routing concern at file-write time. Keeping two pipelines doubles the maintenance surface for no functional gain. The collapse is what makes the cost numbers match across modes: when the codepath is the same, the cost profile is the same.

### D2. Umbrella root is computed once at detection time; everything writes through it

Two options considered:

- **(A) Compute `umbrella_root` at detection, pass it through to all write paths.** Monorepo: `umbrella_root = <repo-root>`. Workspace: `umbrella_root = <workspace-dir>` (with `.claude/` resolved through the meta-repo symlink). Single-project: `umbrella_root = <repo-root>`. Every Phase 3 write uses `<umbrella_root>/.claudboard/...` or `<umbrella_root>/.claude/...`.
- **(B) Branch on `mode` at each write site.** Each write checks `mode == "workspace"` and routes differently.

**Decision: Option A.** Computing the umbrella root once at detection is the simpler abstraction and eliminates the branching everywhere else. The catalog records `mode` for downstream consumers, but the write code doesn't have to know. Workspace's symlink convention (`<workspace>/.claude → meas.workspace/.claude`) means a write to `<umbrella>/.claude/...` lands in the right place transparently — no special-casing.

### D3. ecosystem.md is one file at the umbrella root, not per service

Three options considered:

- **(A) One workspace-wide / monorepo-wide `<umbrella>/.claude/memories/ecosystem.md`.** Covers every service's role, deps, and edges in one file. Loads via standard memory loading from the umbrella root.
- **(B) Per-service `<svc>/.claude/memories/ecosystem.md`.** Status quo for workspace. Each file scoped to one service's deps/edges. Loads only if the session is started in that service.
- **(C) Both: umbrella-wide ecosystem.md plus per-service slices.** Belt-and-braces.

**Decision: Option A.** Per the loading-semantics research, per-service memories don't load when the session starts at the umbrella root (the normal feature-workflow case). Per-service `<svc>/.claude/memories/*.md` is dead weight — except in the edge case where a dev opens Claude directly in one service repo, which is not the feature-workflow path. The umbrella-wide file is the only file that reliably participates in runtime context, and it has a positive side effect: agents reasoning across services see the full topology at once instead of the slice for one service.

Option C wastes tokens producing files that aren't read in the feature-workflow path.

For workspace mode specifically: dropping per-repo ecosystem.md means dropping per-repo `.claude/memories/` directories entirely. Combined with D4 (no per-service `.claude/skills/` or `rules/`), workspace mode no longer touches per-repo `.claude/` directories at all. The per-repo `.claude/` directory remains only for repo-local content the developer manually owns (their CLAUDE.md edits, their `.claude/settings.local.json`, etc.), not for claudboard-managed artifacts.

### D4. `/generate` writes only at the umbrella root — radical-no-leftovers position

Two options considered:

- **(A) Radical.** No per-service `.claude/` writes from `/generate` or `/refresh`. All architectural artifacts (skills, rules, memories) live at the umbrella root. Per-service CLAUDE.md is the only per-service artifact, written one short file per service (dynamically loaded by Claude Code's down-walk when the agent reads a file in that subdir).
- **(B) Safe.** Keep per-service `.claude/memories/ecosystem.md` as a redundant copy in case a dev opens a service standalone. Accept that it costs extra tokens to produce and is mostly redundant.

**Decision: Option A.** The empirical loading-semantics evidence is unambiguous: per-service `.claude/` content is invisible at workflow runtime when the session starts at the umbrella. The "what if a dev opens the service standalone" case is genuine but not the workflow path, and the dev can run `/analyse` directly in that service repo if they need a self-contained `.claude/` — that produces a single-project catalog under `<svc>/.claudboard/`, which is symmetric and consistent.

The per-service CLAUDE.md is the one exception, justified by the documented dynamic-down-walk loading: when a sub-agent reads a file in `<umbrella>/<svc>/...`, Claude Code loads `<umbrella>/<svc>/CLAUDE.md` at that moment. This makes per-service CLAUDE.md the right place for short, service-specific orientation ("this service is a Quarkus app, handles X, points at ecosystem.md for cross-service context").

### D5. Skill packaging is Pattern A (dispatcher + per-service references), with Pattern B as documented escape

Three options considered:

- **(A) Pattern A: one generic skill per concern, references per service inside.** `<umbrella>/.claude/skills/service-info/SKILL.md` enumerates valid service names; `references/<svc>.md` holds the per-service content. Dispatch is deterministic exact-match.
- **(B) Pattern B: per-service skills at umbrella root.** `<umbrella>/.claude/skills/<svc>-info/SKILL.md` per service. N skills in the index. Each loads only when triggered.
- **(C) Mixed: A for most services, B for services with distinctively rich procedural content.**

**Decision: Option A as the v1 baseline; Option C reserved for v2.** Pattern A handles the common case well: most per-service content from claudboard's catalog is facts and conventions (which belong in rules-with-`paths:` and ecosystem.md, not skills), and the small slice that genuinely belongs in a skill is mostly shared across services with per-service quirks. References-on-demand fits that shape. Pattern B fragments the skill index without buying triggering precision (the descriptions would all be near-identical).

Dispatch reliability for Pattern A is solved deterministically: SKILL.md enumerates the exact set of valid service names; references are filenames-exactly-matching those service names; dispatch is closed-set lookup, not fuzzy string matching. This is documented as the contract in `skill-generation.md`.

Pattern B is reserved as a v2 promotion path: when the catalog detects that a service has substantial procedural content that doesn't fit a shared template, `/generate` MAY promote that service from "reference under the dispatcher" to "its own root-level skill." Out of scope for v1.

### D6. Workspace mode without a bootstrapped meta-repo writes inline and instructs the user to bootstrap

Two options considered:

- **(A) Refuse to run.** If workspace mode is detected and `<workspace>/.claude` is not a symlink to a bootstrapped meta-repo, `/analyse` exits and instructs the user to run `/claudboard-workspace-init` first.
- **(B) Write inline and instruct.** `/analyse` proceeds, creates `<workspace>/.claudboard/` and `<workspace>/.claude/reports/` directly (no symlink), writes the catalog and summary, and prints one line at the end: "Workspace is not bootstrapped under git — to share `.claude/` across the team, run `/claudboard-workspace-init` next."

**Decision: Option B.** Refusing to run is a poor UX for the user's first contact with claudboard on a workspace — they may be exploring the tool before committing to a meta-repo bootstrap. Writing inline lets them see the value (the catalog, the summary, the audit findings) before deciding to bootstrap. The bootstrap migration path (already implemented in `claudboard-workspace-init`) handles migrating inline `.claude/` and `.claudboard/` content into the meta-repo cleanly, so writing inline doesn't strand the user.

### D7. Catalog `mode` field gains `"workspace"`; consumers branch only on UX text, not on logic

The catalog's `mode` field already supports `"single-project"` and `"monorepo"`. This change adds `"workspace"`. Downstream consumers (`/generate`, future `/refresh`) MUST NOT branch on `mode` for logic — the catalog's `stacks`, `conventions`, `patterns`, `proposed_artifacts`, and `adaptive_depth` fields carry all the structural information generation needs, regardless of mode. The `mode` field is for UX text only ("Generated for your workspace at..." vs "Generated for your monorepo at...") and for diagnostic output.

### D8. Dependency graph is built in both modes, output is the same shape

Workspace mode currently builds a cross-service dependency graph in Phase 1c (orchestrator-side, derived from wide-scan grep output). The graph feeds ecosystem.md. Cheap to produce; high workflow value.

Monorepo mode currently does not build this graph. With ecosystem.md added to monorepo mode (D3), the graph must be built in monorepo mode too. The graph construction is moved into the unified Phase 1c that runs in both modes. Input is the same (per-repo / per-service grep output); output is the same (a list of cross-service edges with transport, source file, and coupling annotation). Cost is essentially the same — the orchestrator already has the data in context.

For single-project mode, the graph is empty (no cross-service edges); ecosystem.md degenerates to a short "you are alone" file or is omitted. The spec defines the degenerate case explicitly.

### D9. Per-service CLAUDE.md content is short and links to umbrella context

Per-service CLAUDE.md is the only per-service runtime artifact. To stay coherent with the umbrella-as-source-of-truth principle, per-service CLAUDE.md should be short (≤ 30 lines) and lean on the umbrella for cross-cutting context. Suggested shape:

```markdown
# CLAUDE.md — <service-name>

This service is the <role>. Stack: <stack>.

For workspace/monorepo conventions, dependencies, and topology: see umbrella `.claude/memories/ecosystem.md` and `.claude/rules/*.md` (auto-loaded).

## Service-specific
- Entry point: <main file>
- Tests: <how to run>
- Build: <how to build>
- <any service-specific quirks>
```

The umbrella CLAUDE.md remains the comprehensive document. Per-service CLAUDE.md exists only to surface the few facts a sub-agent in that subdirectory needs immediately on the dynamic down-walk.

### D10. Migration from legacy workspace reports is best-effort and non-destructive

Existing workspaces have per-repo reports at `<workspace>/.claude/reports/claudboard-analysis-<repo>.md`. The next `/analyse` run produces the unified umbrella catalog instead; legacy files are left untouched on disk (not consumed by `/generate`, not deleted, not migrated). Users can delete them manually.

If `/generate` is run against a workspace that has only legacy reports and no catalog, the migration path defined in `convention-catalog` (synthesise catalog from legacy reports) applies symmetrically: parse the legacy per-repo reports, synthesise a workspace catalog, proceed.

For per-service `.claude/` directories generated by prior `/generate` runs (the dead-weight artifacts the umbrella-only rule retires): also left on disk untouched. They were never auto-loaded, so they do no harm; deletion is at user discretion. Future `--prune-stale` flag can automate.

## Risks / Trade-offs

- **[Workspace users with bookmarks to per-repo report paths]** Old per-repo reports stay on disk so existing bookmarks resolve; new analysis output lands at new paths. Documented in the generated CLAUDE.md under a "What changed" section after the first post-change `/analyse` run.

- **[Per-service `.claude/` directories accumulate stale content]** Stale dirs do no runtime harm (they were never loaded). Out-of-scope `--prune-stale` flag handles cleanup later. v1 does not auto-delete to avoid touching files the user may have hand-edited.

- **[Pattern A dispatcher brittleness]** Dispatching by service name in user prompts could fail if the user types service-name variants ("controller" vs "meas.cloud.controller"). Mitigation: SKILL.md enumerates exact valid names and instructs the model to match exact; if the user types an alias, the model asks for clarification rather than guessing. Empirically validated when the first project ships generated artifacts using Pattern A; if it's brittle, the v2 promotion path (Pattern B) absorbs the problem services.

- **[ecosystem.md size grows linearly with service count]** A 14-service workspace's ecosystem.md is meaningfully larger than a 3-service monorepo's. Memory loading has a 5KB-line / 25KB budget per memory file (per memory.md docs). Mitigation: ecosystem.md content is per-service one-table-row, not prose paragraphs. Empirical sizing on MEAS (14 services) projects ~2-3KB; well under the budget. If a future project exceeds the budget, the spec already names compression as a follow-up (per-stack rollup instead of per-service rows).

- **[Per-service CLAUDE.md proliferation]** N services means N per-service CLAUDE.md files. Each is small (≤ 30 lines), but the aggregate disk footprint is non-trivial. Mitigation: this is the same write count as the prior status quo for monorepos (where per-service CLAUDE.md was sometimes generated); the change makes it consistent (always per service, but never additional `.claude/` content). The dynamic-down-walk loading semantics make this the right shape — each service needs its own one-page orientation file.

- **[Workspace meta-repo not bootstrapped]** D6 covers this: write inline, instruct to bootstrap. The migration path in `/claudboard-workspace-init` already handles moving inline `.claude/` into the meta-repo cleanly. Verified against the bootstrap script during this change's task 5.x.

- **[Catalog `mode: "workspace"` correctness]** Catalog consumers must not branch on `mode` for logic (D7). If a future `/refresh` change accidentally adds workspace-specific logic keyed off `mode`, it would re-fragment the codepath. Mitigation: a unit test (when test infra exists) asserts that `/generate` produces byte-equivalent output for two catalogs that differ only in `mode`. v1 lands without that test (no test infra), but the spec is explicit.

- **[Per-stack reference-repo selection in workspace mode]** Monorepo mode picks one reference service per detected stack. Workspace mode now does the same — but workspace services are often more heterogeneous than monorepo services (different teams, different repo conventions). The reference repo selected for the "Java" stack might miss conventions of other Java repos. Mitigation: default mode is light-touch by design; `--audit` is the right tool when per-repo coverage matters. Documented in `catalog-format.md`: "default-mode catalog is representative-not-exhaustive."

- **[Workflow tooling assumes per-service `.claude/skills/`]** If anyone has written external tooling that scans `<svc>/.claude/skills/` directories, this change orphans them. Mitigation: no such tooling exists in this repo's known ecosystem; if external users have built on this shape, they can migrate to umbrella-root scanning. Documented in the migration notes section of the generated CLAUDE.md.

- **[Validation budget for this change]** Cost validation requires running `/analyse` (default + `--audit`) against MEAS workspace and re-validating against craftsphere.cloud monorepo, plus `/generate` against the resulting catalogs. Estimated $300-500 in validation runs. Same justification as the prior change: a one-time investment that proves the structural claim holds.

## Validation

To be populated on archive. Acceptance criteria (from tasks.md section 6):

- 6.1 Default `/analyse` on MEAS workspace (14 services) ≤ $80
- 6.2 `/analyse --audit` on MEAS workspace ≤ $250
- 6.3 `/generate` on MEAS workspace umbrella catalog ≤ $25
- 6.4 Default `/analyse` on craftsphere.cloud monorepo (re-validation) ≤ $50
- 6.5 `/generate` on craftsphere.cloud catalog (post per-service write removal) ≤ $15
- 6.6 Generated artifacts on MEAS workspace contain zero per-service `.claude/skills/`, `.claude/rules/`, or `.claude/memories/` writes
- 6.7 Generated artifacts on craftsphere.cloud contain zero per-service `.claude/skills/`, `.claude/rules/`, or `.claude/memories/` writes
- 6.8 Generated ecosystem.md at umbrella root for both MEAS and craftsphere.cloud, loaded by Claude Code on next session startup (verified by inspecting initial context manifest)
- 6.9 Dispatcher skill (Pattern A) produced for both MEAS and craftsphere.cloud; SKILL.md enumerates exact service names; references/<svc>.md files match enumerated names
