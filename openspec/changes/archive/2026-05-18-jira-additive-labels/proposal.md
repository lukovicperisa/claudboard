## Why

`/start-feature` is still destroying existing Jira labels in real runs, even
after the previous fix (`2026-05-13-jira-agent-project-portability`) moved
the label-merge computation from the Haiku-backed `jira-agent` into the
Sonnet-backed orchestrator. The merge is still a prose, multi-step task —
just running on a more capable model — and Sonnet under context pressure
still occasionally collapses "read → merge → write" into a single
`applyLabels` call that omits the existing labels and overwrites them.

The MCP tool `editJiraIssue` only exposes `fields` (which is a destructive
PUT for the `labels` field). It does NOT expose Jira's native
`update: { labels: [{ add: "..." }] }` operation, which is the only API
that physically cannot destroy existing labels. As long as label writes
go through `fields`, label preservation depends on an LLM correctly
computing a union every time. That's a 5-step prose chain
(fetch → parse → union → call → write), and one skipped step destroys
data on a real ticket the user has been working on.

The user-facing requirement is unambiguous: `AI` and `AI_CLI` (and the
optional area label) MUST be **added on top of** existing labels. No
existing label SHALL ever be removed by the workflow.

The structural fix is to remove the LLM from the label-merge entirely.
The merge becomes a deterministic shell script that reads current labels,
unions them with the additive set, and writes the result back — invoked
by `jira-agent` as a single tool call with no prose computation in
between.

## What Changes

- Replace the `applyLabels` action on `jira-agent` with a new `addLabels`
  action that has strictly additive semantics. The action accepts a
  `ticketKey` and a `labelsToAdd` array; it can never remove or reorder
  existing labels.
- Implement the merge inside a new shell script
  `scripts/jira-add-labels.sh` (rendered into the generated
  `feature-workflow/scripts/` directory). The script calls Jira REST
  directly via `curl`: `GET /rest/api/3/issue/{key}?fields=labels`,
  computes the union locally with `jq`, then `PUT /rest/api/3/issue/{key}`
  with `update: { labels: [{ add: "..." }, ...] }` semantics — physically
  additive, regardless of what the merged set turns out to be. No LLM
  in the merge path.
- Authenticate the script using environment variables read at runtime:
  `JIRA_EMAIL` and `JIRA_API_TOKEN`. No secrets are stored in
  `config.json` or anywhere on disk inside the project. The script fails
  loudly with a clear remediation message if either var is missing.
- Remove the orchestrator-side `mergeLabels` / `resolveAreaLabel`
  pseudo-code from `SKILL.md.template`. The orchestrator no longer
  knows the existing label set — it only knows which additive labels to
  send (AI labels plus the resolved area label for the current work
  area). One codepath, additive verb, no chance of a truncated payload.
- Modify `fetchAndPrepare` to stop returning `existingLabels` — it's no
  longer needed (and its presence created the temptation for the
  orchestrator to do prose merge again).
- Route the `create` (Path B, new ticket) flow through the same
  `addLabels` action immediately after ticket creation, instead of
  passing `labels` to `createJiraIssue.additional_fields`. New tickets
  technically have no labels at creation time, but using the additive
  codepath universally means there is exactly one way labels ever reach
  a ticket — easier to reason about, easier to test, no Path A vs Path B
  divergence to keep in sync.
- Add a post-write verification step inside the script: re-read the
  ticket's labels after the additive write and assert that every label
  in `(existing ∪ labelsToAdd)` is present in the post-write set.
  If verification fails, the script exits non-zero with a structured
  error block listing what went missing, and `jira-agent` surfaces
  the error to the orchestrator instead of silently succeeding.

## Capabilities

### New Capabilities
<!-- None — modifies existing capability only. -->

### Modified Capabilities
- `feature-workflow-generation`: jira-agent gains an additive `addLabels`
  action and loses the `applyLabels` action; the rendered template gains
  a new `scripts/jira-add-labels.sh`; the orchestrator stops computing
  the merge; `fetchAndPrepare` no longer returns `existingLabels`;
  `create` no longer carries labels through `additional_fields`. The
  pre-existing public invariant (existing labels SHALL never be
  destroyed) is preserved but its mechanism is replaced.

## Impact

- **Modified files** (in `skills/claudboard-workflow/references/`):
  - `feature-workflow.template/agents/jira-agent.md` — replace
    `applyLabels` with `addLabels`; remove `existingLabels` from
    `fetchAndPrepare` result; modify `create` to call `addLabels` after
    ticket creation instead of passing labels inline.
  - `feature-workflow.template/SKILL.md.template` — remove
    `mergeLabels` / `resolveAreaLabel` pseudo-code from the Project
    Configuration section; replace `applyLabels` invocations with
    `addLabels`; update Path A and Path B prose to compute only the
    additive set (ai + resolved area label), never a merged set.
  - `feature-workflow.template/scripts/jira-add-labels.sh` — NEW: the
    deterministic merge script (curl + jq, no LLM in the path).
  - `feature-workflow.template/config.json.template` — no schema
    change; the existing `jira.labels.ai` and `jira.labels.area` blocks
    remain. The unused `preserveExisting` flag SHALL be removed (it was
    always `true`; the new design makes it structurally impossible to
    set `false` anyway).
  - `jira-config-prompts.md` — add documentation block explaining that
    `JIRA_EMAIL` and `JIRA_API_TOKEN` env vars are required at
    `/start-feature` runtime, with a one-line remediation if either is
    missing. No new prompts.
- **No source-code changes** to projects being onboarded. Template fix
  benefits future regenerations only.
- **Out of scope**: Updating hand-edited `feature-workflow/` skills
  already deployed in craftsphere.cloud and MEAS repos. The user can
  hand-merge the script and agent changes into those, or remove and
  re-run `/claudboard-workflow` per the existing v1 no-upgrade-path
  policy in CLAUDE.md. Adding an MCP-side `update`-operation passthrough
  to `mcp__atlassian__editJiraIssue` is also out of scope — that would
  be a feature request on the Atlassian MCP server, and the script-based
  approach removes the dependency on it anyway.
- **Backward-compat note**: Projects with a previously generated
  `config.json` containing `jira.labels.preserveExisting: true` will
  continue to work (the field is simply unused by the new script).
  Re-running `/claudboard-workflow` to regenerate from scratch requires
  removing the existing `feature-workflow/` directory first, per the
  existing v1 no-upgrade-path policy.
