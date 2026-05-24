## ADDED Requirements

### Requirement: Defensive newline normalization for addComment

Every tracker agent (`jira-agent.md`, `tr-agent.md`) implementing the `addComment` action SHALL normalize the `commentBody` value before invoking the underlying MCP tool. The normalization SHALL perform exactly two substring replacements, in order:

1. Replace every literal `</n>` substring with the empty string.
2. Replace every literal `\n` (the two-character backslash-n sequence) with a real LF newline character.

The replacements SHALL be exact substring matches (no regex, no escaping context). The normalization SHALL be idempotent: when the input contains no `</n>` or literal `\n` sequences, the output equals the input. The normalization SHALL apply only to the `addComment` action; it SHALL NOT be applied to `addWorklog`, `updateDescription`, `create`, or any other action.

#### Scenario: Clean input passes through unchanged
- **WHEN** `addComment` receives a `commentBody` with real LF newlines and no literal `\n` or `</n>` sequences
- **THEN** the body is forwarded to the MCP tool byte-for-byte unchanged

#### Scenario: Literal escape sequences are decoded
- **WHEN** `addComment` receives a `commentBody` like `"## Title\n\nBody text"` where `\n` is the two-character sequence
- **THEN** the agent forwards `"## Title\n\nBody text"` with real LF newlines to the MCP tool, and the rendered tracker comment contains a heading on one line and a paragraph below

#### Scenario: Improvised pseudo-tag is stripped
- **WHEN** `addComment` receives a `commentBody` containing `"...total $9.72</n></n>Merge order:..."`
- **THEN** the agent strips both `</n>` substrings before forwarding, producing `"...total $9.72Merge order:..."` (and any preceding real-newline normalization still applies if `\n` is also present)

#### Scenario: Normalization order matters
- **WHEN** `addComment` receives a `commentBody` containing `"foo\n</n>bar"`
- **THEN** the agent first strips `</n>` to produce `"foo\nbar"`, then decodes `\n` to LF, yielding a body with a real newline between `foo` and `bar`

## MODIFIED Requirements

### Requirement: Jira backend full-flow capability set

The system SHALL implement the full Atlassian-Jira flow under the `TRACKER_JIRA` capability flag. The agent SHALL expose all v1 actions and SHALL map them to the Atlassian MCP tool surface.

The action-to-tool mapping for `TRACKER_JIRA` SHALL be:

| Action | MCP tool(s) |
|--------|-------------|
| `create` | `mcp__atlassian__createJiraIssue` |
| `fetchAndPrepare` | `mcp__atlassian__getJiraIssue` + `mcp__atlassian__searchJiraIssuesUsingJql` + `mcp__atlassian__getTransitionsForJiraIssue` + `mcp__atlassian__transitionJiraIssue` + `mcp__atlassian__editJiraIssue` + `mcp__atlassian__atlassianUserInfo` |
| `updateDescription` | `mcp__atlassian__editJiraIssue` with `fields.description` |
| `addLabels` | `scripts/jira-add-labels.sh` (REST `update.labels[{add:...}]`, atomic) |
| `addComment` | `mcp__atlassian__addCommentToJiraIssue` (preceded by the defensive newline normalization step) |
| `addWorklog` | `mcp__atlassian__addWorklogToJiraIssue` |
| `transition` | `mcp__atlassian__getTransitionsForJiraIssue` + `mcp__atlassian__transitionJiraIssue` |

#### Scenario: Create action on Jira
- **WHEN** the orchestrator invokes `create` with summary, description, AC, area, priority, and labelsToAdd
- **THEN** `jira-agent.md` SHALL create the issue via `createJiraIssue`, write AC to `customfield_<acceptanceCriteria>`, transition to start state, assign to current sprint via `customfield_<sprint>`, assign to self, and apply labels via the additive shell script

#### Scenario: Worklog action on Jira
- **WHEN** the orchestrator invokes `addWorklog` with `timeSpent` and `comment`
- **THEN** `jira-agent.md` SHALL post the worklog via `addWorklogToJiraIssue` with the comment as `commentBody`; the comment SHALL be a fixed terse single-line label of either `"Requirement refinement work"` (Phase 1 worklog) or `"Implementation work"` (Phase 6/7 worklog) — never a multi-line, multi-paragraph, or multi-repo aggregated body

#### Scenario: Comment action on Jira applies defensive normalization
- **WHEN** the orchestrator invokes `addComment` with a `commentBody`
- **THEN** `jira-agent.md` SHALL first apply the defensive newline normalization specified by the "Defensive newline normalization for addComment" requirement, then invoke `mcp__atlassian__addCommentToJiraIssue` with `contentFormat: "markdown"`

### Requirement: T&R backend reduced-flow capability set (v1)

The system SHALL implement a documented v1 subset of the tracker flow under the `TRACKER_TR` capability flag. The agent SHALL map supported actions to the Bosch JIRA MCP tool surface and SHALL refuse unsupported actions with structured errors.

The action-to-tool mapping for `TRACKER_TR` SHALL be:

| Action | T&R support | MCP tool(s) |
|--------|-------------|-------------|
| `create` | NOT SUPPORTED | n/a — returns error |
| `fetchAndPrepare` | partial | `jira_get_issue` + `jira_transition` + `jira_get_myself` + `jira_update_issue` (no sprint assignment) |
| `updateDescription` | supported | `jira_update_issue` with `description` field |
| `addLabels` | supported via RMW | `jira_get_issue` → union with new labels → `jira_update_issue` with `labels` field (REPLACE semantics) |
| `addComment` | supported | `jira_add_comment` (preceded by the defensive newline normalization step) |
| `addWorklog` | NOT SUPPORTED | n/a — Phase 7b posts only the cost comment; no separate time-data body is required |
| `transition` | supported | `jira_transition` (with `targetStatus` or `transitionId`) |

#### Scenario: Create action unavailable on T&R
- **WHEN** the orchestrator invokes `create` and `TRACKER_TR` is active
- **THEN** `tr-agent.md` SHALL emit an error result block with `error: "Action create unavailable on TRACKER_TR — Path A (existing ticket key) is the only supported entry point"` and the orchestrator SHALL surface the error to the user before any further work begins

#### Scenario: Worklog action unavailable on T&R
- **WHEN** the orchestrator invokes `addWorklog` and `TRACKER_TR` is active
- **THEN** the orchestrator SHALL NOT spawn `tr-agent.md` for that action and SHALL NOT fold time-data into any tracker comment; the cost comment posted by Phase 7b is the only Jira artifact produced by the workflow

#### Scenario: Additive labels via read-modify-write
- **WHEN** the orchestrator invokes `addLabels` with `labelsToAdd` and `TRACKER_TR` is active
- **THEN** `tr-agent.md` SHALL call `jira_get_issue` to read current labels, compute the union with `labelsToAdd` (deduplicated), and call `jira_update_issue` with the merged set; the result block SHALL include `preLabels`, `added`, and `postLabels`

#### Scenario: Sprint assignment skipped on T&R
- **WHEN** `fetchAndPrepare` runs on `TRACKER_TR`
- **THEN** `tr-agent.md` SHALL skip the sprint-assignment step (the underlying MCP does not write custom fields) and SHALL note `sprintAssigned: false, reason: "TRACKER_TR — no custom field write support"` in the result block

#### Scenario: AC inlined in description on T&R
- **WHEN** the `architect-agent` generates a ticket description for a `TRACKER_TR` workflow
- **THEN** the AC section SHALL be inlined into the description body (under a `## Acceptance Criteria` heading) instead of being written to a separate custom field

#### Scenario: Comment action on T&R applies defensive normalization
- **WHEN** the orchestrator invokes `addComment` and `TRACKER_TR` is active
- **THEN** `tr-agent.md` SHALL first apply the defensive newline normalization specified by the "Defensive newline normalization for addComment" requirement, then invoke `mcp__bosch-jira-mcp__jira_add_comment`

### Requirement: Documented v1 limitations on T&R

The completion report from `claudboard-workflow` SHALL list the v1 T&R limitations when `TRACKER_TR` is the selected backend, so users understand what the generated workflow can and cannot do.

#### Scenario: T&R limitations listed in completion report
- **WHEN** generation completes with `TRACKER_TR` active
- **THEN** the completion report SHALL include a "T&R v1 limitations" section enumerating: no auto-create ticket (Path A only), no sprint assignment, no worklog (time is not posted to Jira — neither via worklog nor folded into a comment), AC inlined in description, labels via read-modify-write (non-atomic). Each item SHALL note that the limitation can be lifted when the underlying MCP gains the corresponding tool.
