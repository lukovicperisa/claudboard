## ADDED Requirements

### Requirement: Tracker-backend action contract

The system SHALL define a fixed action contract that every supported tracker agent (`jira-agent.md`, `tr-agent.md`) implements. Agents receive an `action` field in INPUT CONTEXT and dispatch on it. The orchestrator SHALL call actions by name regardless of which backend is active.

The v1 action set is: `create`, `fetchAndPrepare`, `updateDescription`, `addLabels`, `addComment`, `addWorklog`, `transition`.

#### Scenario: Action dispatch by name
- **WHEN** the orchestrator spawns a tracker agent with `action: "addComment"` and the backend is `TRACKER_JIRA`
- **THEN** `jira-agent.md` SHALL handle the action via `mcp__atlassian__addCommentToJiraIssue`

#### Scenario: Action dispatch on T&R
- **WHEN** the orchestrator spawns a tracker agent with `action: "addComment"` and the backend is `TRACKER_TR`
- **THEN** `tr-agent.md` SHALL handle the action via `mcp__bosch-jira-mcp__jira_add_comment`

#### Scenario: Action unavailable on backend
- **WHEN** the orchestrator invokes an action that the active backend does not support (e.g., `create` or `addWorklog` on `TRACKER_TR`)
- **THEN** the agent SHALL emit a structured error result block with `error: "Action <name> unavailable on TRACKER_TR — see v1 limitations"` and SHALL NOT improvise by substituting a different MCP tool

### Requirement: Jira backend full-flow capability set

The system SHALL implement the full Atlassian-Jira flow under the `TRACKER_JIRA` capability flag. The agent SHALL expose all v1 actions and SHALL map them to the Atlassian MCP tool surface.

The action-to-tool mapping for `TRACKER_JIRA` SHALL be:

| Action | MCP tool(s) |
|--------|-------------|
| `create` | `mcp__atlassian__createJiraIssue` |
| `fetchAndPrepare` | `mcp__atlassian__getJiraIssue` + `mcp__atlassian__searchJiraIssuesUsingJql` + `mcp__atlassian__getTransitionsForJiraIssue` + `mcp__atlassian__transitionJiraIssue` + `mcp__atlassian__editJiraIssue` + `mcp__atlassian__atlassianUserInfo` |
| `updateDescription` | `mcp__atlassian__editJiraIssue` with `fields.description` |
| `addLabels` | `scripts/jira-add-labels.sh` (REST `update.labels[{add:...}]`, atomic) |
| `addComment` | `mcp__atlassian__addCommentToJiraIssue` |
| `addWorklog` | `mcp__atlassian__addWorklogToJiraIssue` |
| `transition` | `mcp__atlassian__getTransitionsForJiraIssue` + `mcp__atlassian__transitionJiraIssue` |

#### Scenario: Create action on Jira
- **WHEN** the orchestrator invokes `create` with summary, description, AC, area, priority, and labelsToAdd
- **THEN** `jira-agent.md` SHALL create the issue via `createJiraIssue`, write AC to `customfield_<acceptanceCriteria>`, transition to start state, assign to current sprint via `customfield_<sprint>`, assign to self, and apply labels via the additive shell script

#### Scenario: Worklog action on Jira
- **WHEN** the orchestrator invokes `addWorklog` with timeSpent and comment
- **THEN** `jira-agent.md` SHALL post the worklog via `addWorklogToJiraIssue` with the comment as `commentBody`

### Requirement: T&R backend reduced-flow capability set (v1)

The system SHALL implement a documented v1 subset of the tracker flow under the `TRACKER_TR` capability flag. The agent SHALL map supported actions to the Bosch JIRA MCP tool surface and SHALL refuse unsupported actions with structured errors.

The action-to-tool mapping for `TRACKER_TR` SHALL be:

| Action | T&R support | MCP tool(s) |
|--------|-------------|-------------|
| `create` | NOT SUPPORTED | n/a — returns error |
| `fetchAndPrepare` | partial | `jira_get_issue` + `jira_transition` + `jira_get_myself` + `jira_update_issue` (no sprint assignment) |
| `updateDescription` | supported | `jira_update_issue` with `description` field |
| `addLabels` | supported via RMW | `jira_get_issue` → union with new labels → `jira_update_issue` with `labels` field (REPLACE semantics) |
| `addComment` | supported | `jira_add_comment` |
| `addWorklog` | NOT SUPPORTED | n/a — time data folded into final summary comment by orchestrator |
| `transition` | supported | `jira_transition` (with `targetStatus` or `transitionId`) |

#### Scenario: Create action unavailable on T&R
- **WHEN** the orchestrator invokes `create` and `TRACKER_TR` is active
- **THEN** `tr-agent.md` SHALL emit an error result block with `error: "Action create unavailable on TRACKER_TR — Path A (existing ticket key) is the only supported entry point"` and the orchestrator SHALL surface the error to the user before any further work begins

#### Scenario: Worklog action unavailable on T&R
- **WHEN** the orchestrator invokes `addWorklog` and `TRACKER_TR` is active
- **THEN** the orchestrator SHALL NOT spawn `tr-agent.md` for that action; instead, the time data SHALL be folded into the body of the Phase 7 final summary comment

#### Scenario: Additive labels via read-modify-write
- **WHEN** the orchestrator invokes `addLabels` with `labelsToAdd` and `TRACKER_TR` is active
- **THEN** `tr-agent.md` SHALL call `jira_get_issue` to read current labels, compute the union with `labelsToAdd` (deduplicated), and call `jira_update_issue` with the merged set; the result block SHALL include `preLabels`, `added`, and `postLabels`

#### Scenario: Sprint assignment skipped on T&R
- **WHEN** `fetchAndPrepare` runs on `TRACKER_TR`
- **THEN** `tr-agent.md` SHALL skip the sprint-assignment step (the underlying MCP does not write custom fields) and SHALL note `sprintAssigned: false, reason: "TRACKER_TR — no custom field write support"` in the result block

#### Scenario: AC inlined in description on T&R
- **WHEN** the `architect-agent` generates a ticket description for a `TRACKER_TR` workflow
- **THEN** the AC section SHALL be inlined into the description body (under a `## Acceptance Criteria` heading) instead of being written to a separate custom field

### Requirement: Tracker selection in config.json

The generated `config.json` SHALL include a top-level `tracker` discriminator key with value `"jira"` or `"tr"`. The corresponding backend-specific block (`jira` or `tr`) SHALL be present, and the other tracker backend's block SHALL be absent.

#### Scenario: Jira-only config
- **WHEN** `TRACKER_JIRA` is the active backend
- **THEN** `config.json` SHALL contain `"tracker": "jira"`, a populated `"jira": { cloudId, projectKey, urlBase, customFields, transitions }` block, and no `"tr"` key

#### Scenario: T&R-only config
- **WHEN** `TRACKER_TR` is the active backend
- **THEN** `config.json` SHALL contain `"tracker": "tr"`, a populated `"tr": { baseUrl, projectKey, transitions }` block (no `customFields` — T&R cannot write them, no `cloudId` — T&R uses bearer-token auth via the MCP's own config file), and no `"jira"` key

#### Scenario: Neither tracker configured
- **WHEN** neither `TRACKER_JIRA` nor `TRACKER_TR` is active (no tracker MCP detected)
- **THEN** `config.json` SHALL omit the `tracker` key and both backend blocks; the generated `SKILL.md` SHALL have no tracker phases

### Requirement: Tracker-agent file is verbatim and conditional

Each tracker-agent file SHALL be written to `agents/<backend>-agent.md` verbatim from the template tree (no substitution required) and SHALL only be written when its corresponding capability flag is true. Both agents MUST NOT be present in the same generated workflow.

#### Scenario: Jira agent written
- **WHEN** `TRACKER_JIRA` is true
- **THEN** `agents/jira-agent.md` SHALL be written verbatim and `agents/tr-agent.md` SHALL NOT be written

#### Scenario: T&R agent written
- **WHEN** `TRACKER_TR` is true
- **THEN** `agents/tr-agent.md` SHALL be written verbatim and `agents/jira-agent.md` SHALL NOT be written

#### Scenario: Neither tracker active
- **WHEN** neither tracker flag is true
- **THEN** neither `agents/jira-agent.md` nor `agents/tr-agent.md` SHALL be written

### Requirement: T&R authentication and MCP server name convention

The `tr-agent.md` SHALL assume the MCP server is registered under a name matching the detection keyword (`bosch-jira-mcp` is the canonical name; tool prefix `mcp__bosch-jira-mcp__*` is expected). Authentication is handled by the MCP itself reading a bearer token from `~/.config/bosch-jira-mcp/config.json`; the agent SHALL NOT pass or read credentials directly.

#### Scenario: Canonical MCP server name
- **WHEN** `tr-agent.md` invokes a tracker action
- **THEN** every tool reference SHALL use the prefix `mcp__bosch-jira-mcp__<tool>` and the agent SHALL NOT attempt to discover the MCP server name at runtime

#### Scenario: MCP auth failure surfaced
- **WHEN** the underlying MCP returns an authentication error
- **THEN** `tr-agent.md` SHALL emit an error result block including the MCP's error text and the remediation hint "Check `~/.config/bosch-jira-mcp/config.json` bearer token"

### Requirement: Documented v1 limitations on T&R

The completion report from `claudboard-workflow` SHALL list the v1 T&R limitations when `TRACKER_TR` is the selected backend, so users understand what the generated workflow can and cannot do.

#### Scenario: T&R limitations listed in completion report
- **WHEN** generation completes with `TRACKER_TR` active
- **THEN** the completion report SHALL include a "T&R v1 limitations" section enumerating: no auto-create ticket (Path A only), no sprint assignment, no worklog (time folded into final comment), AC inlined in description, labels via read-modify-write (non-atomic). Each item SHALL note that the limitation can be lifted when the underlying MCP gains the corresponding tool.
