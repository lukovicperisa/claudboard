## Why

`/analyse` takes ~10 minutes on smaller projects and close to an hour on multi-repo workspaces, with per-run cost estimated at $1-2 (single-project) to $5-10+ (workspace) **on Sonnet 4.6 pricing**. Opus 4.7 runs the same workload at roughly **5× the cost** — a 2026-05-31 measured run of `/analyse` against GardenMind (Turborepo, 1 service, 556 files) on Opus 4.7 came to **$8.17** across 25 API calls (108K cache_write_1h, 1.87M cache_read accumulated across iterations, 28K output). The optimisations below shrink token volume and tool-call count regardless of model; the headline dollar figures assume Sonnet. Static measurement of this repo shows the bottleneck is tool-call round-trips and bloated raw `grep` output in the conversation tail, not report generation: the analyse SKILL.md is 1,035 lines (~11.9K tokens) loaded every run, the grep universe a Java workspace run could fire is ~200 commands, and unconditional reference loads add ~14K tokens of often-irrelevant content per run. The cost shape is fixable without changing what `/analyse` detects or how it reports — by consolidating discovery work into one bash invocation, gating reference loads on detected signals, making elastic phases truly elastic, and trimming the always-loaded SKILL.md.

## What Changes

- **Add `skills/claudboard-analyse/scripts/discover.sh`** that runs the discovery work currently spread across Phase 1b (global file scan), Phase 1c (Wide Scan), and Phase 1g (duplication detection) as a single bash invocation per repo. Emits a structured JSON discovery report that the model reads in one tool call instead of ~40-50 individual greps. Language-specific grep sets contribute via composable sub-scripts under `scripts/lang/`.
- **Gate reference loading on Phase 1b detection signals.** Skip `edges/messaging.md`, `edges/streaming.md`, `edges/graphql.md`, and `patterns/architectural.md` when their trigger keywords are absent from the discovery JSON. Document the gates in the analyse SKILL.md as machine-readable conditionals.
- **Make Phase 1f (call-path tracing) and Phase 1g (duplication detection) elastic.** Drop async/auth/external path types when their signals are absent from the discovery JSON (instead of padding to a fixed 3-5 paths). Skip duplication detection entirely when the repo has fewer than 30 source files.
- **Shrink analyse SKILL.md** by moving the inline Wide Scan trigger catalogs (Spring annotations, frontend hooks, Python decorators, infrastructure markers) and the inline anti-pattern grep block out of the SKILL.md and into the `stack-detectors-*.md` language packs (where they are language-specific data, not procedure). Target: cut analyse SKILL.md from ~11.9K tokens to ~7-8K tokens.
- **No change to report format, frontmatter, file paths, or detected content.** Backwards compatible with existing `.claude/reports/claudboard-analysis*.md` consumers (`/generate`, `/refresh`, `/claudboard-workflow`).

## Capabilities

### New Capabilities
- `analyse-performance`: Performance discipline for `/analyse` — discovery-script consolidation contract, conditional reference loading gated on detection signals, elastic-phase rules, and SKILL.md size budget. Defines the invariants that keep `/analyse` fast and cheap across single-project, monorepo, and workspace modes.

### Modified Capabilities
<!-- No existing capability requirements change. The behavior detected by monorepo-detection, workspace-detection, per-service-analysis, cross-service-graph, workflow-signals-detection, architectural-patterns-detection, etc. all remain identical — only the execution path that produces those detections changes. -->

## Impact

- **Affected files (analyse skill):**
  - `skills/claudboard-analyse/SKILL.md` — modified (trim, add discovery-script invocation, document conditional ref loads, document elastic-phase rules)
  - `skills/claudboard-analyse/scripts/discover.sh` — new
  - `skills/claudboard-analyse/scripts/lang/*.sh` — new (per-language grep packs the orchestrator script composes)
  - `skills/claudboard/references/stack-detectors-*.md` — modified (absorb the trigger catalogs and anti-pattern greps moved out of SKILL.md)
- **Affected behavior:** none externally observable. Reports retain the same sections, YAML frontmatter, and content fidelity.
- **Downstream consumers (unchanged):** `/generate`, `/refresh`, `/claudboard-workflow`, `/techdebt` all read `.claude/reports/claudboard-analysis*.md` with the same format.
- **Workspace mode:** sub-agents invoke the same `discover.sh` scoped to their repo, so workspace mode inherits the speedup automatically — orchestrator coordination logic is unchanged.
- **Risk:** discovery-script output schema becomes a contract. If the script and SKILL.md drift, analyse fails opaquely. Mitigation: script emits a `schema_version` field and SKILL.md asserts on it.
- **Out of scope:** workspace parallel fan-out audit (cost-neutral; separate concern), perf passes on `/generate`/`/refresh`/`/techdebt` (learnings can be applied later but not bundled here), the in-flight `slim-feature-workflow-*` changes (different surface).
