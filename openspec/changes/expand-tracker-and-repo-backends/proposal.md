## Why

The generated `feature-workflow` skill currently hard-codes exactly two MCP backends: Atlassian Jira for tracking and Azure DevOps for repositories. Real Bosch teams use other tools — notably Bosch Track & Release (T&R) via the in-house `bosch-jira-mcp`, and GitHub for source control. When the workflow runs against a non-supported MCP, it improvises against unfamiliar tools and degrades silently: worklog calls become extra comments, label updates overwrite instead of append, and ticket-create operations fail mid-phase. The fix is to expand from 2 to 4 first-class backends across 2 dimensions (tracker × repo), with explicit detection and explicit handling of each MCP's actual tool surface — no gray-zone improvisation.

## What Changes

- **Add `TRACKER_TR` capability flag** for Bosch Track & Release via `bosch-jira-mcp`. Implements a documented v1 subset of the Jira flow (no auto-create, no worklog, no sprint, AC inlined in description, labels via read-modify-write) reflecting the MCP's current 6-tool surface.
- **Add `REPO_GITHUB` capability flag** for the official GitHub MCP. Implements PR creation, Actions run verification, issue linking via `Closes #N` syntax, and Branch Protection Rules awareness — matching ADO at the intent level (different primitives, same workflow shape).
- **BREAKING: Rename capability flags** `JIRA_AVAILABLE` → `TRACKER_JIRA` and `ADO_AVAILABLE` → `REPO_ADO`. The old names become ambiguous once a parallel backend exists in each dimension.
- **BREAKING: Change `config.json` schema** to introduce `tracker` (`"jira" | "tr"`) and `repo` (`"ado" | "github"`) discriminator keys at the top level. Backend-specific config blocks (`jira`, `tr`, `azureDevOps`, `github`) are present only when their discriminator matches.
- **Add 4-MCP detection** to the orchestrator's Phase 1d with mutually-exclusive resolution per dimension. When two MCPs in the same dimension are detected → prompt the user. When neither → that dimension's phases are stubbed.
- **Add new agent files**: `tr-agent.md` (verbatim, conditional on `TRACKER_TR`) and `pr-agent-github.md` (verbatim, conditional on `REPO_GITHUB`). Rename `pr-agent.md.template` → `pr-agent-ado.md` and remove its `gh` CLI fallback (GitHub is now first-class via its own file).
- **Generalize tracker-aware blocks** in `architect-agent.md.template`, `implementation-agent.md.template`, and `spec-reviewer.md.template` so AC-handling, ticket cross-references, and AC-completeness checks work across both tracker backends (custom field on Jira, description body on T&R).
- **Split `references/jira-config-prompts.md`** into `tracker-config-prompts.md` (Jira + T&R sections) and `repo-config-prompts.md` (ADO + GitHub sections). Update `block-catalog.md` and `substitution-catalog.md` for the new flags and variables.

## Capabilities

### New Capabilities
- `tracker-backends`: Defines the action contract that both `jira-agent.md` and `tr-agent.md` implement (create, fetchAndPrepare, updateDescription, addLabels, addComment, transition, addWorklog), the Jira full-flow capability set, the T&R reduced-flow capability set, and the documented v1 gaps on T&R. Owns the per-backend MCP tool-mapping table.
- `repo-backends`: Defines the action contract that both `pr-agent-ado.md` and `pr-agent-github.md` implement (createPullRequest, linkTicket, verifyPipelineRun, respectBranchPolicy), the ADO flow, the GitHub flow (with `Closes #N` linking + Actions verification + Rulesets), and the divergences between primitives (repositoryId vs owner/repo slug, central policies vs per-rule protection).
- `mcp-detection`: Defines how the orchestrator's Phase 1d scans MCP configuration for the 4 supported servers, the detection keyword rules per backend, the mutually-exclusive resolution per dimension, and the user-prompt behaviour when both MCPs in a dimension are present. Also defines the stubbing rule when a dimension has zero MCPs detected.

### Modified Capabilities
- `feature-workflow-generation`: Orchestrator phase wrapping changes from single-backend `IF JIRA_AVAILABLE` / `IF ADO_AVAILABLE` conditionals to paired tracker-aware / repo-aware blocks. The `config.json` schema gains the `tracker` and `repo` discriminator keys. The capability-flag naming convention changes (the BREAKING rename above).

## Impact

- **Affected code**: `skills/claudboard-workflow/SKILL.md` (Phase 1d MCP detection), `skills/claudboard-workflow/references/block-catalog.md`, `skills/claudboard-workflow/references/substitution-catalog.md`, `skills/claudboard-workflow/references/jira-config-prompts.md` (split into two files), and the entire `skills/claudboard-workflow/references/feature-workflow.template/` tree (orchestrator `SKILL.md.template`, all 7 agent files, `config.json.template`).
- **Affected MCP surfaces**: Adds dependencies on `bosch-jira-mcp` (6 tools: `jira_search`, `jira_get_issue`, `jira_add_comment`, `jira_transition`, `jira_update_issue`, `jira_get_myself`) and the official GitHub MCP (PR + Actions + repository tools).
- **Backward compatibility**: Projects with hand-edited `feature-workflow/` copies (craftsphere, MEAS) are carved out from `claudboard-refresh` per existing project rules — no automatic migration. Projects where `claudboard-workflow` is the source of truth produce the new shape on next regeneration. A migration note in the completion report explains the old-flag → new-flag mapping.
- **Out of scope**: Extending `bosch-jira-mcp` with the missing tools (create, worklog, custom-field writes, atomic-add labels) — not in our control. The design is structured so adding those tools later enables additional blocks under `TRACKER_TR` without restructuring. Generic tracker abstractions, additional trackers (Linear, Notion), and `gh` CLI as a fallback path are all explicitly out of scope.
