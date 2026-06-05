## REMOVED Requirements

### Requirement: Pre-create workspace reports directory before per-repo fan-out
**Reason:** Workspace mode no longer fans out per-repo sub-agents in default mode (per the unified `analyse-performance` MODIFIED requirement). The pre-creation of `<workspace>/.claude/reports/` is now handled inline in Phase 3 alongside `.claudboard/` directory creation, regardless of mode.

### Requirement: Per-repo analysis fan-out via parallel sub-agents
**Reason:** Default-mode workspace `/analyse` no longer fans out per-repo sub-agents. Sub-agent fan-out is now `--audit`-only and follows the unified monorepo `--audit` protocol (one Sonnet sub-agent per service, output to `.claudboard/audits/<svc>.md`). The library-handled-inline rule is preserved in the unified flow.

### Requirement: Sub-agent prompt template for per-repo analysis
**Reason:** Replaced by the unified `--audit` sub-agent prompt template defined in `per-service-analysis`. The workspace-specific prompt (with workspace-root path and per-repo report path) is superseded by the unified one (with service path and `.claudboard/audits/<svc>.md` path).

### Requirement: Per-repo report file path and frontmatter
**Reason:** Per-repo report files are no longer written by default `/analyse` in workspace mode. The `--audit` mode writes per-service files at `<umbrella>/.claudboard/audits/<svc>.md` per the unified `per-service-analysis` requirement; the frontmatter shape carries over to that location.

### Requirement: Workspace summary report path and frontmatter
**Reason:** The standalone `claudboard-analysis-workspace.md` summary file is replaced by the unified `<umbrella>/.claude/reports/claudboard-analysis.md` thin summary defined in `analyse-performance`. The summary's content scope is unchanged (workspace topology, dependency graph, per-service summary table, library inventory, proposed artifacts) but the file path collapses to the unified umbrella path.

### Requirement: Write verification before graph construction
**Reason:** No longer applicable in default mode (no per-repo reports are written). For `--audit` mode, the existing `per-service-analysis` write-verification requirement applies symmetrically across workspace and monorepo.

### Requirement: Phase 3 save behaviour for workspace mode
**Reason:** Phase 3 no longer has a workspace-specific branch. The unified Phase 3 (defined in `analyse-performance`) handles all three modes — single-project, monorepo, workspace — by writing to `<umbrella_root>/.claudboard/` and `<umbrella_root>/.claude/reports/`. The path manifest at completion lists umbrella-root files only.

## MODIFIED Requirements

### Requirement: Ecosystem.md authorship boundary in workspace mode

The orchestrator SHALL write a single umbrella-wide `<umbrella_root>/.claude/memories/ecosystem.md` for workspace mode (and monorepo mode). Sub-agents SHALL NOT write any ecosystem.md file. (Sub-agents in workspace mode are spawned only during `--audit` and operate on a single service in isolation; they do not have cross-service graph context.)

This replaces the prior per-repo authorship boundary, which assumed per-repo ecosystem.md files. With the umbrella-only rule, there is exactly one ecosystem.md per project, and it is always orchestrator-authored.

#### Scenario: Sub-agents do not write ecosystem.md
- **WHEN** an `--audit` sub-agent completes per-service analysis in workspace mode
- **THEN** the sub-agent SHALL NOT create or modify any `ecosystem.md` file

#### Scenario: Orchestrator writes umbrella ecosystem.md once per run
- **WHEN** Phase 1 graph construction completes in workspace or monorepo mode
- **THEN** the orchestrator writes exactly one `ecosystem.md` at `<umbrella_root>/.claude/memories/ecosystem.md`
