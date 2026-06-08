## 1. Script template (`scripts/jira-add-labels.sh`)

- [x] 1.1 In `skills/claudboard-workflow/references/feature-workflow.template/scripts/jira-add-labels.sh`, immediately above the env-var preflight block (currently lines 50-58), insert the fallback assignment: `JIRA_EMAIL="${JIRA_EMAIL:-${JIRA_USERNAME:-}}"` with a one-line comment explaining the atlassian-cli alias
- [x] 1.2 Update the missing-var error message (currently line 54) to read `JIRA_EMAIL (or JIRA_USERNAME)` so the user sees both accepted names in stderr
- [x] 1.3 Update the remediation hint (currently line 55) to show both export options on one line, e.g. `export JIRA_EMAIL=you@example.com  # or JIRA_USERNAME=you@example.com`
- [x] 1.4 Update the header docstring (currently lines 24-27) to document `JIRA_EMAIL` as canonical with `JIRA_USERNAME` accepted as an alias; preserve the existing API-token link and example block

## 2. jira-agent template (`agents/jira-agent.md.template`)

- [x] 2.1 At the occurrence on line 169 ("The script requires `JIRA_EMAIL` and `JIRA_API_TOKEN`…"), change to "The script requires `JIRA_EMAIL` (or `JIRA_USERNAME`) and `JIRA_API_TOKEN`…"
- [x] 2.2 At the occurrence on line 306 ("…authenticates via `JIRA_EMAIL` and `JIRA_API_TOKEN` env vars."), change to "…authenticates via `JIRA_EMAIL` (or `JIRA_USERNAME`) and `JIRA_API_TOKEN` env vars."

## 3. Config template (`config.json.template`)

- [x] 3.1 In the credential-handling header comment (currently line 4: "Credential handling: JIRA_EMAIL/JIRA_API_TOKEN env vars…"), add `(or JIRA_USERNAME)` after `JIRA_EMAIL` so the header comment matches script and agent doc strings

## 4. Tracker config prompts (`tracker-config-prompts.md`)

- [x] 4.1 In the "Environment-Variable Requirements (Jira)" table, change the `JIRA_EMAIL` row description to `Your Atlassian account email (e.g., dev@example.com). Also accepted under the alias JIRA_USERNAME for compatibility with atlassian-cli / jira-cli tooling that already exports JIRA_USERNAME.`
- [x] 4.2 Update the `export` snippet to show both forms — keep `export JIRA_EMAIL=dev@example.com` as primary and add a commented alternative line `# or, if you already use atlassian-cli conventions: export JIRA_USERNAME=dev@example.com`

## 5. Spec delta validation

- [x] 5.1 Run `openspec validate jira-email-username-alias --strict` from `claude-repo-scan/` and resolve any reported issues
- [x] 5.2 Confirm `grep -n 'JIRA_EMAIL' skills/claudboard-workflow/references/` shows no occurrence that mentions `JIRA_EMAIL` without also acknowledging `JIRA_USERNAME` (consistency check across script + agent + config + prompts docs)

## 6. Manual verification

- [x] 6.1 Hand-render the template in a scratch directory (or re-run `/claudboard-workflow` in a test project), confirm `scripts/jira-add-labels.sh` contains the fallback line and the updated error message
- [x] 6.2 With only `JIRA_USERNAME` and `JIRA_API_TOKEN` exported in the shell (no `JIRA_EMAIL`), invoke the rendered script against a sandbox ticket and confirm it succeeds — same outcome as today's `JIRA_EMAIL`-set path
- [x] 6.3 With neither `JIRA_EMAIL` nor `JIRA_USERNAME` exported, confirm the script exits non-zero with stderr naming both accepted variable names
- [x] 6.4 With both `JIRA_EMAIL` and `JIRA_USERNAME` exported to different values, confirm `JIRA_EMAIL` wins (canonical name takes precedence)
