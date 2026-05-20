## MODIFIED Requirements

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

