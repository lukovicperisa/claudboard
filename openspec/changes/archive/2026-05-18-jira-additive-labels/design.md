## Context

The prior change `2026-05-13-jira-agent-project-portability` solved the
"Haiku skips merge steps" problem by moving the label-merge to the Sonnet
orchestrator. That fix held for some time and then regressed — the user
reports labels being destroyed again on a fresh run. The failure mode is
structural, not a bug in any single line of prose: any LLM-driven
"read → parse → union → call sub-agent → write" chain has a non-zero
per-step skip rate, and any skipped step in this chain destroys data.

The five steps in the current flow, with the destruction modes at each:

1. `fetchAndPrepare` (Haiku) reads `fields.labels` and returns
   `existingLabels` in the JSON result block. Failure: omits the field,
   returns `null`, or returns the wrong array (e.g., a different ticket's
   labels picked from a previous tool-result in context).
2. Orchestrator (Sonnet) parses the JSON result block and extracts
   `existingLabels`. Failure: parses other fields but skips this one.
3. Orchestrator runs `mergeLabels(existingLabels, aiLabels, areaLabel)`
   in prose, then constructs the final array. Failure: skips the merge,
   constructs `[aiLabels..., areaLabel]` directly.
4. Orchestrator invokes `applyLabels` with the final array. Failure:
   passes the AI labels only.
5. `jira-agent` (Haiku) writes the array verbatim via `editJiraIssue`.
   Failure: reformats the array, drops items, deduplicates incorrectly.

Each step is ~99% reliable in isolation. The chain is ~95% reliable
end-to-end. For a user running `/start-feature` once a day, 1-in-20
tickets gets its labels destroyed. That is the experience.

The MCP tool `mcp__atlassian__editJiraIssue` only exposes the `fields`
parameter (a destructive write), not Jira's `update` parameter (which
supports `[{ add: "..." }]` and `[{ remove: "..." }]` operations as
true additive/subtractive primitives). So even a perfectly behaving
agent that wants to be additive cannot do so via the MCP tool — it
must always do a full read-modify-write through `fields`. The only way
to expose the native additive primitive is to bypass MCP entirely and
call Jira REST directly via `curl`.

## Goals / Non-Goals

### Goals
- Existing labels on a Jira ticket SHALL NEVER be destroyed by the
  rendered workflow, regardless of LLM behavior.
- The label-write path SHALL contain zero LLM judgment between reading
  the current label set and writing the merged set.
- A label write that does not preserve every prior label SHALL fail
  loudly, not silently — surfaced to the user as an error, not absorbed
  by the workflow.
- One codepath for label writes (Path A existing tickets and Path B
  newly created tickets). No "two ways labels reach a ticket" split.

### Non-Goals
- Adding an MCP-side passthrough for Jira's `update` parameter. That
  would be a feature request on the Atlassian MCP server; the
  script-based approach removes our dependency on it.
- Supporting label *removal* by the workflow. The verb is strictly
  additive in v1. Any later "remove this label" capability is a
  separate, explicit action.
- Auto-migrating already-deployed hand-edited `feature-workflow/`
  skills in craftsphere.cloud / MEAS repos. v1 no-upgrade-path policy
  applies — hand-merge or remove-and-regenerate.

## Decisions

### Decision 1: Move the merge into a shell script, out of all LLMs

**Chosen:** A new script `scripts/jira-add-labels.sh` performs the
merge using `curl` + `jq`. The script reads current labels via the Jira
REST `GET /rest/api/3/issue/{key}?fields=labels`, computes the union
locally with `jq`, then calls `PUT /rest/api/3/issue/{key}` with body
`{"update": {"labels": [{"add": "AI"}, {"add": "AI_CLI"}, ...]}}`. The
`update` operation is Jira's native additive primitive — it cannot
remove existing labels regardless of what the script computes.

**Why:** Prose-based merge has a non-zero per-step skip rate at every
LLM call. A script either runs correctly or fails loudly. The
`update`-operation REST call adds a second layer of safety: even if
the script's local union is wrong somehow, Jira itself will not remove
existing labels because we're not sending a replacement list.

**Alternatives considered:**
- *Verify-after-write in the same agent, prose-bound.* The verify step
  is still prose; an agent that skips the merge will also skip the
  verify. Same surface, just longer.
- *Promote `jira-agent` to Sonnet.* Lowers the per-step skip rate but
  does not eliminate it. The archive's stated lesson — "don't trust
  LLMs with stateful set-math" — still applies.
- *Wait for an MCP-side `update` passthrough.* Out of our control;
  no timeline.

### Decision 2: Strictly additive `addLabels` action, no `applyLabels`

**Chosen:** Rename and re-spec the action as `addLabels(ticketKey,
labelsToAdd[])`. The orchestrator never passes a full merged set —
only the labels it wants added (typically `[AI, AI_CLI]` plus the
resolved area label for the current work area, if any). The agent
invokes the script with `--add <label>` arguments. The verb makes the
contract impossible to misuse: there is no way to pass a list that
would result in removal.

**Why:** `applyLabels` was named after the destructive primitive
underneath (`fields.labels = [...]`), which leaked the destructive
shape into the contract. Every caller was at risk of passing the wrong
list. `addLabels` matches the safe primitive on top.

**Alternatives considered:**
- *Keep `applyLabels` and rely on the script to be additive.* Naming
  matters — the verb shapes how the orchestrator constructs the
  argument. `applyLabels` invites "compute the merged set and pass it
  in"; `addLabels` invites "pass only the additive labels."

### Decision 3: Auth via env vars, not config.json

**Chosen:** The script reads `JIRA_EMAIL` and `JIRA_API_TOKEN` from
the environment at runtime. If either is missing, it exits non-zero
with a one-line remediation message: "Set JIRA_EMAIL and
JIRA_API_TOKEN env vars to enable label updates. See
.claude/skills/feature-workflow/README or jira-config-prompts for
setup details." No secrets in `config.json`, no secrets in
`.claude/`, no secrets in git history.

**Why:** Secrets in repo-tracked or symlinked-meta-repo-tracked config
files are an obvious anti-pattern. Env vars are conventional, simple,
and let each developer manage their own credentials independently.
For Bosch's workspace meta-repo model (where `.claude/` is shared
across the team), env-var auth is the only reasonable option — a
`jira.token` field in `config.json` would either get committed to the
meta-repo (leak) or get gitignored and accidentally lost.

**Alternatives considered:**
- *`jira.token` field in `config.json` pointing at an env var name.*
  Adds a level of indirection without benefit. The script can read
  the canonical env var names directly.
- *Reuse the MCP server's auth token.* Inaccessible from a script
  outside the MCP context. Different auth model entirely.

### Decision 4: Route `create` through `addLabels` for one codepath

**Chosen:** The `create` action on `jira-agent` no longer passes
`labels` through `createJiraIssue.additional_fields`. Immediately
after ticket creation, `create` invokes the same `addLabels` flow
as Path A. This means there is exactly one place in the entire skill
where a label gets written to a ticket.

**Why:** New tickets technically have no labels at creation time, so a
direct write is safe today. But future maintenance changes are easier
when there is one codepath to reason about and test. Also defends
against a race condition that doesn't exist today but would silently
appear later: if the user (or another automation) attaches a label
between `createJiraIssue` and the next workflow step, the additive
codepath preserves it; a direct-write codepath would not.

**Alternatives considered:**
- *Keep `additional_fields.labels` on `create` for parity with Jira's
  one-call shape.* Two codepaths for what is logically one operation.
  Future bug surface for no measurable gain.

### Decision 5: Post-write verification inside the script

**Chosen:** After the additive `PUT`, the script re-reads the ticket's
labels via `GET /rest/api/3/issue/{key}?fields=labels` and asserts
that every label from `(existing ∪ labelsToAdd)` is present. If any
label is missing, the script exits non-zero with a structured error
block including: original labels, requested adds, post-write labels,
the diff. `jira-agent` surfaces this error to the orchestrator instead
of silently succeeding.

**Why:** Belt-and-suspenders. The `update` operation should make
destruction impossible at the Jira API level, but Jira occasionally
mutates labels in unexpected ways (workflow conditions that strip
labels on transition, automations that change them async, etc.).
A verify step catches all of those as a clear error rather than
silent data loss.

**Alternatives considered:**
- *Trust the `update` operation and skip verify.* Probably fine 99.9%
  of the time. The 0.1% is exactly the failure mode we're trying to
  fix — a tiny extra read is worth eliminating it.

## Risks / Trade-offs

- **Risk** — Developers without `JIRA_EMAIL`/`JIRA_API_TOKEN` set will
  hit the env-var error on first `/start-feature` run. → Mitigation:
  the script's error message is the remediation; the
  `jira-config-prompts.md` doc block tells them how to set up tokens
  ahead of time. Acceptable one-time onboarding cost.
- **Risk** — Curl + jq are now runtime dependencies of the rendered
  skill. → Mitigation: both are present on every macOS and Linux
  developer machine in the target audience (Bosch internal teams,
  craftsphere.cloud, MEAS repos). The script does a shebang-line
  availability check and fails with a clear message if either is
  absent.
- **Risk** — The Jira REST endpoint shape (`/rest/api/3/issue/{key}`)
  differs from MCP's abstraction and might drift if Atlassian deprecates
  v3. → Mitigation: v3 has been stable for years; if it changes, the
  script is a single file to update with a clear failure surface.
- **Risk** — Hand-edited `feature-workflow/` skills already in
  craftsphere.cloud and MEAS repos won't benefit from this fix until
  they are manually updated or regenerated. → Mitigation: documented
  in proposal "Out of scope"; the script and agent changes are small
  enough to hand-merge.
- **Trade-off** — Two REST calls (read + write + verify-read = 3 calls)
  per label write, vs. one MCP call today. Latency goes from ~200ms to
  ~600ms. Acceptable for a step that runs once per workflow.

## Migration Plan

- Templates change immediately on merge.
- Already-deployed `feature-workflow/` skills are unaffected until the
  user opts to regenerate (remove the directory, re-run
  `/claudboard-workflow`).
- No data migration. Existing `config.json` files with
  `jira.labels.preserveExisting: true` continue to load — the field is
  unused by the new flow.
