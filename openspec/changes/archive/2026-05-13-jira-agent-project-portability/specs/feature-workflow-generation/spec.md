## ADDED Requirements

### Requirement: Lifecycle-state transition mapping in config.json

The generated `config.json` SHALL include a `jira.transitions` block that maps abstract lifecycle states to project-specific Jira status names. The block SHALL define `start` and `success` as required fields, and `failure` and `pause` as optional fields. A `null` value for an optional field SHALL mean "do not fire this transition" (no-op). The rendered `feature-workflow` skill SHALL reference these states by name (`start`, `success`, `failure`, `pause`) and SHALL NOT contain any literal Jira status string outside this block. Defaults SHALL be `start: "In Progress"`, `success: "In Review"`, `failure: "Blocked"`, `pause: null` so a regenerated workflow with default answers preserves current Craftsphere behavior.

#### Scenario: Project uses non-Craftsphere column names
- **WHEN** the user generates `feature-workflow` for a project whose Jira workflow uses `"Doing"` and `"Code Review"` and provides those values in the Phase 2 prompts
- **THEN** the rendered `config.json` SHALL contain `jira.transitions.start = "Doing"` and `jira.transitions.success = "Code Review"`
- **AND** the rendered `SKILL.md` SHALL fire transitions by lifecycle name without hardcoding any Jira status string
- **AND** the rendered jira-agent SHALL resolve the lifecycle name to the configured status string at call time

#### Scenario: Project leaves failure transition unset
- **WHEN** the user provides `null` (or accepts the "skip" prompt) for `jira.transitions.failure`
- **THEN** the orchestrator's failure handler SHALL skip the transition call entirely and surface the error to the user without modifying ticket status

#### Scenario: Pause transition is reserved
- **WHEN** the rendered workflow runs any v1 command (`/start-feature`, etc.)
- **THEN** no v1 command SHALL fire `jira.transitions.pause`
- **AND** the `pause` field in the rendered `config.json` SHALL include a comment marking it as reserved for future use

### Requirement: Configurable area-label vocabulary

The generated `config.json` SHALL include a `jira.labels` block with `ai` (always-added label list), `area` (per-area label map or `null` for none), and `preserveExisting` (boolean, default `true`). The rendered `feature-workflow` skill SHALL NOT contain a hardcoded `Backend→BE / Frontend→FE / DevOps→DevOps / Docs→Docs` map; it SHALL read the area-to-label mapping from `jira.labels.area` instead. A top-level `area: null` SHALL mean "no area label is added regardless of work type." A per-area entry of `null` (e.g., `area: { backend: "BE", devops: null }`) SHALL mean "skip the area label for that work type." Defaults SHALL be `ai: ["AI", "AI_CLI"]` and `area: { backend: "BE", frontend: "FE", devops: "DevOps", docs: "Docs" }` to preserve current Craftsphere behavior.

#### Scenario: Project does not use area labels
- **WHEN** the user answers "no" to "Does this project use area labels?" in Phase 2
- **THEN** the rendered `config.json` SHALL contain `jira.labels.area = null`
- **AND** when `/start-feature` runs, the labels written to the ticket SHALL contain only `ai` labels and any preserved existing labels — no area label

#### Scenario: Project uses area labels for some areas only
- **WHEN** the user provides `BE` for backend, `FE` for frontend, and leaves devops/docs blank in Phase 2
- **THEN** the rendered `config.json` SHALL contain `jira.labels.area = { backend: "BE", frontend: "FE", devops: null, docs: null }`
- **AND** when `/start-feature` runs on backend work, the labels SHALL include `BE`
- **AND** when `/start-feature` runs on devops work, the labels SHALL NOT include any area label

#### Scenario: Defaults preserve Craftsphere behavior
- **WHEN** a user accepts the default prompts in Phase 2 (Craftsphere-style answers)
- **THEN** the rendered `config.json` SHALL contain the per-area map `{ backend: "BE", frontend: "FE", devops: "DevOps", docs: "Docs" }` and `ai: ["AI", "AI_CLI"]`

### Requirement: Existing labels SHALL never be destroyed by the workflow

When the rendered workflow updates labels on an existing ticket, it SHALL preserve all labels already present on that ticket. The label-merge computation SHALL be performed by the orchestrator, not by the jira-agent sub-agent. The jira-agent's `fetchAndPrepare` action SHALL return the ticket's current label list as `existingLabels` in its result block. The orchestrator SHALL compute the union of `existingLabels`, the configured `ai` labels, and the resolved area label (if any) for the current work type, then pass the resulting list to a new `applyLabels` action on jira-agent.

#### Scenario: Ticket has prior labels that must be preserved
- **WHEN** the user invokes `/start-feature MEAS-1234` and that ticket already has labels `["Collaboration"]`
- **AND** the configured `ai` labels are `["AI", "AI_CLI"]` and the resolved area label for the work is `null`
- **THEN** after the workflow runs, the ticket SHALL have labels `["Collaboration", "AI", "AI_CLI"]` (existing label preserved, AI labels added)

#### Scenario: Ticket has no prior labels
- **WHEN** the user invokes `/start-feature MEAS-5678` and that ticket has labels `[]`
- **AND** `fetchAndPrepare` returns `existingLabels: []` in its result block
- **THEN** the orchestrator SHALL compute the union with the empty set without error
- **AND** the final label list SHALL be just the configured `ai` labels plus any resolved area label

#### Scenario: Newly created ticket
- **WHEN** the orchestrator invokes the `create` action on jira-agent (no existing ticket)
- **THEN** the orchestrator SHALL pre-compute the labels list from `ai` plus the resolved area label for the work type
- **AND** SHALL pass the fully-resolved list to `create`
- **AND** jira-agent SHALL NOT compute labels from a hardcoded map of its own

### Requirement: jira-agent SHALL expose an `applyLabels` action and SHALL NOT compute label sets itself

The jira-agent template SHALL document an `applyLabels` action that takes a `ticketKey` and a fully-resolved `labels` array and writes that array to the ticket via `editJiraIssue`. jira-agent SHALL NOT perform set-union, deduplication, or any other multi-step computation against ticket label state in v1. The `fetchAndPrepare` action SHALL include `existingLabels` (an array, possibly empty) in its result block so the orchestrator has the inputs needed to compute the merged list.

#### Scenario: Orchestrator hands a ready-to-write list to applyLabels
- **WHEN** the orchestrator computes a merged labels list `["Collaboration", "AI", "AI_CLI", "BE"]`
- **AND** invokes jira-agent with `{ action: "applyLabels", ticketKey: "PLAT-100", labels: [...] }`
- **THEN** jira-agent SHALL call `editJiraIssue` with `fields: { labels: [...] }` exactly as provided
- **AND** SHALL NOT add, remove, or reorder labels in transit

#### Scenario: fetchAndPrepare returns existingLabels
- **WHEN** the orchestrator invokes `fetchAndPrepare` on a ticket with labels `["Collaboration"]`
- **THEN** the JSON result block SHALL include `"existingLabels": ["Collaboration"]`

#### Scenario: fetchAndPrepare on a ticket with no labels
- **WHEN** the orchestrator invokes `fetchAndPrepare` on a ticket with no labels
- **THEN** the JSON result block SHALL include `"existingLabels": []` (an empty array, not omitted, not null)

### Requirement: Orchestrator SHALL fire failure_transition on non-recoverable failures only

The rendered `SKILL.md` SHALL wrap the workflow execution in a top-level error handler. On a **non-recoverable** failure, the orchestrator SHALL invoke jira-agent with `{ action: "transition", lifecycleState: "failure" }` (only if `jira.transitions.failure` is non-null) and SHALL surface the error to the user. The orchestrator SHALL NOT fire `failure_transition` on **recoverable** failures.

Non-recoverable failures (must fire when configured): Atlassian MCP unavailable; configured transition name not found in Jira's available transitions; ticket not found; network errors after retry; unhandled exception bubbling from any sub-agent.

Recoverable failures (must NOT fire): test failures; lint failures; design review pushback; spec review pushback; build failures. These SHALL continue to be handled inside the existing iterate loop without touching ticket status.

#### Scenario: MCP server is unavailable mid-flow
- **WHEN** the rendered workflow attempts a Jira call and the Atlassian MCP server returns no response or a transport error after retry
- **AND** `jira.transitions.failure` is configured to `"Blocked"`
- **THEN** the orchestrator SHALL invoke jira-agent to transition the ticket to `"Blocked"`
- **AND** SHALL print the original error to the user
- **AND** SHALL halt the workflow

#### Scenario: Configured transition name does not exist in Jira
- **WHEN** the orchestrator fires `transition: { lifecycleState: "success" }` and jira-agent's transition lookup against available transitions returns no match
- **AND** `jira.transitions.failure` is configured
- **THEN** the orchestrator SHALL fire `failure_transition`
- **AND** SHALL surface a message identifying the missing transition name and listing the available transitions returned by the API

#### Scenario: Test failure during implementation phase
- **WHEN** the iterate loop runs tests and tests fail
- **THEN** the orchestrator SHALL NOT fire `failure_transition`
- **AND** SHALL continue the iterate loop per the existing implementation-phase contract

#### Scenario: failure_transition is null in config
- **WHEN** a non-recoverable failure occurs and `jira.transitions.failure` is `null`
- **THEN** the orchestrator SHALL skip the transition call entirely
- **AND** SHALL still surface the error to the user
- **AND** SHALL still halt the workflow

### Requirement: Phase 2 config gathering SHALL prompt for new fields with Craftsphere-default fallbacks

The `claudboard-workflow` orchestrator's Phase 2 (config gathering) SHALL prompt the user for `jira.transitions.start`, `jira.transitions.success`, `jira.transitions.failure`, `jira.transitions.pause`, and `jira.labels` fields. Each prompt SHALL offer a Craftsphere-style default that the user can accept by pressing Enter. Each prompt SHALL support the standard "stub with TODO" escape per the existing convention in `jira-config-prompts.md`. The prompt for `jira.labels.area` SHALL be a top-level y/n that short-circuits to `area: null` on "no" and otherwise prompts for each of backend/frontend/devops/docs (blank input maps to `null` for that area). The prompt for `jira.transitions.pause` SHALL document the field as reserved-for-future-use.

#### Scenario: User accepts all transition defaults
- **WHEN** the user presses Enter at every transition prompt in Phase 2
- **THEN** the rendered `config.json` SHALL contain `start: "In Progress"`, `success: "In Review"`, `failure: "Blocked"`, `pause: null`

#### Scenario: User answers "no" to area labels
- **WHEN** Phase 2 asks "Does this project use area labels? (y/n)" and the user answers "n"
- **THEN** Phase 2 SHALL NOT prompt for individual area mappings
- **AND** the rendered `config.json` SHALL contain `jira.labels.area = null`

#### Scenario: User provides area labels for some areas only
- **WHEN** Phase 2 asks per-area prompts and the user provides `BE` for backend, presses Enter (blank) for frontend, presses Enter for devops, and provides `Docs` for docs
- **THEN** the rendered `config.json` SHALL contain `jira.labels.area = { backend: "BE", frontend: null, devops: null, docs: "Docs" }`

#### Scenario: Pause prompt explains reserved status
- **WHEN** Phase 2 prompts for `jira.transitions.pause`
- **THEN** the prompt text SHALL state that the field is reserved for future use and is not fired by any v1 command
- **AND** SHALL default to `null`
