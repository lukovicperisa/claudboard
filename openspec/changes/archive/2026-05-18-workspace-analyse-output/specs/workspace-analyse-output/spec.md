## ADDED Requirements

### Requirement: Pre-create workspace reports directory before per-repo fan-out
In workspace mode, after topology presentation and user confirmation (per `workspace-detection`), the system SHALL ensure `<workspace>/.claude/reports/` exists before dispatching any per-repo analysis work. The directory SHALL be created if missing.

The system SHALL NOT require `<workspace>/.claude/` to be a symlink to a meta-repo at this stage — `/analyse` is permitted to run before `/claudboard-workspace-init`. Files written here will be migrated by a subsequent `/claudboard-workspace-init` (per the bootstrap migration requirements).

#### Scenario: Reports directory missing
- **WHEN** workspace mode is confirmed AND `<workspace>/.claude/reports/` does not exist
- **THEN** the system SHALL create `<workspace>/.claude/reports/` recursively before dispatching sub-agents

#### Scenario: Reports directory already exists
- **WHEN** workspace mode is confirmed AND `<workspace>/.claude/reports/` already exists
- **THEN** the system SHALL proceed without modification (idempotent)

#### Scenario: Workspace .claude is a symlink to a bootstrapped meta-repo
- **WHEN** `<workspace>/.claude` is a symlink to a meta-repo's `.claude/` directory
- **THEN** the system SHALL write into the resolved path through the symlink (no special-casing needed); pre-creation MAY be a no-op when the resolved `reports/` directory already exists

### Requirement: Per-repo analysis fan-out via parallel sub-agents
In workspace mode, the per-repo Phase 1b–1h analysis SHALL be dispatched as parallel sub-agent invocations — one Agent invocation per service repo — issued in a single tool-call batch.

Library repos SHALL NOT be dispatched as sub-agents. The orchestrator SHALL handle libraries inline with a lighter scan (no quality scoring, no Watch/Preserve, just identity and dependency surface).

The number of sub-agents dispatched SHALL equal the number of service repos detected in Phase 1a topology presentation.

#### Scenario: Parallel dispatch in single batch
- **WHEN** workspace mode topology lists N service repos AND the user confirms
- **THEN** the system SHALL issue exactly N Agent tool calls in a single message, one per service repo

#### Scenario: Library repos handled inline
- **WHEN** the topology includes M library repos
- **THEN** the orchestrator SHALL NOT dispatch sub-agents for them; library identity and metadata SHALL be collected by the orchestrator directly

#### Scenario: Single-repo workspace edge case
- **WHEN** the workspace contains exactly one service repo
- **THEN** the system MAY dispatch a single sub-agent OR perform the analysis inline; the per-repo report path requirement applies regardless

### Requirement: Sub-agent prompt template for per-repo analysis
Each sub-agent dispatched in workspace mode SHALL receive a prompt that explicitly contains:

1. The absolute path of the repo to analyse
2. The absolute path of the report file to write: `<workspace>/.claude/reports/claudboard-analysis-<repo-name>.md`
3. An instruction to run Phases 1b–1h scoped to that repo, following `claudboard-analyse/SKILL.md`
4. An instruction to **write the full report file before returning**, including the standard frontmatter (`generated_at`, `repo`, `version`)
5. An instruction to RETURN ONLY a compact YAML summary block — service identity, communication surface, quality scores, top Watch findings — for orchestrator graph construction

Sub-agent return text SHALL NOT include the full report body. The full report MUST already be on disk by the time the agent returns.

#### Scenario: Prompt includes both paths
- **WHEN** a sub-agent is dispatched for repo `order-service` in workspace `/Users/x/meas/`
- **THEN** the prompt SHALL contain the absolute repo path `/Users/x/meas/order-service` AND the absolute report path `/Users/x/meas/.claude/reports/claudboard-analysis-order-service.md`

#### Scenario: Sub-agent returns compact summary
- **WHEN** a sub-agent completes its repo analysis
- **THEN** it SHALL return a YAML block containing at minimum: service identity, inbound surface, outbound surface, quality scores per dimension, average score, top 3 Watch findings (severity + one-liner)
- **AND** the orchestrator SHALL be able to use this YAML directly for Phase 1c graph construction without re-reading the per-repo report file

### Requirement: Per-repo report file path and frontmatter
Each per-repo analysis report in workspace mode SHALL be written to `<workspace>/.claude/reports/claudboard-analysis-<repo-name>.md`, where `<repo-name>` is the service repo's directory basename used as-is (no transformation).

The report SHALL include YAML frontmatter:

```yaml
---
generated_at: <ISO 8601 timestamp>
repo: <absolute path to the service repo, NOT the workspace>
version: "<schema version, e.g. 2.1.0>"
workspace_member: true
workspace_root: <absolute path to the workspace root>
---
```

#### Scenario: Per-repo report path
- **WHEN** workspace `/Users/x/meas/` contains service repo `order-service` AND analysis completes
- **THEN** the report SHALL exist at `/Users/x/meas/.claude/reports/claudboard-analysis-order-service.md`

#### Scenario: Frontmatter `repo` field
- **WHEN** a per-repo report is written
- **THEN** the `repo:` field SHALL contain the absolute path of the service repo, NOT the workspace root

#### Scenario: Frontmatter `workspace_root` field
- **WHEN** a per-repo report is written
- **THEN** the `workspace_root:` field SHALL contain the absolute path to the workspace root, allowing downstream tools to find sibling reports

### Requirement: Workspace summary report path and frontmatter
After Phases 1c (graph construction) and 1d (ecosystem injection) complete, the orchestrator SHALL write a workspace-level summary report to `<workspace>/.claude/reports/claudboard-analysis-workspace.md`.

The summary SHALL include YAML frontmatter:

```yaml
---
generated_at: <ISO 8601 timestamp>
workspace_root: <absolute path to the workspace root>
version: "<schema version, e.g. 2.1.0>"
workspace: true
repos:
  - <repo-name>
  - <repo-name>
  ...
libraries:
  - <library-name>
  ...
---
```

The summary body SHALL contain (at minimum): workspace topology, dependency graph, cross-service warnings, per-repo summary table (one row per service repo with average quality score), library inventory, and proposed global artifacts.

#### Scenario: Workspace summary path
- **WHEN** workspace mode analysis completes
- **THEN** the summary SHALL exist at `<workspace>/.claude/reports/claudboard-analysis-workspace.md`

#### Scenario: Frontmatter `workspace: true`
- **WHEN** the workspace summary is written
- **THEN** its frontmatter SHALL contain `workspace: true`

#### Scenario: Frontmatter `repos` enumeration
- **WHEN** the workspace summary is written for a workspace with N service repos
- **THEN** the `repos:` list SHALL contain exactly N entries, matching the per-repo report basenames (without the `claudboard-analysis-` prefix or `.md` suffix)

### Requirement: Write verification before graph construction
After all sub-agents return, the orchestrator SHALL verify each expected per-repo report file exists at its target path before proceeding to Phase 1c graph construction.

If any expected file is missing, the orchestrator SHALL re-run that single repo's analysis serially (in the orchestrator's own context, not via sub-agent) before continuing. The orchestrator SHALL NOT proceed to graph construction with missing reports.

#### Scenario: All reports present
- **WHEN** N sub-agents return AND all N expected report files exist
- **THEN** the orchestrator SHALL proceed to Phase 1c

#### Scenario: One report missing
- **WHEN** N sub-agents return AND M < N expected report files exist
- **THEN** the orchestrator SHALL re-run the N-M missing repos serially before proceeding to Phase 1c
- **AND** the orchestrator SHALL log the missing-then-recovered repos in the workspace summary's "Notes" section

#### Scenario: Sub-agent returns no summary YAML
- **WHEN** a sub-agent's report file exists but the returned summary YAML is missing or malformed
- **THEN** the orchestrator SHALL re-derive the summary by reading the per-repo report file (acceptable fallback) and proceed

### Requirement: Ecosystem.md authorship boundary
The orchestrator, NOT the per-repo sub-agents, SHALL write `<repo>/.claude/memories/ecosystem.md` files. Sub-agents have no graph context and therefore cannot populate ecosystem content correctly.

This requirement clarifies but does not change the file path or content defined by the `ecosystem-injection` capability.

#### Scenario: Sub-agents do not write ecosystem.md
- **WHEN** a sub-agent completes per-repo analysis
- **THEN** the sub-agent SHALL NOT create or modify any `ecosystem.md` file

#### Scenario: Orchestrator writes ecosystem.md after Phase 1c
- **WHEN** Phase 1c (graph construction) completes AND the user confirms the graph
- **THEN** the orchestrator SHALL write one `ecosystem.md` per service repo (per `ecosystem-injection`)

### Requirement: Phase 3 save behaviour for workspace mode
The Phase 3 "Save Report & Next Steps" stage of `/analyse` SHALL handle workspace mode as a third case alongside single-project and monorepo.

Workspace mode Phase 3 SHALL:
1. Verify all per-repo reports exist (already required above) and the workspace summary is written
2. Print a path manifest listing all written report files
3. Offer the same "generate now or in fresh session?" prompt as the existing modes, with the recommendation framed for workspace scope

#### Scenario: Path manifest printed
- **WHEN** workspace mode Phase 3 runs
- **THEN** the system SHALL print a list of all written paths: workspace summary path AND each per-repo report path AND each ecosystem.md path

#### Scenario: Generate prompt offered
- **WHEN** workspace mode Phase 3 completes
- **THEN** the system SHALL ask whether to run `/generate` now or defer; deferring SHALL print "Analysis saved. Run `/generate` from the workspace root in a fresh session when ready."
