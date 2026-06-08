## ADDED Requirements

### Requirement: Jira label script SHALL accept JIRA_USERNAME as an alias for JIRA_EMAIL

The rendered `scripts/jira-add-labels.sh` SHALL treat `JIRA_USERNAME` as an alias for `JIRA_EMAIL` when the latter is unset. The script SHALL resolve the effective email value by reading `JIRA_EMAIL` first and falling back to `JIRA_USERNAME` only when `JIRA_EMAIL` is empty or unset. The resolved value SHALL be used in the basic-auth header passed to Jira REST.

The script SHALL exit non-zero before any Jira REST call only when BOTH `JIRA_EMAIL` and `JIRA_USERNAME` are unset (or both empty). The stderr remediation message SHALL name both accepted variable names so the user understands either is sufficient.

The canonical name in all rendered documentation (script header docstring, `agents/jira-agent.md`, `tracker-config-prompts.md`, `config.json` header comment) SHALL remain `JIRA_EMAIL`. The alias SHALL be documented alongside the canonical name so a reader encountering either name in an existing shell environment can identify which one is in effect.

#### Scenario: JIRA_EMAIL set takes precedence
- **WHEN** the script is invoked with `JIRA_EMAIL=primary@example.com` and `JIRA_USERNAME=secondary@example.com` both exported
- **THEN** the basic-auth header SHALL be constructed from `primary@example.com:$JIRA_API_TOKEN`
- **AND** `JIRA_USERNAME` SHALL be ignored

#### Scenario: JIRA_USERNAME is used when JIRA_EMAIL is unset
- **WHEN** the script is invoked with `JIRA_EMAIL` unset and `JIRA_USERNAME=user@example.com` exported
- **AND** `JIRA_API_TOKEN` is also exported
- **THEN** the script SHALL NOT emit the "missing required env var(s)" error
- **AND** the basic-auth header SHALL be constructed from `user@example.com:$JIRA_API_TOKEN`
- **AND** the script SHALL proceed to the Jira REST GET / PUT / verify sequence exactly as it would when `JIRA_EMAIL` is set

#### Scenario: Both names unset still fails closed
- **WHEN** the script is invoked with both `JIRA_EMAIL` and `JIRA_USERNAME` unset
- **THEN** the script SHALL exit non-zero before any Jira REST call
- **AND** the stderr message SHALL name both accepted variable names — i.e. SHALL contain the substring `JIRA_EMAIL` AND the substring `JIRA_USERNAME`
- **AND** the remediation hint SHALL show an `export` example for each accepted name

#### Scenario: Documentation surfaces the alias consistently
- **WHEN** the rendered `feature-workflow/` skill is inspected after `/claudboard-workflow` runs
- **THEN** the script header docstring, `agents/jira-agent.md` env-var paragraphs, `tracker-config-prompts.md` env-var table, and `config.json` credential-handling header comment SHALL each acknowledge `JIRA_USERNAME` as an accepted alias next to the canonical `JIRA_EMAIL`
- **AND** no rendered file SHALL claim that `JIRA_EMAIL` is the only accepted name
