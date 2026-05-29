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
The system SHALL detect which tracker MCP (Atlassian Jira or Bosch Track & Release) and which repo MCP (Azure DevOps or GitHub) are configured by inspecting the user's MCP configuration. The result SHALL set exactly one of `TRACKER_JIRA` / `TRACKER_TR` (or neither) and exactly one of `REPO_ADO` / `REPO_GITHUB` (or neither). When two MCPs in the same dimension are detected, the system SHALL prompt the user to choose; the chosen flag SHALL be set true and the other false. The detailed detection rules (keyword matching, project-vs-user precedence, prompt wording, completion-report logging) live in the `mcp-detection` capability spec.

#### Scenario: One MCP per dimension detected
- **WHEN** exactly one tracker MCP and exactly one repo MCP are present in MCP configuration
- **THEN** the corresponding flags SHALL be set true (e.g., `TRACKER_TR=true`, `REPO_GITHUB=true`) and the other flags in each dimension SHALL be false; the full workflow for the chosen backends SHALL be generated

#### Scenario: Both tracker MCPs detected
- **WHEN** both Atlassian and Bosch T&R MCPs are detected
- **THEN** the system SHALL prompt the user to choose; only the chosen tracker flag SHALL be true

#### Scenario: Both repo MCPs detected
- **WHEN** both Azure DevOps and GitHub MCPs are detected
- **THEN** the system SHALL prompt the user to choose; only the chosen repo flag SHALL be true

#### Scenario: Tracker MCP missing
- **WHEN** neither tracker MCP is configured
- **THEN** `TRACKER_JIRA` and `TRACKER_TR` SHALL both be false; the system SHALL skip writing both `agents/jira-agent.md` and `agents/tr-agent.md`; the SKILL.md tracker phases SHALL be omitted; and the warning "No tracker MCP detected. Generated feature-workflow has no ticket integration. To enable: configure Atlassian Jira MCP or Bosch T&R MCP, then re-run /claudboard-workflow." SHALL be emitted

#### Scenario: Repo MCP missing
- **WHEN** neither repo MCP is configured
- **THEN** `REPO_ADO` and `REPO_GITHUB` SHALL both be false; the system SHALL skip writing both `agents/pr-agent-ado.md` and `agents/pr-agent-github.md`; Phase 6 SHALL be omitted from SKILL.md; and the warning "No repo MCP detected. Generated feature-workflow has no PR creation. To enable: configure Azure DevOps MCP or GitHub MCP, then re-run /claudboard-workflow." SHALL be emitted

#### Scenario: Both dimensions missing
- **WHEN** no tracker MCP and no repo MCP are configured
- **THEN** the system SHALL emit both warnings and generate a degraded workflow consisting of branch creation, BDD spec, architect plan, implementation, and review phases only

### Requirement: Workspace mode prerequisite — meta-repo must be bootstrapped
When the analysis report has `workspace: true`, the system SHALL refuse to generate the workflow unless `<workspace>/.claude` is a symlink (or copy-mode equivalent per `workspace-meta-repo-bootstrap`) to a meta-repo's `.claude/` directory. If the prerequisite is missing, the system SHALL instruct the user to run `/claudboard-workspace-init` first.

#### Scenario: Workspace mode without bootstrap
- **WHEN** `/claudboard-workflow` is invoked in workspace mode AND `<workspace>/.claude` is not a symlink (or is a regular directory at CWD)
- **THEN** the system SHALL print "Workspace mode requires a bootstrapped meta-repo. Run `/claudboard-workspace-init` first." and stop without writing any files

#### Scenario: Workspace mode with bootstrap present
- **WHEN** `/claudboard-workflow` is invoked in workspace mode AND `<workspace>/.claude` is a symlink to an existing meta-repo `.claude/` directory
- **THEN** the system SHALL proceed with workspace-mode generation

### Requirement: Workspace-mode generation target path
In workspace mode, the system SHALL write generated files only under `<meta-repo>/.claude/skills/feature-workflow/` (resolved through the workspace symlink). The existing path-violation guard (no writes outside the skill directory) SHALL apply with the meta-repo path as the base.

The generated tree contents SHALL match the existing single-repo contract (SKILL.md, config.json, agents/, scripts/, references/) plus the additional workspace-specific files defined in `multirepo-feature-workflow`.

#### Scenario: Workspace generation writes through symlink
- **WHEN** workspace-mode generation runs
- **THEN** all writes SHALL target paths under `<workspace>/.claude/skills/feature-workflow/`, resolving through the symlink to the meta-repo's tracked tree; `git status` in the meta-repo SHALL show the new files as untracked changes ready for review

#### Scenario: No per-repo generation in workspace mode
- **WHEN** workspace-mode generation runs on a workspace with N service repos
- **THEN** the system SHALL NOT create or modify `feature-workflow/` directories inside any individual service repo's `.claude/skills/`

### Requirement: Capability-block resolution
The system SHALL resolve a fixed set of v1 capability flags from the analysis report's "Workflow Signals" subsection and from runtime MCP detection. Each flag drives `<!-- IF FLAG -->...<!-- ENDIF -->` block evaluation in templates.

The v1 capability flags are: `TRACKER_JIRA`, `TRACKER_TR`, `REPO_ADO`, `REPO_GITHUB`, `WORKSPACE_MODE`, `CROSS_SERVICE_EDGES`, `SHARED_LIB`, `AUTH_PERIMETER`, `MEMORIES_PRESENT`, `MONGODB`, `JPA`, `KAFKA`.

The tracker dimension (`TRACKER_JIRA`, `TRACKER_TR`) and the repo dimension (`REPO_ADO`, `REPO_GITHUB`) are each mutually exclusive: at most one flag per dimension SHALL be true in any given generated workflow.

`WORKSPACE_MODE` SHALL gate not only substitution variables (existing behavior) but also the multi-repo variants of SKILL.md, the multi-repo variants of every code-touching agent, the multi-repo `config.json` shape (with `repos: { ... }` map), and the inclusion of `scripts/load-repo-context.sh` in the generated tree.

#### Scenario: Block enabled
- **WHEN** a capability flag resolves to true
- **THEN** all `<!-- IF FLAG -->...<!-- ENDIF -->` blocks for that flag in all templates SHALL be retained verbatim (with inner `{{VAR}}` substitutions still applied) and the comment fences themselves SHALL be removed

#### Scenario: Block disabled
- **WHEN** a capability flag resolves to false
- **THEN** all `<!-- IF FLAG -->...<!-- ENDIF -->` blocks for that flag SHALL be removed entirely from rendered output (including any whitespace-only lines that would remain)

#### Scenario: Mutually exclusive flags
- **WHEN** generation resolves capability flags
- **THEN** at most one of `TRACKER_JIRA` and `TRACKER_TR` SHALL be true at any time, and at most one of `REPO_ADO` and `REPO_GITHUB` SHALL be true; if a generation pass would produce both flags true in either dimension, the system SHALL halt with a precedence-resolution error before writing any files

#### Scenario: Unknown flag in template
- **WHEN** a template contains a `<!-- IF X -->` for a flag not in the v1 capability set
- **THEN** the system SHALL log a warning naming the unknown flag and treat the block as disabled

#### Scenario: Resolving WORKSPACE_MODE
- **WHEN** the analysis report indicates workspace mode (sibling-repo workspace detected)
- **THEN** `WORKSPACE_MODE` SHALL be true, `{{REPO_LIST_BULLETS}}`, `{{REPO_COUNT}}`, and `{{REPOS_MAP_JSON}}` SHALL be populated from the workspace inventory, and the multi-repo template variants for SKILL.md, agents, scripts, and config.json SHALL be rendered

#### Scenario: WORKSPACE_MODE false renders single-repo variants
- **WHEN** `WORKSPACE_MODE` is false
- **THEN** the existing single-repo SKILL.md, agents, scripts, and config.json SHALL be rendered exactly per the pre-existing requirements (no behavioral change)

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
The system SHALL resolve substitution variables from the analysis report and runtime context, then replace `{{VAR}}` tokens in all template files. The v1 substitution catalog is: `PROJECT_NAME`, `REPO_NAME`, `STACK_NAME`, `TEST_FRAMEWORK`, `BASE_PACKAGE`, `BUILD_CMD`, `TEST_CMD`, `LINT_CMD`, `TICKET_PREFIX`, `WORKSPACE_NAME`, `REPO_COUNT`, `REPO_LIST_BULLETS`, `REPOS_MAP_JSON`, `EDGE_TYPES_JOINED`, `SHARED_LIB_NAME`, `SHARED_LIB_CONSUMER_COUNT`, `ECOSYSTEM_MEMORY_NAME`, `REPO_OR_SERVICE_LABEL`, `STACK_REMINDERS`, `TR_BASE_URL`, `TR_PROJECT_KEY`, `GITHUB_OWNER`, `GITHUB_REPO`, `GITHUB_LINKING_KEYWORD`.

`REPOS_MAP_JSON` SHALL render as a JSON object suitable for direct embedding in the workspace `config.json`, mapping repo name to a per-repo settings object containing the auto-detected repo identifier (`azureDevOps.repositoryId` when `REPO_ADO`, or `github.owner`/`github.repo` when `REPO_GITHUB`) plus any other per-repo overrides identified during generation.

#### Scenario: All substitutions resolvable
- **WHEN** every `{{VAR}}` token in the templates can be resolved from the analysis report or runtime context
- **THEN** all tokens SHALL be replaced and rendered output SHALL contain no `{{...}}` artifacts

#### Scenario: Unresolvable substitution
- **WHEN** a `{{VAR}}` token cannot be resolved (analysis report missing the field and no runtime fallback applies)
- **THEN** the system SHALL log a warning and replace the token with the literal string `[TODO: VAR]` to preserve template structure

#### Scenario: REPOS_MAP_JSON resolution under REPO_ADO
- **WHEN** `WORKSPACE_MODE` is true, `REPO_ADO` is true, and the analysis report enumerates 3 service repos with detectable Azure DevOps remotes
- **THEN** `{{REPOS_MAP_JSON}}` SHALL render as a JSON object with 3 keys (one per repo), each value containing at minimum the `azureDevOps.repositoryId` extracted from that repo's git remote

#### Scenario: REPOS_MAP_JSON resolution under REPO_GITHUB
- **WHEN** `WORKSPACE_MODE` is true, `REPO_GITHUB` is true, and the analysis report enumerates 3 service repos with detectable GitHub remotes
- **THEN** `{{REPOS_MAP_JSON}}` SHALL render as a JSON object with 3 keys (one per repo), each value containing at minimum `github.owner` and `github.repo` extracted from that repo's git remote

#### Scenario: REPOS_MAP_JSON with missing per-repo data
- **WHEN** one of the workspace repos has no detectable repo remote for the active `REPO_*` backend
- **THEN** the rendering SHALL include the repo with `[TODO: repositoryId]` (ADO) or `[TODO: owner/repo]` (GitHub) stubs for that repo and SHALL warn the user during the confirmation gate

#### Scenario: STACK_REMINDERS escape hatch
- **WHEN** the analysis report contains a "Patterns detected" section
- **THEN** `{{STACK_REMINDERS}}` SHALL resolve to a verbatim copy of that section's bullet list, suitable for direct injection into a "Repo conventions worth remembering" block in heavy agents

#### Scenario: T&R substitution variables resolved
- **WHEN** `TRACKER_TR` is true and the user supplies the T&R base URL and project key during config gathering
- **THEN** `{{TR_BASE_URL}}` and `{{TR_PROJECT_KEY}}` SHALL be populated from the user-supplied values

#### Scenario: GitHub substitution variables resolved
- **WHEN** `REPO_GITHUB` is true and the project's git remote matches a GitHub URL pattern
- **THEN** `{{GITHUB_OWNER}}` and `{{GITHUB_REPO}}` SHALL be auto-extracted; `{{GITHUB_LINKING_KEYWORD}}` SHALL default to `"Closes"` unless the user overrides during config gathering

### Requirement: config.json input flow
The system SHALL produce `config.json` for the generated `feature-workflow/` skill via a three-tier resolution: auto-detect → sibling-repo inheritance → user prompt. The user SHALL be able to stub any field with a `TODO` placeholder to defer. The config SHALL contain a top-level `tracker` discriminator (`"jira"` | `"tr"` | absent) and a top-level `repo` discriminator (`"ado"` | `"github"` | absent). The backend-specific block matching the active discriminator SHALL be populated; the other backend's block in the same dimension SHALL be absent.

#### Scenario: Azure DevOps remote auto-detection
- **WHEN** `REPO_ADO` is the active backend and `git remote -v` output contains a URL matching `dev.azure.com/{org}/{project}/_git/{repo}` or `{org}.visualstudio.com/{project}/_git/{repo}`
- **THEN** the system SHALL extract `azureDevOps.organization`, `azureDevOps.project`, and `azureDevOps.repositoryId` automatically without prompting

#### Scenario: GitHub remote auto-detection
- **WHEN** `REPO_GITHUB` is the active backend and `git remote -v` output contains a URL matching `github.com:{owner}/{repo}` or `https://github.com/{owner}/{repo}`
- **THEN** the system SHALL extract `github.owner` and `github.repo` automatically without prompting

#### Scenario: Sibling-repo inheritance offer
- **WHEN** at least one sibling directory under the parent of the target repo contains `.claude/skills/feature-workflow/config.json` with the same active tracker and repo backends
- **THEN** the system SHALL display the inheritable shared values (tracker-specific: Jira `cloudId`/`projectKey`/`customFields` or T&R `baseUrl`/`projectKey`; repo-specific: ADO `organization`/`project` or GitHub `linkingKeyword`) and ask: "Inherit shared config from <sibling>? [y/n/edit]"

#### Scenario: Sibling inheritance accepted
- **WHEN** the user accepts the sibling-inheritance offer
- **THEN** the inherited values SHALL be written into the new `config.json` verbatim; per-repo identifiers (ADO `repositoryId`, GitHub `owner`/`repo`) SHALL still be requested or auto-detected for the new repo

#### Scenario: User prompted for missing values
- **WHEN** any required `config.json` field cannot be auto-detected or inherited
- **THEN** the system SHALL prompt the user, offering: a free-text answer, a default if applicable, or "stub with TODO and continue"

#### Scenario: Branch convention defaults
- **WHEN** the user does not provide branch convention values
- **THEN** the system SHALL default `git.branchTypes` to `["feature", "bugfix", "hotfix"]`, `git.branchPattern` to `"{type}/{ticket}/{slug}"` if any tracker flag is true else `"{type}/{slug}"`, and `git.ticketRegex` to `"[A-Z]+-[0-9]+"`

#### Scenario: Stripped tracker section in config
- **WHEN** `TRACKER_JIRA` and `TRACKER_TR` are both false
- **THEN** the generated `config.json` SHALL omit the `tracker` discriminator key and both the `jira` and `tr` blocks

#### Scenario: Stripped repo section in config
- **WHEN** `REPO_ADO` and `REPO_GITHUB` are both false
- **THEN** the generated `config.json` SHALL omit the `repo` discriminator key and both the `azureDevOps` and `github` blocks

#### Scenario: Tracker discriminator selects single backend block
- **WHEN** `TRACKER_TR` is true
- **THEN** the generated `config.json` SHALL contain `"tracker": "tr"`, a populated `"tr": { baseUrl, projectKey, transitions }` block, and no `"jira"` block

#### Scenario: Repo discriminator selects single backend block
- **WHEN** `REPO_GITHUB` is true
- **THEN** the generated `config.json` SHALL contain `"repo": "github"`, a populated `"github": { owner, repo, linkingKeyword }` block, and no `"azureDevOps"` block

### Requirement: File generation contract
The system SHALL write generated files only under the resolved feature-workflow skill directory:
- In single-repo mode: `<project>/.claude/skills/feature-workflow/`
- In workspace mode: `<workspace>/.claude/skills/feature-workflow/` (a symlink resolving to `<meta-repo>/.claude/skills/feature-workflow/`)

The system SHALL NOT modify any files outside this directory in either mode.

The generated tree SHALL contain:
- `SKILL.md` (rendered from template; multi-repo variant when `WORKSPACE_MODE` is true)
- `config.json` (synthesized from inputs; workspace shape with `repos: { ... }` map when `WORKSPACE_MODE` is true)
- `agents/jira-agent.md` (verbatim copy if `TRACKER_JIRA`; otherwise NOT written)
- `agents/tr-agent.md` (verbatim copy if `TRACKER_TR`; otherwise NOT written)
- `agents/pr-agent-ado.md` (verbatim copy if `REPO_ADO`; otherwise NOT written)
- `agents/pr-agent-github.md` (verbatim copy if `REPO_GITHUB`; otherwise NOT written)
- `agents/git-agent.md`, `agents/architect-agent.md`, `agents/implementation-agent.md`, `agents/sdd-expert-agent.md`, `agents/design-reviewer.md`, `agents/spec-reviewer.md` (rendered from templates; multi-repo variants when `WORKSPACE_MODE` is true; each accepts a `repo` argument in workspace mode)
- `scripts/lib.sh`, `scripts/prepare-commit.sh`, `scripts/prepare-pr.sh`, `scripts/prepare-squash.sh` (verbatim copies; in workspace mode they SHALL accept a `--repo` flag or `REPO_PATH` env var)
- `scripts/jira-add-labels.sh` (verbatim copy if `TRACKER_JIRA`; otherwise NOT written)
- `scripts/load-repo-context.sh` (only generated when `WORKSPACE_MODE` is true)
- `references/claude-pricing.md` (verbatim copy)

Mutually-exclusive tracker and repo agents SHALL never both be present: the generator SHALL refuse to write both `jira-agent.md` and `tr-agent.md` in the same output (likewise for the two PR agents).

#### Scenario: Existing skill present in single-repo mode
- **WHEN** `.claude/skills/feature-workflow/` already exists in the target project
- **THEN** the system SHALL refuse to overwrite, print "feature-workflow skill already exists. Upgrade flow is not available in v1; remove the existing skill manually if you want to regenerate.", and stop

#### Scenario: Existing skill present in workspace mode
- **WHEN** the meta-repo's `.claude/skills/feature-workflow/` already exists
- **THEN** the system SHALL refuse to overwrite, print "feature-workflow skill already exists at <path>. Upgrade flow is not available in v1; remove the existing skill manually if you want to regenerate.", and stop

#### Scenario: Path outside target ignored
- **WHEN** rendering would write to any path outside the resolved feature-workflow skill directory
- **THEN** the system SHALL refuse the write and report a path-violation error

#### Scenario: Workspace mode writes to per-repo locations are blocked
- **WHEN** in workspace mode, rendering would write to any path under `<workspace>/<repo>/.claude/` (i.e., into a service repo's `.claude/`)
- **THEN** the system SHALL refuse the write and report a path-violation error; per-repo `feature-workflow/` skills are explicitly not generated in workspace mode

#### Scenario: Mutually-exclusive tracker agents
- **WHEN** the resolved capability flags would cause both `jira-agent.md` and `tr-agent.md` to be written
- **THEN** the system SHALL halt before writing any files and report a "mutually-exclusive tracker flags both true" error

#### Scenario: Mutually-exclusive repo agents
- **WHEN** the resolved capability flags would cause both `pr-agent-ado.md` and `pr-agent-github.md` to be written
- **THEN** the system SHALL halt before writing any files and report a "mutually-exclusive repo flags both true" error

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
- **WHEN** generation completed but the tracker and/or repo dimension has no active MCP flag (both tracker flags false and/or both repo flags false)
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

The generated `config.json` SHALL include a `jira.labels` block with `ai` (always-added label list) and `area` (per-area label map or `null` for none). The previously specified `preserveExisting` flag SHALL be removed — preservation is now structural (via the additive script) and not a configurable behavior. The rendered `feature-workflow` skill SHALL NOT contain a hardcoded `Backend→BE / Frontend→FE / DevOps→DevOps / Docs→Docs` map; it SHALL read the area-to-label mapping from `jira.labels.area` instead. A top-level `area: null` SHALL mean "no area label is added regardless of work type." A per-area entry of `null` (e.g., `area: { backend: "BE", devops: null }`) SHALL mean "skip the area label for that work type." Defaults SHALL be `ai: ["AI", "AI_CLI"]` and `area: { backend: "BE", frontend: "FE", devops: "DevOps", docs: "Docs" }` to preserve current Craftsphere behavior.

#### Scenario: preserveExisting field is absent
- **WHEN** the rendered `config.json` is inspected after a fresh generation
- **THEN** the `jira.labels` block SHALL contain `ai` and `area` only
- **AND** SHALL NOT contain a `preserveExisting` key

#### Scenario: Project does not use area labels
- **WHEN** the user answers "no" to "Does this project use area labels?" in Phase 2
- **THEN** the rendered `config.json` SHALL contain `jira.labels.area = null`
- **AND** when `/start-feature` runs, the additive set SHALL contain only `ai` labels — no area label

#### Scenario: Project uses area labels for some areas only
- **WHEN** the user provides `BE` for backend, `FE` for frontend, and leaves devops/docs blank in Phase 2
- **THEN** the rendered `config.json` SHALL contain `jira.labels.area = { backend: "BE", frontend: "FE", devops: null, docs: null }`
- **AND** when `/start-feature` runs on backend work, the additive set SHALL include `BE`
- **AND** when `/start-feature` runs on devops work, the additive set SHALL NOT include any area label

#### Scenario: Defaults preserve Craftsphere behavior
- **WHEN** a user accepts the default prompts in Phase 2 (Craftsphere-style answers)
- **THEN** the rendered `config.json` SHALL contain the per-area map `{ backend: "BE", frontend: "FE", devops: "DevOps", docs: "Docs" }` and `ai: ["AI", "AI_CLI"]`

### Requirement: Existing labels SHALL never be destroyed by the workflow

When the rendered workflow updates labels on an existing ticket, it SHALL preserve all labels already present on that ticket. The preservation mechanism SHALL be a deterministic shell script (`scripts/jira-add-labels.sh`) that uses Jira's native additive `update.labels[].add` REST operation, so that label destruction is structurally impossible regardless of LLM behavior. The orchestrator SHALL pass only the additive label set to `jira-agent`; it SHALL NOT read, hold, or compute the existing label set itself.

#### Scenario: Ticket has prior labels that must be preserved
- **WHEN** the user invokes `/start-feature MEAS-1234` and that ticket already has labels `["Collaboration"]`
- **AND** the configured `ai` labels are `["AI", "AI_CLI"]` and the resolved area label for the work is `null`
- **THEN** after the workflow runs, the ticket SHALL have labels `["Collaboration", "AI", "AI_CLI"]` (existing label preserved, AI labels added)
- **AND** the script's post-write verify step SHALL have confirmed the existing label is still present

#### Scenario: Ticket has no prior labels
- **WHEN** the user invokes `/start-feature MEAS-5678` and that ticket has labels `[]`
- **THEN** after the workflow runs, the ticket SHALL have labels equal to the configured `ai` labels plus any resolved area label
- **AND** no error SHALL be raised by the empty-prior-labels case

#### Scenario: Newly created ticket
- **WHEN** the orchestrator invokes the `create` action on jira-agent (no existing ticket)
- **THEN** jira-agent SHALL create the ticket without any `labels` in `additional_fields`
- **AND** SHALL invoke the `addLabels` script with the configured `ai` labels plus the resolved area label
- **AND** the ticket's final label set SHALL equal that additive set

#### Scenario: Workflow runs while user has just attached a label
- **WHEN** between the orchestrator's first jira-agent call and the eventual `addLabels` call, the user (or another automation) attaches a new label `"Manual-Review"` to the ticket
- **THEN** after `addLabels` completes, `"Manual-Review"` SHALL still be present on the ticket
- **AND** the additive `ai`/area labels SHALL also be present

### Requirement: jira-agent SHALL expose `addLabels` (strictly additive) and SHALL NOT expose `applyLabels`

The jira-agent template SHALL document an `addLabels` action that takes a `ticketKey` and a `labelsToAdd` array, and SHALL invoke `scripts/jira-add-labels.sh` with one `--add <label>` argument per entry in the array. The agent SHALL NOT call `editJiraIssue` with `fields.labels` under any code path. The previously specified `applyLabels` action SHALL NOT appear in the template.

#### Scenario: addLabels invokes the script with --add per label
- **WHEN** the orchestrator calls `jira-agent` with `{ action: "addLabels", ticketKey: "PLAT-100", labelsToAdd: ["AI", "AI_CLI", "BE"] }`
- **THEN** the agent SHALL execute `bash .claude/skills/feature-workflow/scripts/jira-add-labels.sh --ticket PLAT-100 --add AI --add AI_CLI --add BE`
- **AND** SHALL NOT make any `mcp__atlassian__editJiraIssue` call with a `labels` field

#### Scenario: jira-agent surfaces script errors as agent errors
- **WHEN** the script exits non-zero (env-var missing, verify failed, network error)
- **THEN** the agent's result JSON SHALL include `"error": "<one-line summary>"` and `"scriptStderr": "<full stderr>"` and `"applied": false`
- **AND** the agent SHALL NOT report `"applied": true`

#### Scenario: applyLabels action is absent from the template
- **WHEN** the rendered `agents/jira-agent.md` is inspected
- **THEN** it SHALL NOT contain a section titled `Action: applyLabels`
- **AND** it SHALL NOT contain any prose instructing the agent to write `fields.labels` via `editJiraIssue`

### Requirement: Label writes SHALL go through a deterministic merge script

The rendered `feature-workflow` skill SHALL include a shell script `scripts/jira-add-labels.sh` that performs all label writes against a Jira ticket. The script SHALL:

1. Read the ticket's current labels via Jira REST `GET /rest/api/3/issue/{key}?fields=labels`.
2. Compute the union of the current labels and the supplied `--add <label>` arguments using `jq` (no LLM in the merge path).
3. Write the result via Jira REST `PUT /rest/api/3/issue/{key}` using the body shape `{"update": {"labels": [{"add": "<label>"}, ...]}}` — i.e., Jira's native additive operation, not `fields.labels`.
4. Re-read the ticket's labels and verify that every label in `(current ∪ adds)` is present in the post-write set.
5. Exit non-zero with a structured error if any label is missing post-write.

The script SHALL be the only mechanism by which the rendered workflow writes labels. No agent, no orchestrator prose, and no MCP `editJiraIssue` call SHALL set `fields.labels` directly.

#### Scenario: Script preserves existing labels under union semantics
- **WHEN** the script is invoked as `jira-add-labels.sh --ticket MEAS-1234 --add AI --add AI_CLI`
- **AND** the ticket currently has labels `["Collaboration", "Spike"]`
- **THEN** the script SHALL call Jira REST with `update.labels = [{add: "AI"}, {add: "AI_CLI"}]`
- **AND** after the write, the ticket SHALL have labels `["Collaboration", "Spike", "AI", "AI_CLI"]` (in some order)
- **AND** the verify step SHALL succeed and the script SHALL exit 0

#### Scenario: Script verify catches Jira-side label loss
- **WHEN** the script writes additive labels but the post-write read shows a previously-present label is gone (e.g., a Jira automation stripped it)
- **THEN** the script SHALL exit non-zero with a structured error block listing pre-write labels, requested adds, post-write labels, and the missing set
- **AND** `jira-agent` SHALL surface that error to the orchestrator instead of returning a success result

#### Scenario: Script fails closed when env vars are missing
- **WHEN** the script is invoked with either `JIRA_EMAIL` or `JIRA_API_TOKEN` unset
- **THEN** the script SHALL exit non-zero before any Jira REST call
- **AND** stderr SHALL contain a one-line remediation message naming the missing variable(s)

#### Scenario: Script fails closed when curl or jq is missing
- **WHEN** the script is invoked on a machine where either `curl` or `jq` is not on `PATH`
- **THEN** the script SHALL exit non-zero with a clear message naming the missing dependency

### Requirement: Auth for Jira label writes SHALL be supplied via environment variables

The script SHALL authenticate to Jira using `JIRA_EMAIL` and `JIRA_API_TOKEN` read from the process environment. No credential SHALL be stored in `config.json`, in any rendered skill file, or anywhere inside the project tree. The `jira-config-prompts.md` reference file SHALL document the env-var requirement and how to obtain a Jira API token.

#### Scenario: Config.json SHALL NOT carry credentials
- **WHEN** the generated `config.json` is inspected after a fresh `/claudboard-workflow` run
- **THEN** it SHALL NOT contain any key named `token`, `apiToken`, `password`, `auth`, or equivalent
- **AND** the `jira` block SHALL contain only non-secret configuration (`cloudId`, `projectKey`, `urlBase`, `customFields`, `transitions`, `labels`)

#### Scenario: Documentation surfaces the env-var requirement
- **WHEN** `jira-config-prompts.md` is read by `claudboard-workflow`
- **THEN** it SHALL contain a section documenting that `/start-feature` requires `JIRA_EMAIL` and `JIRA_API_TOKEN` env vars at runtime
- **AND** the section SHALL include a brief pointer to how to generate a Jira API token

### Requirement: Orchestrator SHALL pass only the additive label set, never a merged set

The rendered `SKILL.md` SHALL instruct the orchestrator to compute `labelsToAdd` as the union of the configured `ai` labels and the resolved area label for the current work area (if non-null). The orchestrator SHALL NOT read the ticket's existing labels, SHALL NOT compute a merged set, and SHALL NOT pass the existing labels to `jira-agent` in any form.

#### Scenario: Orchestrator constructs the additive set from config only
- **WHEN** the orchestrator prepares to call `addLabels` for a backend work area with `ai = ["AI", "AI_CLI"]` and `area.backend = "BE"`
- **THEN** `labelsToAdd` SHALL be `["AI", "AI_CLI", "BE"]`
- **AND** the orchestrator SHALL NOT have called `fetchAndPrepare` for the purpose of reading existing labels
- **AND** the orchestrator SHALL NOT include any existing-label data in the `addLabels` payload

#### Scenario: Area label null is omitted from the additive set
- **WHEN** the resolved area label for the current work is `null` (either `area: null` at top level or the per-area entry is `null`)
- **THEN** `labelsToAdd` SHALL contain only the `ai` labels and no area label

### Requirement: The create action SHALL route labels through addLabels, not additional_fields

The `create` action on jira-agent SHALL invoke `createJiraIssue` without any `labels` entry in `additional_fields`. Immediately after ticket creation succeeds, `create` SHALL invoke the `addLabels` flow (i.e., the same script) with the configured `ai` labels and the resolved area label for the work type. There SHALL be exactly one codepath in the rendered skill by which a label reaches a Jira ticket.

#### Scenario: create does not pass labels to createJiraIssue
- **WHEN** the rendered `agents/jira-agent.md` `create` action is inspected
- **THEN** the documented `createJiraIssue` call SHALL NOT include a `labels` key in `additional_fields`

#### Scenario: create adds labels via the script after ticket creation
- **WHEN** the `create` action runs and `createJiraIssue` returns ticket key `PLAT-200`
- **AND** the configured additive set for the work area is `["AI", "AI_CLI", "BE"]`
- **THEN** the agent SHALL invoke `scripts/jira-add-labels.sh --ticket PLAT-200 --add AI --add AI_CLI --add BE` before emitting its result block

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

---

## Requirements (automated-cost-tracking additions)

### Requirement: Phase 7b cost comment — JIRA variant
The generated feature-workflow SKILL.md SHALL instruct the orchestrator to compute the actual session cost autonomously from the Claude Code session JSONL and post a per-phase/per-agent cost breakdown comment to the JIRA ticket. The orchestrator SHALL NOT prompt the user for `/cost` output or any cost-related input.

Phase 7b (JIRA) steps:
1. Read `claude-pricing.md`
2. Run the JSONL cost script (see `automated-cost-computation` capability) to obtain `ACTUAL_TOTAL`
3. Build the per-phase/per-agent table from SPAWN_LOG × profile estimates, with orchestrator row = `ACTUAL_TOTAL − Σ(sub_agent_estimates)`
4. Compose the comment and post it via jira-agent; proceed immediately to Phase 7c

#### Scenario: JIRA cost comment posted without user interaction
- **WHEN** the feature-workflow reaches Phase 7b (JIRA variant)
- **THEN** the orchestrator computes the cost, composes the comment, and posts it without asking the user anything

#### Scenario: JIRA comment includes actual total and breakdown table
- **WHEN** the cost comment is posted
- **THEN** it contains `**Actual session cost:** $X.XX`, a per-phase/per-agent table with Spawns and Est. Cost columns, and a footer note explaining the computation source

---

### Requirement: Phase 7b cost comment — T&R variant
The generated feature-workflow SKILL.md SHALL instruct the orchestrator to apply the same autonomous cost computation to the T&R Phase 7b summary comment. The `$XX.XX (from /cost)` placeholder SHALL be replaced with the JSONL-computed actual total. The orchestrator SHALL NOT prompt the user for `/cost` output.

#### Scenario: T&R cost comment posted without user interaction
- **WHEN** the feature-workflow reaches Phase 7b (T&R variant)
- **THEN** the orchestrator computes the cost and posts the comment without any user prompt

#### Scenario: T&R comment cost section shows actual total
- **WHEN** the T&R summary comment is composed
- **THEN** the Cost Analysis section displays `**Actual session cost:** $X.XX` from the JSONL computation, not `$XX.XX (from /cost)`

---

### Requirement: Spawn-count tracking across phases
The generated feature-workflow SKILL.md SHALL instruct the orchestrator to record a SPAWN_LOG memo at the end of each phase and to capture `SESSION_JSONL_PATH` at Phase 1 kickoff.

SPAWN_LOG format:
```
SPAWN_LOG:
  phase1: <agent>×<n>, ...
  phase2: <agent>×<n>, ...
  ...
```

`SESSION_JSONL_PATH` = `~/.claude/projects/$(pwd | sed 's|/|-|g')/$CLAUDE_CODE_SESSION_ID.jsonl`, recorded before any directory change.

#### Scenario: SPAWN_LOG available at Phase 7b
- **WHEN** the workflow has run through Phase 6
- **THEN** the orchestrator holds a SPAWN_LOG covering all spawned agents per phase

#### Scenario: SESSION_JSONL_PATH captured at kickoff
- **WHEN** Phase 1 begins
- **THEN** the orchestrator records `SESSION_JSONL_PATH` using `$CLAUDE_CODE_SESSION_ID` and the current working directory

---

## Requirements (pause-on-prompts additions)

### Requirement: Interactive checkpoints must actually pause the CLI
Generated `feature-workflow` skills SHALL pause the CLI at every documented interactive checkpoint (autonomy prompt, synthesis HALT, manual-mode `proceed`, blocker recovery, gate confirmation, any other "wait for user" point) using one of exactly two mechanisms: (1) calling `AskUserQuestion`, or (2) ending the orchestrator's turn immediately after printing the prompt with no further tool calls and no further text in the same response. The template SHALL state this two-mechanism rule once, in a top-level "Halt mechanics" subsection, and SHALL reference it from every later HALT/wait/prompt instruction.

#### Scenario: Autonomy prompt pauses via AskUserQuestion
- **WHEN** the orchestrator reaches the clarification-autonomy entry prompt and `AskUserQuestion` is available
- **THEN** the orchestrator SHALL call `AskUserQuestion` with options `Accept default (<default>)`, `a — autopilot`, `b — balanced`, `c — guided`, `d — manual` and SHALL NOT call any other tool in the same response

#### Scenario: Autonomy prompt fallback ends the turn
- **WHEN** the orchestrator reaches the autonomy prompt and `AskUserQuestion` is unavailable
- **THEN** the orchestrator SHALL print the documented prompt line verbatim and SHALL end its turn immediately — no further tool calls, no further text — until the user responds

#### Scenario: Synthesis HALT ends the turn in blocking autonomy levels
- **WHEN** the resolved autonomy level is `balanced`, `guided`, or `manual` AND Phase 1-syn synthesis has been printed
- **THEN** the orchestrator SHALL end its turn immediately after the synthesis output and SHALL NOT call any further tool until the user has replied with `confirm` or `correct: <feedback>`

#### Scenario: Manual-mode proceed waits at end of turn
- **WHEN** the resolved autonomy level is `manual` AND the orchestrator has asked its free-form clarification questions
- **THEN** the orchestrator SHALL end its turn after each question batch and SHALL NOT advance past Phase 1a until the user has replied with `proceed` (or equivalent)

#### Scenario: Blocker recovery and other "wait" points
- **WHEN** any phase reaches a point documented as "halt and tell the user", "wait for guidance", or "stop and ask"
- **THEN** the orchestrator SHALL end its turn immediately after surfacing the blocker text and SHALL NOT call any further tool until the user has provided guidance

#### Scenario: Plain text alone never substitutes for pause
- **WHEN** an interactive checkpoint is reached AND the orchestrator emits only printed text (no `AskUserQuestion`, no end-of-turn)
- **THEN** the implementation SHALL be considered non-conformant with this requirement, because the CLI does not pause on plain text and the user cannot respond

#### Scenario: Halt mechanics subsection is present and referenced
- **WHEN** a newly generated `feature-workflow/SKILL.md` is inspected
- **THEN** it SHALL contain a top-level `## Halt mechanics` subsection that states the two-mechanism rule, AND every later HALT / wait / prompt / `proceed` instruction in the file SHALL either explicitly say "end the turn" / "use AskUserQuestion" or reference the Halt-mechanics subsection

