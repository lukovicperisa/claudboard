## MODIFIED Requirements

### Requirement: config.json input flow

The system SHALL produce `config.json` for the generated `feature-workflow/`
skill via a three-tier resolution: auto-detect → sibling-repo inheritance →
user prompt. The user SHALL be able to stub any field with a `TODO`
placeholder to defer. The config SHALL contain a top-level `tracker`
discriminator (`"jira"` | `"tr"` | absent) and a top-level `repo`
discriminator (`"ado"` | `"github"` | absent). The backend-specific block
matching the active discriminator SHALL be populated; the other backend's
block in the same dimension SHALL be absent.

The sibling-repo inheritance tier SHALL NOT fire when there are no
inheritable values that would actually change the resolved config — see
the "Sibling-repo inheritance offer" scenario below for the precise
trigger and the two new suppression scenarios for the negative cases.

#### Scenario: Sibling-repo inheritance offer
- **WHEN** at least one sibling directory under the parent of the target
  repo contains `.claude/skills/feature-workflow/config.json` with the
  same active tracker and repo backends AND at least one inheritable
  field in that sibling holds a value that is BOTH (a) not a
  `[TODO: …]` stub left by a prior orchestrator run AND (b) different
  from the documented default for that field
- **THEN** the system SHALL display the inheritable shared values
  (tracker-specific: Jira `cloudId`/`projectKey`/`customFields` or T&R
  `baseUrl`/`projectKey`; repo-specific: ADO `organization`/`project`
  or GitHub `linkingKeyword`) — restricted to only the non-stub
  non-default values — and ask: "Inherit shared config from <sibling>?
  [y/n/edit]"

#### Scenario: Sibling with all-stub config suppresses offer
- **WHEN** the only sibling(s) matching the active backends have every
  inheritable field set to a value matching `^\[TODO: .*\]$`
- **THEN** the orchestrator SHALL proceed directly from Phase 2a
  (auto-detect) to Phase 2c (per-field prompting) with no Phase 2b
  narration about siblings or inheritance and no y/n prompt

#### Scenario: Sibling values match defaults suppresses offer
- **WHEN** the only sibling(s) matching the active backends have every
  inheritable field set to either a `[TODO: …]` stub OR a value that
  exactly matches the documented default for that field (e.g.,
  `jira.customFields.sprint = customfield_10001`,
  `jira.customFields.acceptanceCriteria = customfield_12206`,
  `github.linkingKeyword = Closes`)
- **THEN** the orchestrator SHALL proceed directly from Phase 2a to
  Phase 2c with no Phase 2b narration about siblings and no y/n prompt;
  the per-field prompts in Phase 2c SHALL still apply the same default
  values, producing a resolved config bit-identical to one in which the
  user had answered "y" to the suppressed offer

#### Scenario: Sibling inheritance accepted
- **WHEN** the user accepts the sibling-inheritance offer
- **THEN** the inherited values SHALL be written into the new
  `config.json` verbatim; per-repo identifiers (ADO `repositoryId`,
  GitHub `owner`/`repo`) SHALL still be requested or auto-detected for
  the new repo
