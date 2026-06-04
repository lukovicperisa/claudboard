# Design — claudboard-workflow-non-interactive

## Context

The beta.9 `claudboard-non-interactive` change explicitly deferred
`/claudboard-workflow` ("addressed individually"). This is that follow-up.
The shape mirrors beta.9 closely: identify legitimate prompts vs. busywork,
delete the busywork, tighten the legitimate ones with default-or-detect.

## Decisions

### D1. Silent stubbing over MCP enumeration for ambiguous fields

For fields where auto-detection would require a non-trivial MCP enumeration
or an ambiguity resolution (`jira.projectKey` when multiple Jira projects
are accessible, `azureDevOps.repositoryId` when multiple ADO repos exist),
write `[TODO: FIELD_NAME]` silently rather than prompt.

**Rationale.** The user explicitly chose this in the proposal review on
2026-06-04: "stub with [TODO: JIRA_PROJECT_KEY] silently". The reasoning:
the completion report already lists every stub, so discoverability is
preserved; the alternative (one prompt per ambiguous field) re-introduces
exactly the friction this change is meant to eliminate.

**Alternative considered.** Heuristic enumeration with disambiguation
prompts (`getVisibleJiraProjects` → filter by repo-name → if 1 result use
it, if 0 stub, if >1 prompt). Rejected because it adds MCP-call latency
and the >1 branch still prompts. Deferred for revisit if the stub-rate
turns out to be high in practice (telemetry: count `[TODO:]` stubs per run
across users; revisit if median > 1).

### D2. Documented defaults applied silently, no MCP confirmation

For Jira fields with a widely-correct default (`customfield_10001`,
`customfield_12206`, transitions `In Progress`/`In Review`/`Blocked`, area
labels `BE`/`FE`/`DevOps`/`Docs`, `linkingKeyword = "Closes"`, git fields),
write the default value silently without making an MCP call to confirm it.

**Rationale.** The user chose "Silent always" in the proposal review.
Confirming a default that turns out to be correct adds latency for zero
information; confirming a default that turns out to be wrong still
silently writes the user-overridable value (the user can edit
`config.json` post-run). The net behavioural difference between "silent
default" and "MCP-confirmed default" is one wrong-but-overridable value
per ~100 runs at most, traded against eliminating one MCP call per field
per run.

**Alternative considered.** Run the MCP call to confirm. Rejected: see
above.

### D3. Single Atlassian MCP call for the two trivially-detectable fields

`jira.cloudId` and `jira.urlBase` are returned by the same call:
`mcp__atlassian__getAccessibleAtlassianResources`. The orchestrator MUST
make this call exactly once when `mcp.tracker_jira == true`, populate both
fields, and degrade to stubbing both as `[TODO: JIRA_CLOUD_ID]` /
`[TODO: JIRA_URL_BASE]` on call failure (network error, OAuth not
completed, multi-site response with no clear pick).

**Multi-site disambiguation.** `getAccessibleAtlassianResources` may
return multiple sites if the user has access to several Atlassian
instances. The orchestrator MUST take the first result and proceed
silently. If this is wrong, the user edits `config.json` post-run; the
completion report does NOT need to flag it as a stub (the values are
real, just possibly from the wrong site). This trades correctness for
silence in the multi-site case; rationale: multi-site Atlassian access
is rare, and the user discovers the wrong site immediately on first
`/start-feature` run when the MCP rejects the cloudId.

**Rationale.** This is the one MCP call worth making: it returns two
fields, has no documented default, and is high-signal. Heuristic
fallback (parsing CLAUDE.md or grep'ing the repo for atlassian URLs)
would be too brittle.

### D4. Invocation-hint parser — whole-word case-insensitive, no memory lookup

Parse the user's invocation text (full message that triggered the
skill, including any tokens after `/claudboard-workflow`) with
case-insensitive whole-word matches against fixed token tables:

| Dimension | Hint resolves to | Tokens (whole word, case-insensitive) |
|-----------|------------------|---------------------------------------|
| tracker   | `tracker_jira`   | `jira`, `atlassian`                  |
| tracker   | `tracker_tr`     | `tr`, `t&r`, `track`, `bosch`        |
| repo      | `repo_ado`       | `ado`, `azure`, `devops`             |
| repo      | `repo_github`    | `github`, `gh`                       |

**Whole-word semantics.** Match boundaries on whitespace, punctuation, or
string start/end. `github-actions-test` MUST NOT match `github` (no word
boundary). `for the Github repo` MUST match (whitespace boundary). `T&R`
matches `t&r` token (case-insensitive, treating `&` as part of the token).

**Conflict within a dimension.** If both tracker tokens match (e.g. user
wrote "compare jira vs tr"), suppress the pre-resolution for that
dimension and let the Phase 1d conflict prompt fire. Same for repo.

**No-MCP-hint case.** If the user includes a hint for a dimension where
no MCP is configured at all, the hint is silently ignored (no MCP exists
to resolve toward).

**Rationale.** The user chose "Whole-word case-insensitive match
anywhere". Memory-record lookup was an option but rejected — explicit
invocation hints make user intent observable in the conversation, which
matches how the prompt-suppression precedent in beta.9 works (visible
in `.claude/settings.json`).

### D5. Completion-report stub list is the discoverability contract

Phase 7's completion report MUST contain a section listing every
`[TODO: …]` value in the generated `config.json` with its JSON path,
exactly like beta.9's completion report lists detected MCPs:

```
## Unfilled config values

The following config.json fields were stubbed because they could not be
auto-detected. Edit them before running /start-feature:

  - jira.projectKey            [TODO: JIRA_PROJECT_KEY]
    Path: .claude/skills/feature-workflow/config.json
  - azureDevOps.repositoryId   [TODO: ADO_REPO_ID]
    Path: .claude/skills/feature-workflow/config.json
```

If no stubs were written, the section is omitted (silence = success).

**Rationale.** Silent stubbing is correct only if the unfilled state is
discoverable. The completion report is the natural channel — already
read by every user at end of run.

### D6. Phase 2c file disposition — keep, don't delete

`tracker-config-prompts.md` and `repo-config-prompts.md` contain valuable
prose explaining what each field means and how to find its value (e.g.
"How to find your Atlassian Cloud ID: admin.atlassian.com → ..."). Delete
the orchestrator's load gate but keep the files on disk with a header
clarifying they are documentation:

```
> **Documentation only — no longer loaded at runtime.**
> Since the workflow-non-interactive change (2026-06-04), the
> orchestrator silently stubs missing fields with [TODO: …] instead of
> prompting. This file remains as a reference for users editing
> config.json by hand.
```

**Rationale.** Deleting the files would lose the field documentation
(no other file describes what `jira.customFields.sprint` is). Keeping
them as docs is zero-cost.

### D7. No `--interactive` escape hatch

The original sketch included a `--interactive` flag that would re-enable
the deleted Phase 2c prompts for power users. Rejected as scope creep
during proposal review: nobody asked for it, it doubles the codepath,
and the user has the simpler escape — edit `config.json` post-run.

If a user genuinely wants the old prompts, they can revert to a
pre-change version of the SKILL.md. No flag in v1.

## Risks

### R1. MCP call latency

`getAccessibleAtlassianResources` adds one MCP round-trip per workflow
generation (~100-500ms). Mitigation: the call is made once per run, not
per field. Acceptable; far cheaper than 14 user prompts.

### R2. Wrong default in unusual Jira instances

Defaults `customfield_10001` (Sprint) and `customfield_12206`
(Acceptance Criteria) are the standard Jira Cloud values but can differ
in heavily-customised instances. A wrong default means the generated
`feature-workflow` will silently write to the wrong field. Mitigation:
the user can edit `config.json` post-run; the documented prompts file
explains where to look up the correct values.

If this becomes a frequent issue, future change adds a one-time MCP
confirmation per default value (gated by a simple `--verify-defaults`
flag).

### R3. Invocation-hint false positives

A user message like "I want to start the workflow for the github
project" contains `github` and would resolve the repo dimension even
if the user didn't mean it as a hint. Mitigation: in this specific case
the user almost certainly does have GitHub configured (and only
GitHub), so the resolution is correct anyway. The conflict-prompt only
fires when both repo MCPs are configured, and a hint match in that
context is overwhelmingly intentional.

### R4. Phase 2b sibling inheritance interaction

The `2026-06-03-skip-vacuous-sibling-inheritance` change made Phase 2b
silent when there are no inheritable values. That change is orthogonal
to this one. After both ship, Phase 2b runs after Phase 2a-bis and may
still trigger an inheritance offer when a sibling has explicitly-set
non-default values. This is correct: an existing sibling config IS a
signal the user wants to share, and overriding the auto-fill defaults
with the sibling's values is the user-intended behaviour.

**Ordering decision.** Phase 2a-bis (silent auto-fill) runs BEFORE
Phase 2b (sibling inheritance). If the user accepts inheritance, the
sibling values overwrite the auto-filled values. This is correct
precedence: explicit sibling > documented default > stub.

## Migration

No data migration. Existing generated `feature-workflow/` skills are
unaffected. Users who regenerate with this change in place get the
silent-stub behaviour; users on older skills keep their existing
generated artifacts. The v1 "no upgrade path" caveat for
`feature-workflow/` is unchanged.

## Open Questions

- **Telemetry on stub frequency.** No structured logging exists today.
  Tracking how often `[TODO:]` stubs are written would inform whether to
  promote D1's "ambiguous → stub" rule to "ambiguous → ask once". For v1,
  manual user feedback is the channel.
- **Workspace-mode behaviour.** When generating in workspace mode (single
  meta-repo `feature-workflow/` shared across all sibling repos), the
  `jira.projectKey` heuristic (uppercase repo-name) is meaningless —
  there are N repos. Should the workspace name be the heuristic source?
  Or should workspace mode always stub `projectKey`? Resolved in tasks:
  workspace mode always stubs `projectKey` and `azureDevOps.repositoryId`
  silently — there is no per-repo identifier at the workspace level.
