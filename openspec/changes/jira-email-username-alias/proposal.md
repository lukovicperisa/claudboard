## Why

Every `/start-feature` run in projects whose developers have an Atlassian-CLI-style shell environment (`JIRA_URL` / `JIRA_USERNAME` / `JIRA_API_TOKEN`) fails immediately at the Jira label step with:

```
Error: missing required env var(s): JIRA_EMAIL
```

The rendered `scripts/jira-add-labels.sh` from `feature-workflow.template` hard-requires the variable name `JIRA_EMAIL` (template line 51). The atlassian-cli ecosystem (`jira-cli`, `act`, several Atlassian-published quickstart guides) standardised on `JIRA_USERNAME` for the same value years before the additive-labels script was written, and developers who already have one of those tools installed (or who followed Atlassian's own setup docs) end up with `JIRA_USERNAME` exported and `JIRA_EMAIL` absent. There is no warning at config time — the failure is uniformly post-ticket-creation, breaking the run after the ticket has already been created and labels are the only remaining step.

This is a name-mismatch bug, not a credential problem. The value the user has in `JIRA_USERNAME` is literally the email Atlassian needs; the script just doesn't look for it under that name.

The contract the script publishes (`JIRA_EMAIL`-only) is also stricter than necessary: the value flows straight into a basic-auth header — Jira itself does not care which env var supplied the email. Accepting `JIRA_USERNAME` as a fallback when `JIRA_EMAIL` is unset closes the gap with zero behaviour change for the existing `JIRA_EMAIL`-using callers and zero new failure modes.

## What Changes

- **MODIFIED** `skills/claudboard-workflow/references/feature-workflow.template/scripts/jira-add-labels.sh` — in the env-var preflight, fall back to `JIRA_USERNAME` when `JIRA_EMAIL` is unset (`JIRA_EMAIL="${JIRA_EMAIL:-${JIRA_USERNAME:-}}"`), and update the missing-var error message to name both accepted variables so the remediation text matches reality. Update the script's header docstring to document the alias.
- **MODIFIED** `skills/claudboard-workflow/references/feature-workflow.template/agents/jira-agent.md.template` — wherever the agent prose currently says "requires `JIRA_EMAIL` and `JIRA_API_TOKEN`", change to "requires `JIRA_EMAIL` (or `JIRA_USERNAME`) and `JIRA_API_TOKEN`" (two occurrences: lines 169 and 306 of the template).
- **MODIFIED** `skills/claudboard-workflow/references/feature-workflow.template/config.json.template` — update the credential-handling header comment (line 4) to mention both accepted variable names.
- **MODIFIED** `skills/claudboard-workflow/references/tracker-config-prompts.md` — in the "Environment-Variable Requirements (Jira)" table, document the `JIRA_USERNAME` alias and explain when each name appears in the wild (atlassian-cli ecosystem). Update the `export` snippet to show both forms.

Out of scope:
- Renaming the canonical variable from `JIRA_EMAIL` to `JIRA_USERNAME`. `JIRA_EMAIL` was chosen deliberately to be self-documenting — basic-auth against Jira Cloud takes an email, not an arbitrary username. The alias closes the compatibility gap without losing that clarity.
- Reading credentials from `config.json` or any on-disk file. The "no secrets in the project tree" invariant from `2026-05-18-jira-additive-labels` stands.
- Patching `feature-workflow/scripts/jira-add-labels.sh` copies already rendered into downstream projects. The user can hand-patch the same one-line change in any deployed copy, or re-run `/claudboard-workflow` per the existing v1 no-upgrade-path policy.

## Capabilities

### New Capabilities
None.

### Modified Capabilities
- `feature-workflow-generation`: the env-var contract for the rendered Jira label script loosens to accept `JIRA_USERNAME` as an alias for `JIRA_EMAIL`. The previously specified failure scenario (`unset → exit non-zero`) is preserved but tightens its trigger to "both names unset"; the post-fallback behaviour is identical to today's `JIRA_EMAIL`-only path.

## Impact

- **Affected files (modified):**
  - `skills/claudboard-workflow/references/feature-workflow.template/scripts/jira-add-labels.sh` (one-line fallback + error-message + docstring)
  - `skills/claudboard-workflow/references/feature-workflow.template/agents/jira-agent.md.template` (two doc-string edits)
  - `skills/claudboard-workflow/references/feature-workflow.template/config.json.template` (header comment)
  - `skills/claudboard-workflow/references/tracker-config-prompts.md` (env-var table + export snippet)
- **Affected files (unchanged):**
  - `feature-workflow.template/SKILL.md.template` — no orchestrator behaviour changes
  - Any rendered `feature-workflow/` skill in a downstream project (template-only fix; downstream copies update when regenerated)
- **User-visible effect:** After the next `/claudboard-workflow` run in a project, `/start-feature` succeeds for users whose shell exports `JIRA_USERNAME` instead of `JIRA_EMAIL`. Users who export `JIRA_EMAIL` see no change. The post-failure error message names both accepted variables instead of just one.
- **Runtime cost:** $0 — pure template/script edits, no new API calls or dependencies.
- **Risks:**
  - *`JIRA_USERNAME` set to a non-email value.* Some users (rare) may have `JIRA_USERNAME` exported to an Atlassian display name or legacy username rather than an email. Basic-auth against Jira Cloud requires an email, so the script will fail at the Jira REST call with a 401 in that case — same outcome as today's "wrong credentials" path, just one step later. The error is loud (401 + curl body in stderr) and the remediation is the same as for any credential mismatch. Acceptable.
  - *Documentation drift.* The archived `2026-05-18-jira-additive-labels` change's spec text still names only `JIRA_EMAIL`. Archived deltas are immutable by design; the new canonical spec (after this change archives) will be the source of truth. No action needed.
