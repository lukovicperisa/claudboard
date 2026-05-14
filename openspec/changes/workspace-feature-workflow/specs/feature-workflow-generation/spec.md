## ADDED Requirements

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

## MODIFIED Requirements

### Requirement: File generation contract
The system SHALL write generated files only under the resolved feature-workflow skill directory:
- In single-repo mode: `<project>/.claude/skills/feature-workflow/`
- In workspace mode: `<workspace>/.claude/skills/feature-workflow/` (a symlink resolving to `<meta-repo>/.claude/skills/feature-workflow/`)

The system SHALL NOT modify any files outside this directory in either mode.

The generated tree SHALL contain:
- `SKILL.md` (rendered from template; multi-repo variant when `WORKSPACE_MODE` is true)
- `config.json` (synthesized from inputs; workspace shape with `repos: { ... }` map when `WORKSPACE_MODE` is true)
- `agents/jira-agent.md` (verbatim copy if `JIRA_AVAILABLE`)
- `agents/git-agent.md`, `agents/pr-agent.md`, `agents/architect-agent.md`, `agents/implementation-agent.md`, `agents/sdd-expert-agent.md`, `agents/design-reviewer.md`, `agents/spec-reviewer.md` (rendered from templates; `pr-agent.md` skipped if `ADO_AVAILABLE` is false; multi-repo variants when `WORKSPACE_MODE` is true; each accepts a `repo` argument in workspace mode)
- `scripts/lib.sh`, `scripts/prepare-commit.sh`, `scripts/prepare-pr.sh`, `scripts/prepare-squash.sh` (verbatim copies; in workspace mode they SHALL accept a `--repo` flag or `REPO_PATH` env var)
- `scripts/load-repo-context.sh` (NEW; only generated when `WORKSPACE_MODE` is true)
- `references/claude-pricing.md` (verbatim copy)

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

### Requirement: Capability-block resolution
The system SHALL resolve a fixed set of v1 capability flags from the analysis report's "Workflow Signals" subsection and from runtime MCP detection. Each flag drives `<!-- IF FLAG -->...<!-- ENDIF -->` block evaluation in templates.

The v1 capability flags are: `JIRA_AVAILABLE`, `ADO_AVAILABLE`, `WORKSPACE_MODE`, `CROSS_SERVICE_EDGES`, `SHARED_LIB`, `AUTH_PERIMETER`, `MEMORIES_PRESENT`, `MONGODB`, `JPA`, `KAFKA`.

`WORKSPACE_MODE` SHALL gate not only substitution variables (existing behavior) but also the multi-repo variants of SKILL.md, the multi-repo variants of every code-touching agent, the multi-repo `config.json` shape (with `repos: { ... }` map), and the inclusion of `scripts/load-repo-context.sh` in the generated tree.

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
The system SHALL resolve substitution variables from the analysis report and runtime context, then replace `{{VAR}}` tokens in all template files. The v1 substitution catalog is: `PROJECT_NAME`, `REPO_NAME`, `STACK_NAME`, `TEST_FRAMEWORK`, `BASE_PACKAGE`, `BUILD_CMD`, `TEST_CMD`, `LINT_CMD`, `TICKET_PREFIX`, `WORKSPACE_NAME`, `REPO_COUNT`, `REPO_LIST_BULLETS`, `REPOS_MAP_JSON`, `EDGE_TYPES_JOINED`, `SHARED_LIB_NAME`, `SHARED_LIB_CONSUMER_COUNT`, `ECOSYSTEM_MEMORY_NAME`, `REPO_OR_SERVICE_LABEL`, `STACK_REMINDERS`.

`REPOS_MAP_JSON` SHALL render as a JSON object suitable for direct embedding in the workspace `config.json`, mapping repo name to a per-repo settings object containing the auto-detected Azure DevOps `repositoryId` (and any other per-repo overrides identified during generation).

#### Scenario: All substitutions resolvable
- **WHEN** every `{{VAR}}` token in the templates can be resolved from the analysis report or runtime context
- **THEN** all tokens SHALL be replaced and rendered output SHALL contain no `{{...}}` artifacts

#### Scenario: Unresolvable substitution
- **WHEN** a `{{VAR}}` token cannot be resolved (analysis report missing the field and no runtime fallback applies)
- **THEN** the system SHALL log a warning and replace the token with the literal string `[TODO: VAR]` to preserve template structure

#### Scenario: REPOS_MAP_JSON resolution
- **WHEN** `WORKSPACE_MODE` is true and the analysis report enumerates 3 service repos with detectable Azure DevOps remotes
- **THEN** `{{REPOS_MAP_JSON}}` SHALL render as a JSON object with 3 keys (one per repo), each value containing at minimum the `azureDevOps.repositoryId` extracted from that repo's git remote

#### Scenario: REPOS_MAP_JSON with missing per-repo data
- **WHEN** one of the workspace repos has no detectable Azure DevOps remote
- **THEN** the rendering SHALL include the repo with a `[TODO: repositoryId]` stub for that repo and SHALL warn the user during the confirmation gate

#### Scenario: STACK_REMINDERS escape hatch
- **WHEN** the analysis report contains a "Patterns detected" section
- **THEN** `{{STACK_REMINDERS}}` SHALL resolve to a verbatim copy of that section's bullet list, suitable for direct injection into a "Repo conventions worth remembering" block in heavy agents
