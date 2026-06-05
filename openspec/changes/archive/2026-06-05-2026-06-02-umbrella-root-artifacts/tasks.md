## 1. Catalog schema and reference docs

- [x] 1.1 Extend `skills/claudboard/references/catalog-schema.json`: add `"workspace"` to the `mode` enum; add optional `umbrella_root` field (absolute path; equal to `repo` for monorepo/single-project, equal to the workspace dir for workspace); add optional `repo_count` field on `stacks[]` entries to disambiguate "5 React services in 1 monorepo repo" from "5 React repos in a workspace".
- [x] 1.2 Update `skills/claudboard/references/catalog-format.md`: document workspace-mode catalog placement (umbrella root, reached via the `.claude/`-style symlink convention but for `.claudboard/`); document the unified default/audit shape across all three modes; document the `umbrella_root` field and how consumers resolve it; document that consumers MUST NOT branch on `mode` for logic (D7).
- [x] 1.3 Document the per-stack reference-repo selection rule for workspace mode: orchestrator picks one repo per stack as the reference, populates `stacks[].reference_service` with that repo name. Note that reference selection is representative-not-exhaustive (per D-risks).

## 2. `/analyse` SKILL.md modifications

- [x] 2.1 Collapse the workspace-mode section of `skills/claudboard-analyse/SKILL.md` into the existing monorepo flow. Remove the standalone "Workspace parallelisation protocol" section; replace with one bullet under the unified Phase 1 noting that workspace detection sets `umbrella_root = <workspace dir>` and that `--audit` fan-out uses the same Sonnet sub-agent protocol as monorepo.
- [x] 2.2 Remove the workspace-specific Phase 3 path that writes per-repo reports under `<workspace>/.claude/reports/`. Replace with the unified Phase 3 that writes only `<umbrella_root>/.claudboard/catalog.json`, `<umbrella_root>/.claude/reports/claudboard-analysis.md`, and (under `--audit`) `<umbrella_root>/.claudboard/audits/<svc>.md`.
- [x] 2.3 Move ecosystem.md authorship into the unified Phase 1 / Phase 3 (currently workspace-only): the orchestrator writes a single `<umbrella_root>/.claude/memories/ecosystem.md` covering every detected service. Runs in workspace and monorepo modes; degenerates to a short "no cross-service deps" file in single-project mode (or is omitted).
- [x] 2.4 Move cross-service-graph construction into the unified Phase 1 (currently workspace-only): runs in workspace and monorepo modes. Single-project produces an empty graph.
- [x] 2.5 Update Phase 1a (detection + classification): keep the workspace detection logic (per-repo `.git/`); after detection, compute `umbrella_root` once and pass through to all later phases. Eliminate per-mode write-path branching downstream.
- [x] 2.6 Add D6 handling: in workspace mode, if `<workspace>/.claude` is not present as a symlink, `/analyse` creates `<workspace>/.claudboard/` and `<workspace>/.claude/reports/` inline, writes outputs there, and at the end prints one line instructing the user to run `/claudboard-workspace-init` to share these under git.
- [x] 2.7 Update the SKILL.md "Cost expectations" section to add workspace-mode caps: default ≤ $80 on a 14-repo project, `--audit` ≤ $250. Note that all three modes share the same pipeline.
- [x] 2.8 Confirm SKILL.md size budget. The current file is ~743 lines; this change should reduce it (collapsing workspace-specific sections). Target ≤ 700 lines post-change.

## 3. `/generate` SKILL.md modifications

- [x] 3.1 Remove every per-service `.claude/` write path from `skills/claudboard-generate/SKILL.md`. No writes to `<umbrella>/<svc>/.claude/skills/`, `<umbrella>/<svc>/.claude/rules/`, or `<umbrella>/<svc>/.claude/memories/` under any mode.
- [x] 3.2 Keep per-service CLAUDE.md writes (`<umbrella>/<svc>/CLAUDE.md`). Document the dynamic-down-walk rationale inline.
- [x] 3.3 Update the artifact-shape section: rules with `paths:` globs are the primary channel for service-specific conventions; ecosystem.md is the primary channel for service-specific topology; Pattern A skill (dispatcher + references) is the channel for service-specific procedural content.
- [x] 3.4 Update Phase 3 (skill generation): when the catalog's `proposed_artifacts` contains skill entries with per-service variations, generate a single `<umbrella>/.claude/skills/<concern>/SKILL.md` (dispatcher) plus one reference file per service in `references/<svc>.md`. The SKILL.md enumerates the exact valid service names and instructs deterministic exact-match dispatch.
- [x] 3.5 Update the Pre-Write Summary preview to reflect the new file list (no per-service `.claude/` paths; per-service CLAUDE.md count; umbrella ecosystem.md).
- [x] 3.6 Update the workspace-mode block of `/generate`: writes only to umbrella root (the meta-repo via symlink, or inline at workspace root if not bootstrapped). Remove any per-repo `.claude/` write paths.
- [x] 3.7 Update the "If no report found" error message to be mode-aware: in workspace mode without a bootstrapped meta-repo, suggest `/claudboard-workspace-init` alongside `/analyse`.

## 4. `/refresh` SKILL.md modifications

- [x] 4.1 Apply the same per-service `.claude/` removal in `skills/claudboard-refresh/SKILL.md`. Refresh writes only at umbrella root.
- [x] 4.2 Keep per-service CLAUDE.md updates during refresh (when the catalog indicates a service's role or stack has changed).
- [x] 4.3 Document the legacy-path behaviour: refresh does not delete per-service `.claude/` directories left by prior versions; it just stops updating them. A future `--prune-stale` flag will handle cleanup.

## 5. Reference and template updates

- [x] 5.1 Update `skills/claudboard/references/skill-generation.md`: add Pattern A documentation (dispatcher + per-service references); document the exact-match-dispatch convention; document Pattern B as escape hatch (out of scope for v1 generation, but the doc names it so future regenerations can promote services).
- [x] 5.2 Add a per-service CLAUDE.md template variant to `skills/claudboard/references/claude-md-template.md`. Short (≤ 30 lines), service-specific, references the umbrella `.claude/memories/ecosystem.md` and `.claude/rules/`. Umbrella CLAUDE.md template gains a "Services" section that lists each service with a one-line description.
- [x] 5.3 Update `skills/claudboard/references/pattern-catalog.md` and `skills/claudboard/references/workflow-signals.md` if either references per-service `.claude/` write paths (sweep and remove). (No changes needed — no such references found.)
- [x] 5.4 Update `skills/claudboard/references/quality-signals.md` if it references per-service rule generation paths (sweep and remove). (No changes needed — references were general runtime loading docs, not per-service write paths.)

## 6. Cost & quality validation (gates before merge)

- [ ] 6.1 Run default `/analyse` on MEAS workspace (14 service repos). Measure with `compute-cost.sh`. Acceptance: ≤ $80.
- [ ] 6.2 Run `/analyse --audit` on MEAS workspace. Measure. Acceptance: ≤ $250.
- [ ] 6.3 Run `/generate` against the MEAS umbrella catalog. Measure. Acceptance: ≤ $25. Verify zero writes under any `<workspace>/<repo>/.claude/skills/`, `<workspace>/<repo>/.claude/rules/`, or `<workspace>/<repo>/.claude/memories/` path (assert by enumerating the post-run file tree).
- [ ] 6.4 Run default `/analyse` on craftsphere.cloud monorepo (re-validation). Measure. Acceptance: ≤ $50 (regression check against the $27 baseline measured in `thin-analyse-catalog-primary`).
- [ ] 6.5 Run `/generate` on craftsphere.cloud catalog. Measure. Acceptance: ≤ $15 (improvement from $11.31 baseline due to removed per-service writes is expected; ≤ $15 is the regression cap). Verify zero per-service `.claude/` writes.
- [ ] 6.6 Verify generated ecosystem.md on MEAS workspace contains entries for all 14 services (or all those classified as services, excluding libraries), with role / depends-on / used-by / shared-contracts / coupling-warnings sections populated for each.
- [ ] 6.7 Verify generated ecosystem.md on craftsphere.cloud contains entries for all detected services. (Note: this is a new artifact for monorepo mode — prior monorepo runs did not produce ecosystem.md.)
- [ ] 6.8 Verify dispatcher skill (Pattern A) produced for at least one stack on each test project. SKILL.md enumerates exact valid service names; `references/<svc>.md` filenames match enumerated names exactly.
- [ ] 6.9 Verify per-service CLAUDE.md files written (one per service) and that each is ≤ 30 lines and references the umbrella ecosystem.md.
- [ ] 6.10 Verify Claude Code's initial-context manifest on a feature-workflow session started at MEAS workspace root includes `<workspace>/.claude/memories/ecosystem.md` (proves the runtime-loading claim).
- [ ] 6.11 Document the measured numbers in a Validation section appended to design.md before merge. If any acceptance criterion fails, revise the proposal honestly; do not merge with unmet caps.

## 7. Documentation & communication

- [x] 7.1 Update the project `README.md`: add a paragraph noting that workspace and monorepo modes share one pipeline; both produce a single catalog at the umbrella root; per-service `.claude/` directories are no longer generated.
- [x] 7.2 Add a "Migration from older claudboard (workspace mode)" subsection to the README: existing per-repo reports under `<workspace>/.claude/reports/` are not consumed by `/generate`; users can delete them at leisure. Per-service `.claude/` directories left by prior `/generate` runs are also not consumed; deletion is optional.
- [x] 7.3 Update the generated CLAUDE.md template (umbrella) to include a "How this project is onboarded" section: links to ecosystem.md, references skill (if generated), and notes `.claudboard/catalog.json` as the source of truth for regeneration.

## 8. Memory and proposal cleanup

- [x] 8.1 Update or create a `umbrella-root-loading-semantics` memory file documenting: the empirical loading research (skills/rules/memories walk UP from CWD, subagents re-discover from their CWD, only CLAUDE.md walks DOWN dynamically), the umbrella-only rule it justifies, and Pattern A / Pattern B as the canonical channels for service-specific content. Future sessions need this context to avoid drifting back to per-service writes.
- [x] 8.2 Update `MEMORY.md` index to point at the new memory file.
- [x] 8.3 Note in the project memory that workspace and monorepo modes are now unified; future spec work should treat them as one mode with one detection-time routing rule.

## 9. Out-of-scope follow-ups to file as separate changes

These are explicitly out of scope for this change. Listed here so they don't get lost.

- [ ] 9.1 `--prune-stale` flag for `/generate` / `/refresh` to delete per-service `.claude/` directories left by prior versions.
- [ ] 9.2 `/refresh` redesign to diff against the unified catalog (still deferred from `thin-analyse-catalog-primary`; this change makes the follow-up smaller because workspace and monorepo are now the same shape).
- [ ] 9.3 Promotion logic for "this service has enough procedural distinctiveness to warrant its own root-level skill (Pattern B)." Pattern A uniformly in v1; promotion is v2.
- [ ] 9.4 Cost preview / scope-confirmation calibration in `/analyse`'s `AskUserQuestion`. Still deferred from prior change.
- [ ] 9.5 Workspace meta-repo bootstrap UX improvements: auto-suggest `/claudboard-workspace-init` when workspace mode detects missing `.claude/` symlink (covered partially by 2.6; UX polish deferred).
- [ ] 9.6 ecosystem.md size compression for very large workspaces (per-stack rollup instead of per-service rows) if any project's ecosystem.md exceeds the memory size budget.
- [ ] 9.7 Unit test asserting `/generate` produces byte-equivalent output for two catalogs differing only in `mode` field (requires test infra not present in v1).
