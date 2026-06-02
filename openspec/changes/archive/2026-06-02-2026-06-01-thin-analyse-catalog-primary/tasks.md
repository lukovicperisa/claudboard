## 1. Catalog schema and reference docs

- [x] 1.1 Create `skills/claudboard/references/catalog-schema.json` as a JSON Schema document (draft-07 or 2020-12) defining: `schema_version` (literal `"1"`), `generated_at` (ISO-8601), `from_audit` (bool), `repo` (path), `mode` (`single-project` | `monorepo`), `stacks` (array of `{id, service_count, reference_service, exemplar_paths}`), `conventions` (object: `di_style`, `logging`, `error_handling`, `test_framework`, `naming`), `patterns` (object keyed by pattern id, each `{exemplar_path, frequency, variations, applicable_paths}`), `proposed_artifacts` (array of `{type: rule|skill, name, paths?, exemplar, depth_signal}`), `adaptive_depth` (object: per-stack quality average producing `full|medium|skeleton`).
- [x] 1.2 Create `skills/claudboard/references/catalog-format.md` — human explainer covering: which fields are required vs optional, how `/analyse` populates each (data sources), how `/generate` consumes each, the regeneration contract (always-from-scratch vs delta), the migration path from legacy reports, and the `schema_version` compatibility rule (consumers assert match, mismatch → clear error naming both versions).
- [x] 1.3 Document the catalog↔audit relationship: when `--audit` produces both, `from_audit: true` and audits are sibling files in `.claudboard/audits/`. When default `/analyse` produces catalog without audits, `from_audit: false` and the catalog is derived from less data (still complete for `/generate`'s needs, less rich).

## 2. `/analyse` SKILL.md modifications

- [x] 2.1 Update Phase 1 frontmatter and intro to state the dual-mode behaviour: default mode produces catalog + thin global summary; `--audit` adds per-service deep analysis. Document the `--audit` flag invocation contract.
- [x] 2.2 Restructure Phase 1c-1h so that the per-service deep pass is gated by `--audit`. Default mode runs: discover.sh once per detected service (cheap), strategic sampling on ONE reference service per detected stack (not all M services), orchestrator-synthesised catalog. Audit mode runs: existing Phases 1c-1h on every service via Sonnet sub-agents.
- [x] 2.3 Add sub-agent dispatch directive: when `--audit` triggers fan-out, sub-agent `Agent` calls SHALL specify `model: "claude-sonnet-4-6"` (or equivalent Sonnet tier ID). Document why (D5 from design.md).
- [x] 2.4 Update Phase 3 to write `.claudboard/catalog.json` (always) and `.claude/reports/claudboard-analysis.md` (always; thin human-readable summary). When `--audit` was passed, additionally write `.claudboard/audits/<svc>.md` per service.
- [x] 2.5 Remove the per-service `.claude/reports/claudboard-analysis-<svc>.md` write path from default mode. Only `--audit` produces per-service files (and only to `.claudboard/audits/`).
- [x] 2.6 Update the SKILL.md "Constraints" section to reflect: `.claudboard/catalog.json` is the primary artifact contract; per-service audit reports are opt-in; `.claude/reports/claudboard-analysis.md` remains for human review.
- [x] 2.7 Update the SKILL.md Reference Files table to add the two new catalog reference files (1.1, 1.2). Confirm SKILL.md size budget (≤ 750 lines per the May 30 budget; this change should not regress). [743 lines ✓]
- [x] 2.8 Update the "Phase 3: Save Report & Next Steps" section to print the new file paths and recommend running `/generate` next (unchanged) or `/analyse --audit` for monorepo health review.

## 3. `/generate` SKILL.md modifications

- [x] 3.1 Update Phase 1 ("Load Analysis Report") to look for `.claudboard/catalog.json` first. If present: read and proceed to Phase 2. If absent: check for legacy `.claude/reports/claudboard-analysis.md`; if present, run migration (3.2) then proceed.
- [x] 3.2 Add migration sub-section: when only legacy reports exist, parse them (best-effort), extract conventions / proposed artifacts / pattern exemplars, write a synthesised `.claudboard/catalog.json` with `from_audit: <true if per-service reports present, else false>`, log one line telling the user the migration happened, and proceed. If parsing fails, emit clear message naming the problem report and instruct user to run `/analyse` for a fresh catalog.
- [x] 3.3 Update Phase 2 "Pre-write summary" to render from catalog fields (Proposed Artifacts now comes directly from catalog `proposed_artifacts`, not from a markdown section).
- [x] 3.4 Update Phase 3 generation steps to source: conventions → `catalog.conventions`; rule depth → `catalog.adaptive_depth`; skill exemplars → `catalog.patterns[<pattern>].exemplar_path`; per-service scope (monorepo) → `catalog.stacks[].applicable_paths`. Confirm CLAUDE.md, rules, and skills output formats remain identical to today.
- [x] 3.5 Add model tier directive: `/generate` orchestrator SHALL run on Sonnet tier. Document the rationale (D5).
- [x] 3.6 Update the SKILL.md Reference Files table to point at `catalog-schema.json` and `catalog-format.md`. Remove (or deprecate) the per-service report parsing instructions from `references/skill-generation.md` if they exist as a separate input.
- [x] 3.7 Update the "If no report found" error message to reflect new artifact: "No catalog or legacy reports found. Run `/analyse` first to produce `.claudboard/catalog.json`."

## 4. Filesystem layout & .gitignore guidance

- [x] 4.1 Document in `skills/claudboard/references/catalog-format.md` the recommended `.gitignore` posture for projects: `.claudboard/` is build state and MAY be gitignored; teams who want to share the catalog across PRs may commit it instead. State the trade-off (committed catalog ↔ tracked artifact history; ignored catalog ↔ no merge conflicts on regeneration).
- [x] 4.2 Update generated CLAUDE.md template (`skills/claudboard/references/claude-md-template.md`) to add a brief note about `.claudboard/` if the project has one: "Build state from `/analyse` lives in `.claudboard/`; not loaded by Claude Code at runtime. Re-run `/analyse` to refresh; run `/analyse --audit` for per-service detail."
- [x] 4.3 Confirm `.claudboard/audits/<svc>.md` files include the existing YAML frontmatter pattern (`generated_at`, `repo`, `monorepo_service: true`, etc.) — no shape change to per-service reports themselves, only their location and production trigger. [Documented in analyse SKILL.md Phase 3 ✓]

## 5. Spec & capability updates

- [x] 5.1 (handled by /opsx:apply via the delta specs in `specs/`) Add new capability spec `openspec/specs/convention-catalog/spec.md` from the change's `specs/convention-catalog/spec.md` delta.
- [x] 5.2 (handled by /opsx:apply) Apply MODIFIED deltas to `openspec/specs/per-service-analysis/spec.md`, `openspec/specs/monorepo-generation/spec.md`, `openspec/specs/analyse-performance/spec.md` per the change's `specs/` deltas.

## 6. Cost & quality validation (gates before merge)

- [x] 6.1 Run default `/analyse` on craftsphere.cloud (19-service monorepo, real-world baseline). Measure with `compute-cost.sh`. Acceptance: ≤$150. [**Measured 2026-06-01: ~$27 Vertex (Opus 4.7, 50 calls, 4.4M cw5). PASS.** See design.md → Validation.]
- [ ] 6.2 Run `/analyse --audit` on craftsphere.cloud. Measure. Acceptance: ≤$250 (down from measured $417 today). [Deferred — projected ~$70-85 from 6.1 scaling.]
- [x] 6.3 Run `/generate` against the default-mode catalog from 6.1. Measure. Acceptance: ≤$25. [**Measured 2026-06-01: $11.31 (Sonnet 4.6). PASS.** Script and `/cost` agree.]
- [ ] 6.4 Diff the `.claude/` artifacts produced in 6.3 against a baseline `/generate` run sourced from a full-audit catalog. Acceptance: substantively equivalent (same CLAUDE.md structure, same rules generated, same skills generated; minor wording differences acceptable). If diff is substantive (missing rules, missing skill scaffolds, divergent conventions), the catalog content contract in spec is incomplete — fix and re-test. [Blocked on 6.2.]
- [ ] 6.5 Run default `/analyse` on a single-project repo (e.g. GardenMind, the prior baseline). Measure. Acceptance: ≤$15 (cost-neutral or modestly better than the $8.17 measured Opus-baseline; the asymmetric tier should help even on single-project). [Deferred — needs target repo selection.]
- [x] 6.6 Document the measured numbers in a final "Validation" section appended to `design.md` before merge. If any acceptance criterion fails, do not merge — revise the proposal honestly. [Validation section appended 2026-06-02; covers 6.1 + 6.3; 6.2/6.4/6.5 marked open.]

## 7. Documentation & communication

- [x] 7.1 Update the claudboard `README.md` to describe the new layout (`.claudboard/catalog.json` primary, `.claudboard/audits/` opt-in, `.claude/` unchanged for runtime context). One paragraph; no behavioural change to other skills.
- [x] 7.2 Add a short "Migration from older claudboard" section to the README: existing projects' first `/generate` call will auto-migrate; subsequent runs use the catalog.
- [x] 7.3 Add a "Per-task cost" note to README pointing at this change for context on default vs `--audit` cost expectations.

## 8. Memory and proposal cleanup

- [x] 8.1 Update or create a `catalog-as-primary-artifact` memory file documenting: the empirical finding that `.claude/reports/` are not auto-loaded, the conflated-products diagnosis, the catalog/audit split, and the asymmetric tier rationale. This is the kind of architectural learning future sessions need to remember.
- [x] 8.2 Note in `MEMORY.md` index that the analyse→generate pipeline is now catalog-mediated; per-service reports are audit-only.
- [x] 8.3 Mark the `speed-up-analyse` cost-baseline claims as superseded by this change's measurements (the original "$1-2 single-project" claim was Sonnet-assumed; corrected baselines are in 6.1-6.5). [Documented in memory file and SKILL.md cost context note]

## 9. Out-of-scope follow-ups to file as separate changes

These are explicitly out of scope for this change. They are listed here so they don't get forgotten.

- [ ] 9.1 `/refresh` redesign to diff against catalog instead of re-scanning. The catalog makes this dramatically cheaper to implement; should be the immediate next change.
- [ ] 9.2 Cost preview in `/analyse`'s scope-confirmation `AskUserQuestion`. Needs a calibration table; orthogonal to this restructure.
- [ ] 9.3 Plugin-namespace gate fix for the `cost-reporting` stop hook so `/claudboard:claudboard-analyse` invocations actually fire the cost line. Separate capability (`cost-reporting`); should be its own change.
- [ ] 9.4 Workspace-mode catalog adaptation (per-repo catalogs + optional workspace rollup). Different invariants from single-project/monorepo; deserves its own design pass.
- [ ] 9.5 Aggressive tier flag (`--tier=aggressive` to route extraction to Haiku). Revisit once conservative tier ships and calibration data accumulates.
