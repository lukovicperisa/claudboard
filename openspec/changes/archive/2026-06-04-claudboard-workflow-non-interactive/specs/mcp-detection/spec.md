# Delta — mcp-detection (claudboard-workflow-non-interactive)

## ADDED Requirements

### Requirement: Invocation-hint pre-resolution for dimension conflicts

The orchestrator SHALL parse the user's invocation text (the full message
that triggered the skill, including any tokens following
`/claudboard-workflow`) for backend hints BEFORE evaluating any
`mcp.ambiguities` entry. A hint is a case-insensitive whole-word match
against the per-dimension token tables. When a hint matches a dimension
that has a detected conflict, the conflicting backend SHALL be suppressed
silently and the dimension SHALL be removed from `mcp.ambiguities` so no
precedence-prompt fires for it.

#### Scenario: Tracker hint resolves dimension silently

- **WHEN** both `tracker_jira` and `tracker_tr` are detected at the same precedence level AND the user's invocation text contains a whole-word case-insensitive match for any of `jira`, `atlassian`
- **THEN** the system SHALL set `tracker_jira = true`, `tracker_tr = false`, record `sources.tracker_jira.matched_via = "invocation-hint"`, remove the `tracker` entry from `mcp.ambiguities`, and NOT display the tracker precedence-prompt
- **AND** symmetrically for tokens `tr`, `t&r`, `track`, `bosch` resolving to `tracker_tr = true`

#### Scenario: Repo hint resolves dimension silently

- **WHEN** both `repo_ado` and `repo_github` are detected at the same precedence level AND the user's invocation text contains a whole-word case-insensitive match for any of `ado`, `azure`, `devops`
- **THEN** the system SHALL set `repo_ado = true`, `repo_github = false`, record `sources.repo_ado.matched_via = "invocation-hint"`, remove the `repo` entry from `mcp.ambiguities`, and NOT display the repo precedence-prompt
- **AND** symmetrically for tokens `github`, `gh` resolving to `repo_github = true`

#### Scenario: Both hints in a dimension cancel pre-resolution

- **WHEN** the user's invocation text contains whole-word matches for BOTH a `tracker_jira` token AND a `tracker_tr` token (e.g. "compare jira vs tr")
- **THEN** the system SHALL NOT pre-resolve the tracker dimension; the conflict-prompt SHALL fire as if no hint were present
- **AND** symmetrically for the repo dimension when both repo tokens match

#### Scenario: Hint without configured MCP is silently ignored

- **WHEN** the user's invocation text contains a hint token for a backend that is NOT configured in any detected MCP server (e.g. user wrote "use github" but no GitHub MCP is configured)
- **THEN** the system SHALL silently ignore the hint and proceed with normal precedence resolution (no warning, no error)

#### Scenario: Hint match requires word boundary

- **WHEN** the user's invocation text contains a hint token as a substring of a larger word (e.g. `github-actions-test`, `jiragate`)
- **THEN** the system SHALL NOT treat this as a hint match — boundaries SHALL be whitespace, punctuation, or string start/end

## MODIFIED Requirements

### Requirement: Precedence-prompt when two MCPs in a dimension are detected
The orchestrator SHALL display a numbered conflict prompt asking the user to choose when both backends in a dimension (tracker or repo) are detected at the same precedence level AND no invocation-hint resolved the dimension. The prompt SHALL fire exactly once per conflicting dimension during Phase 1d and SHALL NOT repeat in later phases.

#### Scenario: Both tracker MCPs detected, no hint

- **WHEN** both `tracker_jira` and `tracker_tr` are detected at the same precedence level AND no invocation-hint matched the tracker dimension
- **THEN** the orchestrator SHALL display the numbered tracker conflict prompt listing both backends with their source paths and SHALL wait for a numeric response (`1` or `2`) before continuing

#### Scenario: Both repo MCPs detected, no hint

- **WHEN** both `repo_ado` and `repo_github` are detected at the same precedence level AND no invocation-hint matched the repo dimension
- **THEN** the orchestrator SHALL display the numbered repo conflict prompt and SHALL wait for a numeric response before continuing

#### Scenario: Both prompts independent

- **WHEN** both dimensions have conflicts AND neither dimension was resolved by an invocation hint
- **THEN** the tracker prompt and repo prompt SHALL be displayed independently (one after the other), each requiring its own numeric response
