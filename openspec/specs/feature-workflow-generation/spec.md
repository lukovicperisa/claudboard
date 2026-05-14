## Requirements

### Requirement: Skill invocation and trigger phrases
The system SHALL expose `claudboard-workflow` as a peer skill alongside `claudboard-analyse`, `claudboard-generate`, `claudboard-refresh`, and `claudboard-techdebt`. The skill SHALL be triggered by the slash command `/claudboard-workflow` and by natural-language phrases including "set up feature workflow", "install start-feature skill", "generate feature-workflow", and equivalents.

#### Scenario: Slash command invocation
- **WHEN** the user types `/claudboard-workflow` in a target project directory
- **THEN** the system SHALL begin the workflow-generation flow rooted at the current working directory

#### Scenario: Natural-language invocation
- **WHEN** the user says "set up feature workflow for this repo" or "install the start-feature skill"
- **THEN** the system SHALL invoke `claudboard-workflow` and confirm the target directory before proceeding

#### Scenario: Auto-trigger from other skills
- **WHEN** any other skill or flow runs (including `/claudboard-analyse`, `/claudboard-generate`, `/claudboard-refresh`)
- **THEN** the system SHALL NOT auto-invoke `claudboard-workflow`; the user must opt in explicitly

### Requirement: Hard prereq on prior `/claudboard-generate` run
The system SHALL refuse to generate the `feature-workflow` skill unless `CLAUDE.md` exists at the project root AND `.claude/rules/` exists with at least one rule file.

#### Scenario: Missing prereq artifacts
- **WHEN** the user invokes `/claudboard-workflow` and either `CLAUDE.md` or `.claude/rules/` (with at least one rule file) is missing
- **THEN** the system SHALL print "Run `/claudboard-generate` first to create the context heavy agents will lean on. claudboard-workflow without that context produces weak prompts." and stop without writing any files

#### Scenario: Prereq satisfied
- **WHEN** both `CLAUDE.md` and at least one rule file exist
- **THEN** the system SHALL proceed to the analysis-report check

### Requirement: Analysis report consumption
The system SHALL read `.claude/reports/claudboard-analysis.md` to source detected substitutions and capability signals. If the report is missing, the system SHALL ask the user to run `/claudboard-analyse` first.

#### Scenario: Missing analysis report
- **WHEN** `.claude/reports/claudboard-analysis.md` is not found
- **THEN** the system SHALL print "No analysis report found. Run `/claudboard-analyse` first, then re-run `/claudboard-workflow`." and stop

#### Scenario: Stale analysis report
- **WHEN** the report's `generated_at` frontmatter is older than 7 days
- **THEN** the system SHALL warn "Analysis report is N days old. Capability signals may be stale. Continue or re-run /analyse?" and pause for user confirmation

#### Scenario: Analysis report missing workflow-signals subsection
- **WHEN** the report does not contain a "Workflow Signals" subsection
- **THEN** the system SHALL treat all workflow signals as `unknown` / empty, warn "Limited workflow signals available — capability blocks may default off; consider re-running /analyse to refresh.", and continue

### Requirement: MCP availability detection
The system SHALL detect whether the Atlassian (Jira) MCP and Azure DevOps MCP are configured by inspecting the user's MCP configuration. The result SHALL set the `JIRA_AVAILABLE` and `ADO_AVAILABLE` capability flags.

#### Scenario: Both MCPs configured
- **WHEN** Atlassian MCP and Azure DevOps MCP are both present in MCP configuration
- **THEN** `JIRA_AVAILABLE` and `ADO_AVAILABLE` SHALL both be set to true and the full workflow SHALL be generated

#### Scenario: Jira MCP missing
- **WHEN** the Atlassian MCP is not configured
- **THEN** `JIRA_AVAILABLE` SHALL be false, the system SHALL skip writing `agents/jira-agent.md`, drop Jira-dependent SKILL.md phases (ticket creation, worklog, status transitions), and emit the warning "Jira MCP not detected. Generated feature-workflow without ticket integration. To enable: configure the Atlassian MCP, then re-run /claudboard-workflow."

#### Scenario: Azure DevOps MCP missing
- **WHEN** the Azure DevOps MCP is not configured
- **THEN** `ADO_AVAILABLE` SHALL be false, the system SHALL skip writing `agents/pr-agent.md`, drop ADO-dependent SKILL.md phases (PR creation), and emit the warning "Azure DevOps MCP not detected. Generated feature-workflow without PR creation. To enable: configure the Azure DevOps MCP, then re-run /claudboard-workflow."

#### Scenario: Both MCPs missing
- **WHEN** neither MCP is configured
- **THEN** the system SHALL emit both warnings and generate a degraded workflow consisting of branch creation, BDD spec, architect plan, implementation, and review phases only

### Requirement: Capability-block resolution
The system SHALL resolve a fixed set of v1 capability flags from the analysis report's "Workflow Signals" subsection and from runtime MCP detection. Each flag drives `<!-- IF FLAG -->...<!-- ENDIF -->` block evaluation in templates.

The v1 capability flags are: `JIRA_AVAILABLE`, `ADO_AVAILABLE`, `WORKSPACE_MODE`, `CROSS_SERVICE_EDGES`, `SHARED_LIB`, `AUTH_PERIMETER`, `MEMORIES_PRESENT`, `MONGODB`, `JPA`, `KAFKA`.

#### Scenario: Block enabled
- **WHEN** a capability flag resolves to true
- **THEN** all `<!-- IF FLAG -->...<!-- ENDIF -->` blocks for that flag in all templates SHALL be retained verbatim (with inner `{{VAR}}` substitutions still applied) and the comment fences themselves SHALL be removed

#### Scenario: Block disabled
- **WHEN** a capability flag resolves to false
- **THEN** all `<!-- IF FLAG -->...<!-- ENDIF -->` blocks for that flag SHALL be removed entirely from rendered output (including any whitespace-only lines that would remain)

#### Scenario: Unknown flag in template
- **WHEN** a template contains a `<!-- IF X -->` for a flag not in the v1 capability set
- **THEN** the system SHALL log a warning naming the unknown flag and treat the block as disabled

#### Scenario: Resolving WORKSPACE_MODE
- **WHEN** the analysis report indicates workspace mode (sibling-repo workspace detected)
- **THEN** `WORKSPACE_MODE` SHALL be true and `{{REPO_LIST_BULLETS}}` and `{{REPO_COUNT}}` SHALL be populated from the workspace inventory

#### Scenario: Resolving CROSS_SERVICE_EDGES
- **WHEN** the workflow-signals subsection lists at least one cross-service edge
- **THEN** `CROSS_SERVICE_EDGES` SHALL be true and `{{EDGE_TYPES_JOINED}}` SHALL be a comma-joined list of detected edge types

#### Scenario: Resolving SHARED_LIB
- **WHEN** the workflow-signals subsection lists at least one shared library with consumer_count >= 2
- **THEN** `SHARED_LIB` SHALL be true and `{{SHARED_LIB_NAME}}` and `{{SHARED_LIB_CONSUMER_COUNT}}` SHALL be populated for the most-consumed shared library

#### Scenario: Resolving AUTH_PERIMETER
- **WHEN** the workflow-signals subsection sets auth_perimeter to a value other than `none` or `unknown`
- **THEN** `AUTH_PERIMETER` SHALL be true

#### Scenario: Resolving MEMORIES_PRESENT
- **WHEN** `.claude/memories/` exists and contains at least one `.md` file
- **THEN** `MEMORIES_PRESENT` SHALL be true and `{{ECOSYSTEM_MEMORY_NAME}}` SHALL resolve to the matching memory file basename if `ecosystem.md` exists

#### Scenario: Resolving persistence flags
- **WHEN** the analysis report's stack detection indicates Spring Data MongoDB
- **THEN** `MONGODB` SHALL be true; `JPA` SHALL be similarly true if Spring Data JPA / Hibernate detected; `KAFKA` SHALL be true if Kafka producers/consumers detected

### Requirement: Substitution variable resolution
The system SHALL resolve substitution variables from the analysis report and runtime context, then replace `{{VAR}}` tokens in all template files. The v1 substitution catalog is: `PROJECT_NAME`, `REPO_NAME`, `STACK_NAME`, `TEST_FRAMEWORK`, `BASE_PACKAGE`, `BUILD_CMD`, `TEST_CMD`, `LINT_CMD`, `TICKET_PREFIX`, `WORKSPACE_NAME`, `REPO_COUNT`, `REPO_LIST_BULLETS`, `EDGE_TYPES_JOINED`, `SHARED_LIB_NAME`, `SHARED_LIB_CONSUMER_COUNT`, `ECOSYSTEM_MEMORY_NAME`, `REPO_OR_SERVICE_LABEL`, `STACK_REMINDERS`.

#### Scenario: All substitutions resolvable
- **WHEN** every `{{VAR}}` token in the templates can be resolved from the analysis report or runtime context
- **THEN** all tokens SHALL be replaced and rendered output SHALL contain no `{{...}}` artifacts

#### Scenario: Unresolvable substitution
- **WHEN** a `{{VAR}}` token cannot be resolved (analysis report missing the field and no runtime fallback applies)
- **THEN** the system SHALL log a warning and replace the token with the literal string `[TODO: VAR]` to preserve template structure

#### Scenario: STACK_REMINDERS escape hatch
- **WHEN** the analysis report contains a "Patterns detected" section
- **THEN** `{{STACK_REMINDERS}}` SHALL resolve to a verbatim copy of that section's bullet list, suitable for direct injection into a "Repo conventions worth remembering" block in heavy agents

### Requirement: config.json input flow
The system SHALL produce `config.json` for the generated `feature-workflow/` skill via a three-tier resolution: auto-detect → sibling-repo inheritance → user prompt. The user SHALL be able to stub any field with a `TODO` placeholder to defer.

#### Scenario: Azure DevOps remote auto-detection
- **WHEN** `git remote -v` output contains a URL matching `dev.azure.com/{org}/{project}/_git/{repo}` or `{org}.visualstudio.com/{project}/_git/{repo}`
- **THEN** the system SHALL extract `azureDevOps.organization` and `azureDevOps.project` automatically without prompting

#### Scenario: Sibling-repo inheritance offer
- **WHEN** at least one sibling directory under the parent of the target repo contains `.claude/skills/feature-workflow/config.json`
- **THEN** the system SHALL display the inheritable shared values (Jira `cloudId`, `projectKey`, `customFields`, ADO `organization`, ADO `project`) and ask: "Inherit shared config from <sibling>? [y/n/edit]"

#### Scenario: Sibling inheritance accepted
- **WHEN** the user accepts the sibling-inheritance offer
- **THEN** the inherited values SHALL be written into the new `config.json` verbatim; ADO `repositoryId` SHALL still be requested (it is per-repo)

#### Scenario: User prompted for missing values
- **WHEN** any required `config.json` field cannot be auto-detected or inherited
- **THEN** the system SHALL prompt the user, offering: a free-text answer, a default if applicable, or "stub with TODO and continue"

#### Scenario: Branch convention defaults
- **WHEN** the user does not provide branch convention values
- **THEN** the system SHALL default `git.branchTypes` to `["feature", "bugfix", "hotfix"]`, `git.branchPattern` to `"{type}/{ticket}/{slug}"` if `JIRA_AVAILABLE` else `"{type}/{slug}"`, and `git.ticketRegex` to `"[A-Z]+-[0-9]+"`

#### Scenario: Stripped Jira section in config
- **WHEN** `JIRA_AVAILABLE` is false
- **THEN** the generated `config.json` SHALL omit the `jira` top-level key entirely

#### Scenario: Stripped Azure DevOps section in config
- **WHEN** `ADO_AVAILABLE` is false
- **THEN** the generated `config.json` SHALL omit the `azureDevOps` top-level key entirely

### Requirement: File generation contract
The system SHALL write generated files only under `<project>/.claude/skills/feature-workflow/`. The system SHALL NOT modify any files outside this directory.

The generated tree SHALL contain:
- `SKILL.md` (rendered from template)
- `config.json` (synthesized from inputs)
- `agents/jira-agent.md` (verbatim copy if `JIRA_AVAILABLE`)
- `agents/git-agent.md`, `agents/pr-agent.md`, `agents/architect-agent.md`, `agents/implementation-agent.md`, `agents/sdd-expert-agent.md`, `agents/design-reviewer.md`, `agents/spec-reviewer.md` (rendered from templates; `pr-agent.md` skipped if `ADO_AVAILABLE` is false)
- `scripts/lib.sh`, `scripts/prepare-commit.sh`, `scripts/prepare-pr.sh`, `scripts/prepare-squash.sh` (verbatim copies)
- `references/claude-pricing.md` (verbatim copy)

#### Scenario: Existing skill present
- **WHEN** `.claude/skills/feature-workflow/` already exists in the target project
- **THEN** the system SHALL refuse to overwrite, print "feature-workflow skill already exists. Upgrade flow is not available in v1; remove the existing skill manually if you want to regenerate.", and stop

#### Scenario: Path outside target ignored
- **WHEN** rendering would write to any path outside `<project>/.claude/skills/feature-workflow/`
- **THEN** the system SHALL refuse the write and report a path-violation error

### Requirement: User-facing confirmation gate
The system SHALL present a summary of what will be generated (file tree, enabled capability blocks, resolved config values) and pause for explicit user confirmation before writing any files.

#### Scenario: User confirms
- **WHEN** the user accepts the generation summary with `y` or equivalent
- **THEN** the system SHALL write all files and print the completion report

#### Scenario: User declines
- **WHEN** the user rejects the summary with `n` or equivalent
- **THEN** the system SHALL ask "Which parts should I skip or change?" and adjust before re-presenting the summary

#### Scenario: User edits a field
- **WHEN** the user requests an edit to a config value or capability flag during the confirmation gate
- **THEN** the system SHALL apply the edit, re-render the affected templates, and re-display the summary

### Requirement: Completion report
After successful generation, the system SHALL print a completion report listing: files written, capability blocks enabled and disabled, any TODO stubs in `config.json`, MCP-availability warnings, and a "next steps" section suggesting `/start-feature` on a small ticket as the validation task.

#### Scenario: Successful generation
- **WHEN** all files are written successfully
- **THEN** the report SHALL list every written file and its size, group capability blocks into "enabled" / "disabled", and include the suggested validation task

#### Scenario: Generation with stripped MCPs
- **WHEN** generation completed but `JIRA_AVAILABLE` and/or `ADO_AVAILABLE` were false
- **THEN** the report SHALL prominently include the corresponding warning(s) and the path to enable each later

#### Scenario: Generation with TODO stubs
- **WHEN** the user chose to stub one or more `config.json` fields with TODO
- **THEN** the report SHALL list each TODO field by name with a hint on what value to fill in

### Requirement: Refresh exclusion
The `claudboard-refresh` skill SHALL NOT modify or replace generated `feature-workflow/` artifacts in v1.

#### Scenario: Refresh on a project with generated feature-workflow
- **WHEN** the user runs `/claudboard-refresh` on a project containing `.claude/skills/feature-workflow/`
- **THEN** `claudboard-refresh` SHALL leave the directory untouched and SHALL note in its report: "Skipped feature-workflow/ — upgrade path is opt-in via future /claudboard-workflow --upgrade"

### Requirement: Dispatcher routing
The dispatcher skill `claudboard` SHALL list `claudboard-workflow` in its routing table and SHALL describe its trigger phrases.

#### Scenario: Dispatcher invocation matches workflow trigger
- **WHEN** a user phrase matches a `claudboard-workflow` trigger and the dispatcher receives it
- **THEN** the dispatcher SHALL route to `claudboard-workflow` and not to any other claudboard sibling

### Requirement: Plugin manifest entry
The plugin manifest at `plugin/.claude-plugin/plugin.json` SHALL list `claudboard-workflow` so it ships with the plugin distribution.

#### Scenario: Plugin distribution
- **WHEN** the claudboard plugin is installed via the standard plugin mechanism
- **THEN** the `claudboard-workflow` skill SHALL be available alongside the other claudboard sibling skills with no additional installation steps

---

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
