## ADDED Requirements

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
