# Delta — feature-workflow-generation (claudboard-workflow-non-interactive)

## MODIFIED Requirements

### Requirement: config.json input flow

The system SHALL produce `config.json` for the generated `feature-workflow/`
skill via a two-tier resolution: auto-detect-or-default → sibling-repo
inheritance. The orchestrator SHALL NOT prompt the user for individual
`config.json` field values; any field that cannot be auto-detected and is
not covered by a documented default SHALL be silently stubbed as
`[TODO: FIELD_NAME]`. The config SHALL contain a top-level `tracker`
discriminator (`"jira"` | `"tr"` | absent) and a top-level `repo`
discriminator (`"ado"` | `"github"` | absent). The backend-specific block
matching the active discriminator SHALL be populated; the other backend's
block in the same dimension SHALL be absent.

The sibling-repo inheritance tier SHALL NOT fire when there are no
inheritable values that would actually change the resolved config — see
the "Sibling-repo inheritance offer" scenario for the precise trigger
and the two suppression scenarios for the negative cases.

#### Scenario: Atlassian site auto-detection

- **WHEN** `TRACKER_JIRA` is the active backend
- **THEN** the system SHALL call `mcp__atlassian__getAccessibleAtlassianResources` exactly once and populate `jira.cloudId` from the first resource's `id` and `jira.urlBase` from its `url` field
- **AND** on call failure (network error, OAuth not completed, empty result), both fields SHALL be stubbed as `[TODO: JIRA_CLOUD_ID]` and `[TODO: JIRA_URL_BASE]` without prompting

#### Scenario: Jira project-key heuristic

- **WHEN** `TRACKER_JIRA` is the active backend AND the project is NOT in workspace mode
- **THEN** the system SHALL set `jira.projectKey` to `uppercase(basename($PROJECT_PATH))` if the resulting string matches `^[A-Z]+$`; otherwise the system SHALL stub it as `[TODO: JIRA_PROJECT_KEY]` without prompting

#### Scenario: Jira project-key in workspace mode

- **WHEN** `TRACKER_JIRA` is the active backend AND the project IS in workspace mode (`WORKSPACE_MODE = true`)
- **THEN** the system SHALL unconditionally stub `jira.projectKey` as `[TODO: JIRA_PROJECT_KEY]` — the workspace name is not a valid project-key heuristic source

#### Scenario: Jira documented defaults applied silently

- **WHEN** `TRACKER_JIRA` is the active backend AND the corresponding field is not set by inheritance
- **THEN** the system SHALL write the following documented defaults without prompting and without MCP confirmation:
  - `jira.customFields.sprint = "customfield_10001"`
  - `jira.customFields.acceptanceCriteria = "customfield_12206"`
  - `jira.transitions.start = "In Progress"`
  - `jira.transitions.success = "In Review"`
  - `jira.transitions.failure = "Blocked"`
  - `jira.labels.area = {"backend": "BE", "frontend": "FE", "devops": "DevOps", "docs": "Docs"}`

#### Scenario: Azure DevOps repositoryId stubbed silently

- **WHEN** `REPO_ADO` is the active backend
- **THEN** the system SHALL stub `azureDevOps.repositoryId` as `[TODO: ADO_REPO_ID]` without prompting; `azureDevOps.organization`, `azureDevOps.project`, and `azureDevOps.repositoryName` continue to be auto-extracted from the git remote URL per the existing scenario

#### Scenario: GitHub linking-keyword default applied silently

- **WHEN** `REPO_GITHUB` is the active backend
- **THEN** the system SHALL write `github.linkingKeyword = "Closes"` without prompting

#### Scenario: Git branch convention defaults applied silently

- **WHEN** the generation flow reaches the git-field resolution step
- **THEN** the system SHALL write `git.branchTypes = ["feature", "bugfix", "hotfix"]`, `git.branchPattern = "{type}/{ticket}/{slug}"` if any tracker flag is true else `"{type}/{slug}"`, and `git.ticketRegex = "[A-Z]+-[0-9]+"` without prompting

#### Scenario: Completion-report stub list

- **WHEN** any `config.json` field in the generated artifact has a value matching `^\[TODO: .*\]$`
- **THEN** the Phase 7 completion report SHALL contain an `## Unfilled config values` subsection that lists every stub on its own line as `<json_path>  [TODO: ...]`, followed by the `config.json` filesystem path the user must edit
- **AND** when zero stubs were written, this subsection SHALL be omitted entirely

#### Scenario: Sibling-repo inheritance offer

- **WHEN** at least one sibling directory under the parent of the target repo contains `.claude/skills/feature-workflow/config.json` with the same active tracker and repo backends AND at least one inheritable field in that sibling holds a value that is BOTH (a) not a `[TODO: …]` stub left by a prior orchestrator run AND (b) different from the documented default for that field
- **THEN** the system SHALL display the inheritable shared values and ask: "Inherit shared config from <sibling>? [y/n/edit]"
- **AND** accepted inheritance SHALL overwrite the values written by Phase 2a-bis silent auto-fill (sibling > default > stub precedence)

#### Scenario: Sibling with all-stub config suppresses offer

- **WHEN** the only sibling(s) matching the active backends have every inheritable field set to a value matching `^\[TODO: .*\]$`
- **THEN** the orchestrator SHALL proceed directly from Phase 2a-bis (silent auto-fill) to Phase 3 (capability-flag resolution) with no Phase 2b narration about siblings or inheritance and no y/n prompt

#### Scenario: Sibling values match defaults suppresses offer

- **WHEN** the only sibling(s) matching the active backends have every inheritable field set to either a `[TODO: …]` stub OR a value that exactly matches the documented default for that field
- **THEN** the orchestrator SHALL proceed directly from Phase 2a-bis to Phase 3 with no Phase 2b narration about siblings and no y/n prompt; the Phase 2a-bis silent auto-fill SHALL produce a resolved config bit-identical to one in which the user had answered "y" to the suppressed offer

## REMOVED Requirements

### Requirement: User prompted for missing values
**Reason:** Phase 2c (the per-field prompt loop) is deleted entirely. The replacement contract — silent stubbing for any field that auto-detect-or-default cannot cover — is captured by the "Atlassian site auto-detection", "Jira project-key heuristic", "Azure DevOps repositoryId stubbed silently", and "Completion-report stub list" scenarios under the MODIFIED `config.json input flow` requirement. The original scenario ("WHEN any required field cannot be auto-detected or inherited THEN the system SHALL prompt the user, offering: a free-text answer, a default if applicable, or 'stub with TODO and continue'") is incompatible with the non-interactive contract.

**Migration:** Users who previously relied on the prompts to learn what each field meant can read `skills/claudboard-workflow/references/tracker-config-prompts.md` and `repo-config-prompts.md` — those files remain on disk as documentation. After a `/claudboard-workflow` run, every silently-stubbed field is listed in the completion report's "Unfilled config values" subsection with the `config.json` filesystem path for manual editing.
