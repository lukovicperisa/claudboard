## ADDED Requirements

### Requirement: Repo-backend action contract

The system SHALL define a fixed action contract that every supported pr-agent (`pr-agent-ado.md`, `pr-agent-github.md`) implements. Agents receive an `action` field in INPUT CONTEXT and dispatch on it. The orchestrator SHALL call actions by name regardless of which backend is active.

The v1 action set is: `createPullRequest`, `linkTicket`, `verifyPipelineRun`, `getPullRequestStatus`.

#### Scenario: Action dispatch by name on ADO
- **WHEN** the orchestrator spawns a repo agent with `action: "createPullRequest"` and the backend is `REPO_ADO`
- **THEN** `pr-agent-ado.md` SHALL handle the action via the Azure DevOps MCP's PR-creation tool

#### Scenario: Action dispatch by name on GitHub
- **WHEN** the orchestrator spawns a repo agent with `action: "createPullRequest"` and the backend is `REPO_GITHUB`
- **THEN** `pr-agent-github.md` SHALL handle the action via the official GitHub MCP's PR-creation tool

### Requirement: ADO backend capability set

The system SHALL implement the Azure DevOps flow under the `REPO_ADO` capability flag. The agent SHALL map actions to the Azure DevOps MCP tool surface, including PR creation, work item linking via the ADO work-item-link field, pipeline trigger checks, and branch policy enforcement notes.

The repo identifier in `config.json` for `REPO_ADO` SHALL be `azureDevOps.repositoryId` (a GUID).

#### Scenario: PR creation on ADO
- **WHEN** `createPullRequest` is invoked with title, description, sourceBranch, targetBranch, and the active backend is `REPO_ADO`
- **THEN** `pr-agent-ado.md` SHALL create the PR via the Azure DevOps MCP, attach the ticket key to the work-item-link field, and return the PR URL

#### Scenario: Pipeline trigger check on ADO
- **WHEN** `verifyPipelineRun` is invoked after a PR push and the active backend is `REPO_ADO`
- **THEN** `pr-agent-ado.md` SHALL poll the Azure DevOps MCP for the most recent pipeline run on the PR branch and return its status

### Requirement: GitHub backend capability set

The system SHALL implement the GitHub flow under the `REPO_GITHUB` capability flag. The agent SHALL use the official GitHub MCP and SHALL match ADO at the intent level — same workflow shape, different primitives.

The repo identifier in `config.json` for `REPO_GITHUB` SHALL be `github.owner` and `github.repo` (a `owner/repo` slug pair).

Ticket-to-PR linking SHALL be achieved by including `Closes #<N>` (or `Fixes #<N>`, configurable) in the PR description body, since GitHub has no separate work-item-link field.

Pipeline verification SHALL be achieved by polling GitHub Actions workflow runs for the PR branch via the GitHub MCP, since GitHub Actions runs are event-triggered (no manual trigger required).

Branch protection awareness SHALL be advisory: the agent SHALL document in the PR description any rule-protected branches encountered, but SHALL NOT attempt to mutate Branch Protection Rules or Rulesets.

#### Scenario: PR creation on GitHub
- **WHEN** `createPullRequest` is invoked with title, description, sourceBranch, targetBranch, and the active backend is `REPO_GITHUB`
- **THEN** `pr-agent-github.md` SHALL create the PR via the official GitHub MCP, append `Closes #<ticketNumber>` to the description (when the ticket reference is numeric and `github.linkingKeyword` is configured), and return the PR URL

#### Scenario: Issue linking via PR body
- **WHEN** `linkTicket` is invoked with a ticket key on `REPO_GITHUB`
- **THEN** `pr-agent-github.md` SHALL update the existing PR's description body to include `<linkingKeyword> #<N>` (default keyword: `Closes`) and SHALL NOT attempt to write any GitHub field outside the PR body

#### Scenario: Pipeline verification via Actions runs
- **WHEN** `verifyPipelineRun` is invoked after a PR push and the active backend is `REPO_GITHUB`
- **THEN** `pr-agent-github.md` SHALL list Actions workflow runs for the PR branch via the GitHub MCP and return the latest run's status

### Requirement: Repo selection in config.json

The generated `config.json` SHALL include a top-level `repo` discriminator key with value `"ado"` or `"github"`. The corresponding backend-specific block (`azureDevOps` or `github`) SHALL be present, and the other repo backend's block SHALL be absent.

#### Scenario: ADO-only config
- **WHEN** `REPO_ADO` is the active backend
- **THEN** `config.json` SHALL contain `"repo": "ado"`, a populated `"azureDevOps": { organization, project, repositoryId }` block, and no `"github"` key

#### Scenario: GitHub-only config
- **WHEN** `REPO_GITHUB` is the active backend
- **THEN** `config.json` SHALL contain `"repo": "github"`, a populated `"github": { owner, repo, linkingKeyword }` block (with `linkingKeyword` defaulting to `"Closes"`), and no `"azureDevOps"` key

#### Scenario: Neither repo configured
- **WHEN** neither `REPO_ADO` nor `REPO_GITHUB` is active (no repo MCP detected)
- **THEN** `config.json` SHALL omit the `repo` key and both backend blocks; the generated `SKILL.md` SHALL have no PR phases (Phase 6 stubbed)

### Requirement: PR agent file is verbatim and conditional

Each PR-agent file SHALL be written to `agents/pr-agent-<backend>.md` verbatim from the template tree (no substitution required) and SHALL only be written when its corresponding capability flag is true. Both PR agents MUST NOT be present in the same generated workflow.

#### Scenario: ADO agent written
- **WHEN** `REPO_ADO` is true
- **THEN** `agents/pr-agent-ado.md` SHALL be written verbatim and `agents/pr-agent-github.md` SHALL NOT be written

#### Scenario: GitHub agent written
- **WHEN** `REPO_GITHUB` is true
- **THEN** `agents/pr-agent-github.md` SHALL be written verbatim and `agents/pr-agent-ado.md` SHALL NOT be written

#### Scenario: Neither repo active
- **WHEN** neither repo flag is true
- **THEN** neither PR-agent file SHALL be written and Phase 6 SHALL be omitted from `SKILL.md`

### Requirement: git-agent branch-protection awareness per backend

The shared `git-agent.md` template SHALL include backend-aware branch-protection blocks: an `IF REPO_ADO` block referencing Azure DevOps branch policies, and an `IF REPO_GITHUB` block referencing GitHub Branch Protection Rules / Rulesets. Only the block matching the active backend SHALL be rendered.

#### Scenario: ADO branch policy block rendered
- **WHEN** `REPO_ADO` is true
- **THEN** the rendered `git-agent.md` SHALL contain the ADO branch-policy guidance block and SHALL NOT contain the GitHub block

#### Scenario: GitHub Rulesets block rendered
- **WHEN** `REPO_GITHUB` is true
- **THEN** the rendered `git-agent.md` SHALL contain the GitHub Branch Protection Rules / Rulesets guidance block and SHALL NOT contain the ADO block
