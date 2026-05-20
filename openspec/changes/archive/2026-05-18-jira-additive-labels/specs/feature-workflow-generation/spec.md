## ADDED Requirements

### Requirement: Label writes SHALL go through a deterministic merge script

The rendered `feature-workflow` skill SHALL include a shell script
`scripts/jira-add-labels.sh` that performs all label writes against a
Jira ticket. The script SHALL:

1. Read the ticket's current labels via Jira REST `GET /rest/api/3/issue/{key}?fields=labels`.
2. Compute the union of the current labels and the supplied
   `--add <label>` arguments using `jq` (no LLM in the merge path).
3. Write the result via Jira REST `PUT /rest/api/3/issue/{key}` using
   the body shape `{"update": {"labels": [{"add": "<label>"}, ...]}}`
   — i.e., Jira's native additive operation, not `fields.labels`.
4. Re-read the ticket's labels and verify that every label in
   `(current ∪ adds)` is present in the post-write set.
5. Exit non-zero with a structured error if any label is missing post-write.

The script SHALL be the only mechanism by which the rendered workflow
writes labels. No agent, no orchestrator prose, and no MCP
`editJiraIssue` call SHALL set `fields.labels` directly.

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

The script SHALL authenticate to Jira using `JIRA_EMAIL` and
`JIRA_API_TOKEN` read from the process environment. No credential SHALL
be stored in `config.json`, in any rendered skill file, or anywhere
inside the project tree. The `jira-config-prompts.md` reference file
SHALL document the env-var requirement and how to obtain a Jira API
token.

#### Scenario: Config.json SHALL NOT carry credentials
- **WHEN** the generated `config.json` is inspected after a fresh `/claudboard-workflow` run
- **THEN** it SHALL NOT contain any key named `token`, `apiToken`, `password`, `auth`, or equivalent
- **AND** the `jira` block SHALL contain only non-secret configuration (`cloudId`, `projectKey`, `urlBase`, `customFields`, `transitions`, `labels`)

#### Scenario: Documentation surfaces the env-var requirement
- **WHEN** `jira-config-prompts.md` is read by `claudboard-workflow`
- **THEN** it SHALL contain a section documenting that `/start-feature` requires `JIRA_EMAIL` and `JIRA_API_TOKEN` env vars at runtime
- **AND** the section SHALL include a brief pointer to how to generate a Jira API token

### Requirement: jira-agent SHALL expose `addLabels` (strictly additive) and SHALL NOT expose `applyLabels`

The jira-agent template SHALL document an `addLabels` action that takes
a `ticketKey` and a `labelsToAdd` array, and SHALL invoke
`scripts/jira-add-labels.sh` with one `--add <label>` argument per
entry in the array. The agent SHALL NOT call `editJiraIssue` with
`fields.labels` under any code path. The previously specified
`applyLabels` action SHALL NOT appear in the template.

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

### Requirement: Orchestrator SHALL pass only the additive label set, never a merged set

The rendered `SKILL.md` SHALL instruct the orchestrator to compute
`labelsToAdd` as the union of the configured `ai` labels and the
resolved area label for the current work area (if non-null). The
orchestrator SHALL NOT read the ticket's existing labels, SHALL NOT
compute a merged set, and SHALL NOT pass the existing labels to
`jira-agent` in any form.

#### Scenario: Orchestrator constructs the additive set from config only
- **WHEN** the orchestrator prepares to call `addLabels` for a backend work area with `ai = ["AI", "AI_CLI"]` and `area.backend = "BE"`
- **THEN** `labelsToAdd` SHALL be `["AI", "AI_CLI", "BE"]`
- **AND** the orchestrator SHALL NOT have called `fetchAndPrepare` for the purpose of reading existing labels
- **AND** the orchestrator SHALL NOT include any existing-label data in the `addLabels` payload

#### Scenario: Area label null is omitted from the additive set
- **WHEN** the resolved area label for the current work is `null` (either `area: null` at top level or the per-area entry is `null`)
- **THEN** `labelsToAdd` SHALL contain only the `ai` labels and no area label

### Requirement: The create action SHALL route labels through addLabels, not additional_fields

The `create` action on jira-agent SHALL invoke `createJiraIssue`
without any `labels` entry in `additional_fields`. Immediately after
ticket creation succeeds, `create` SHALL invoke the `addLabels` flow
(i.e., the same script) with the configured `ai` labels and the
resolved area label for the work type. There SHALL be exactly one
codepath in the rendered skill by which a label reaches a Jira
ticket.

#### Scenario: create does not pass labels to createJiraIssue
- **WHEN** the rendered `agents/jira-agent.md` `create` action is inspected
- **THEN** the documented `createJiraIssue` call SHALL NOT include a `labels` key in `additional_fields`

#### Scenario: create adds labels via the script after ticket creation
- **WHEN** the `create` action runs and `createJiraIssue` returns ticket key `PLAT-200`
- **AND** the configured additive set for the work area is `["AI", "AI_CLI", "BE"]`
- **THEN** the agent SHALL invoke `scripts/jira-add-labels.sh --ticket PLAT-200 --add AI --add AI_CLI --add BE` before emitting its result block

## MODIFIED Requirements

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

### Requirement: Configurable area-label vocabulary

The generated `config.json` SHALL include a `jira.labels` block with
`ai` (always-added label list) and `area` (per-area label map or
`null` for none). The previously specified `preserveExisting` flag
SHALL be removed — preservation is now structural (via the additive
script) and not a configurable behavior. The rendered `feature-workflow`
skill SHALL NOT contain a hardcoded `Backend→BE / Frontend→FE /
DevOps→DevOps / Docs→Docs` map; it SHALL read the area-to-label
mapping from `jira.labels.area` instead. A top-level `area: null`
SHALL mean "no area label is added regardless of work type." A per-area
entry of `null` (e.g., `area: { backend: "BE", devops: null }`) SHALL
mean "skip the area label for that work type." Defaults SHALL be
`ai: ["AI", "AI_CLI"]` and
`area: { backend: "BE", frontend: "FE", devops: "DevOps", docs: "Docs" }`
to preserve current Craftsphere behavior.

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

## REMOVED Requirements

### Requirement: jira-agent SHALL expose an `applyLabels` action and SHALL NOT compute label sets itself

**Reason:** Superseded by the `addLabels` (strictly additive) action,
which delegates the merge to a deterministic shell script. The
`applyLabels` action and the orchestrator-side merge computation are
both removed — they were the surface where label destruction could
re-emerge under LLM step-skip pressure.

**Migration:** Projects that already generated a `feature-workflow/`
skill containing `applyLabels` continue to work as-is. To pick up the
new additive flow, remove the existing `feature-workflow/` directory
and re-run `/claudboard-workflow` per the existing v1 no-upgrade-path
policy.
