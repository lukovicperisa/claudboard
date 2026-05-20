## Why

`/analyse` already detects workspace mode (via `workspace-detection`), constructs the cross-service graph (via `cross-service-graph`), and writes per-repo `ecosystem.md` files (via `ecosystem-injection`). What it does **not** define anywhere — in any active or archived spec — is *where the per-repo analysis report files go on disk* in workspace mode. The single-project case writes `.claude/reports/claudboard-analysis.md`; the monorepo case writes a global report plus per-service variants under `.claude/reports/`. Workspace mode has no analogous contract.

This gap surfaced in production: a 12-repo run on the MEAS workspace produced no per-repo report files. The orchestrator parallelised per-repo Phase 1b–1h work into 12 sub-agents (a reasonable interpretation of the "per-repo loop" instruction), but with no defined target path, no agent wrote a report. `/generate` then had nothing to read for any repo.

This change defines the workspace-mode output contract: the parallel sub-agent protocol, the per-repo report file path, the workspace summary file path, and the orchestrator's responsibility to verify writes before proceeding to graph construction.

## What Changes

- **NEW: parallel sub-agent protocol for workspace-mode `/analyse`** — workspace mode SHALL fan out per-repo Phase 1b–1h work into one Agent invocation per service repo, dispatched in a single batch (parallel). Each sub-agent receives a templated prompt that names the exact repo path, the exact report file path to write, and the structured YAML summary to return.
- **NEW: per-repo report file contract** — every service repo's analysis report SHALL be written to `<workspace>/.claude/reports/claudboard-analysis-<repo-name>.md`. The sub-agent writes the file before returning. The orchestrator pre-creates `<workspace>/.claude/reports/` before fan-out.
- **NEW: workspace summary report contract** — after sub-agents return and Phases 1c (graph) and 1d (ecosystem) complete, the orchestrator SHALL write `<workspace>/.claude/reports/claudboard-analysis-workspace.md`, containing workspace topology, dependency graph, cross-service warnings, per-repo summary table, and proposed global artifacts. Frontmatter SHALL include `workspace: true` and `repos: [<repo-name>, ...]`.
- **NEW: ecosystem.md attribution clarification** — `ecosystem.md` files (defined by `ecosystem-injection`) SHALL be written by the orchestrator after Phase 1c, **not** by the per-repo sub-agents. Sub-agents have no graph context. This clarifies the existing `ecosystem-injection` requirement; it does not change the file location or format.
- **NEW: write-verification step** — after sub-agents return, the orchestrator SHALL verify each expected report file exists. Any missing file SHALL trigger a serial re-run of that single repo before proceeding to Phase 1c.
- **NEW: library handling clarification** — library repos are NOT delegated to sub-agents. The orchestrator handles them inline (lighter scan, no quality scoring) and references them only in the workspace summary's library inventory section.
- **OUT OF SCOPE**: changes to single-project or monorepo output paths (unchanged); changes to graph construction or ecosystem.md content (covered by `cross-service-graph` and `ecosystem-injection` respectively); workspace summary's content layout (orchestrator may evolve this freely as long as the path and frontmatter contract holds).

## Capabilities

### New Capabilities
- `workspace-analyse-output`: The output contract for workspace-mode `/analyse`. Defines parallel sub-agent fan-out, per-repo report file path, workspace summary file path, frontmatter shape, write verification, library handling, and the ecosystem.md authorship boundary.

## Impact

- **MODIFIED skills**:
  - `skills/claudboard-analyse/SKILL.md` — add explicit "Workspace parallelisation protocol" subsection to Phase 1a (after topology presentation); add workspace case to Phase 3 "Save Report"; add a one-line note to Phase 1d (ecosystem injection) clarifying that the orchestrator writes ecosystem files, not the sub-agents.
- **NO new templates or helper scripts.** The sub-agent prompt template lives inline in the SKILL.md text.
- **Coordination with active changes**:
  - `workspace-feature-workflow` (in-flight) — once this change lands, the validation tasks (10.3, 10.5) under workspace-feature-workflow can run end-to-end because `/claudboard-workflow` will have report files to read. This change unblocks that change's MEAS validation.
  - `monorepo-support` (in-flight) — independent. Different mode (single git repo with multiple services); no overlap.
- **Real test target**: the same MEAS workspace at `/Users/LUP1BG/Documents/BoschProjects/meas/`. Re-run `/analyse` from the workspace root after this change lands; verify per-repo and workspace report files exist and contain the expected frontmatter and content.
