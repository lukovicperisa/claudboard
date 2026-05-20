## 1. Author the parallel sub-agent protocol in `claudboard-analyse/SKILL.md`

- [x] 1.1 Add a new subsection "Workspace parallelisation protocol" to Phase 1a, immediately after "Step 3: Topology presentation"
- [x] 1.2 Document pre-creation of `<workspace>/.claude/reports/` (recursive, idempotent) before fan-out
- [x] 1.3 Document the single-batch parallel Agent dispatch pattern (one Agent invocation per service repo, all in one tool-call message)
- [x] 1.4 Document the library-handling carve-out (libraries handled inline by orchestrator, not delegated)
- [x] 1.5 Provide the verbatim sub-agent prompt template, parameterised by `<repo-path>`, `<report-path>`, and `<workspace-root>`. Include all five required prompt elements (repo path, report path, phase scope, write-before-return, return-only-summary)
- [x] 1.6 Document the YAML summary schema the sub-agent must return (service identity, inbound/outbound surface, quality scores, top 3 Watch findings)
- [x] 1.7 Document the write-verification step after sub-agents return; specify the serial-recovery path for missing files

## 2. Update Phase 1d (ecosystem injection) attribution note

- [x] 2.1 Add a one-line note at the top of Phase 1d: "Ecosystem files are written by the orchestrator after Phase 1c, NOT by per-repo sub-agents — sub-agents have no graph context."
- [x] 2.2 Confirm the existing `<repo-dir>/.claude/memories/ecosystem.md` path language remains unchanged

## 3. Update Phase 3 "Save Report & Next Steps" with workspace case

- [x] 3.1 Add a new "Workspace mode" subsection alongside the existing single-project and monorepo subsections
- [x] 3.2 Document the per-repo report path (`<workspace>/.claude/reports/claudboard-analysis-<repo-name>.md`) and confirm sub-agents have already written them
- [x] 3.3 Document the workspace summary path (`<workspace>/.claude/reports/claudboard-analysis-workspace.md`) and the orchestrator writes it after Phase 1c+1d
- [x] 3.4 Document the required frontmatter for per-repo reports (`workspace_member: true`, `workspace_root: <path>`)
- [x] 3.5 Document the required frontmatter for the workspace summary (`workspace: true`, `repos: [...]`, `libraries: [...]`)
- [x] 3.6 Document the Phase 3 path manifest output (list every written file path) and the workspace-scoped generate prompt

## 4. Update Constraints section

- [x] 4.1 Update the "Constraints" section to reflect that workspace mode writes per-repo report files, a workspace summary file, AND per-repo `ecosystem.md` files (was previously: "the only file written is `.claude/reports/claudboard-analysis.md`")

## 5. Update Reference Files table

- [ ] 5.1 No new reference files are introduced; confirm the existing reference table needs no changes

## 6. End-to-end validation against MEAS workspace

- [ ] 6.1 Re-run `/analyse` from `/Users/LUP1BG/Documents/BoschProjects/meas/` after the SKILL.md changes land
- [ ] 6.2 Verify `<workspace>/.claude/reports/claudboard-analysis-<repo>.md` exists for every detected service repo (8 expected for MEAS)
- [ ] 6.3 Verify `<workspace>/.claude/reports/claudboard-analysis-workspace.md` exists with `workspace: true` and the correct `repos:` enumeration in frontmatter
- [ ] 6.4 Verify `<workspace>/<repo>/.claude/memories/ecosystem.md` exists for every service repo (libraries excluded)
- [ ] 6.5 Verify all per-repo report `repo:` frontmatter fields contain the absolute service-repo path (NOT the workspace root)
- [ ] 6.6 Verify all per-repo report `workspace_root:` frontmatter fields point at the workspace root
- [ ] 6.7 Verify the orchestrator's parallel dispatch happened in a single tool-call batch (inspect agent trace if available)
- [ ] 6.8 Verify the fallback recovery path: artificially break one sub-agent's prompt, confirm the orchestrator detects the missing file and recovers serially

## 7. Coordination tasks

- [ ] 7.1 After this change lands, unblock `workspace-feature-workflow` tasks 10.3 and 10.5 (they require per-repo reports to exist)
- [ ] 7.2 Confirm no conflict with `monorepo-support` change (different mode, no shared file paths)
