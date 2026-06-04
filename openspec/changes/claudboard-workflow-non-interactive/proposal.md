## Why

`/claudboard-workflow` blocks the orchestrator with ~14 sequential prompts in
Phase 2c (10 Jira fields, 1–2 repo fields, 3 git fields) and 1–2 prompts in
Phase 1d (tracker/repo MCP conflict) every time it runs against a project. The
beta.9 non-interactive work explicitly deferred this skill — "addressed
individually" — and the deferral has now bitten on every workflow regeneration.
Confirmed by user feedback on 2026-06-04: "I ran the claudboard-workflow and
I was again asked about jira stuff, ado stuff and area labels. Didn't we
address that."

Every Phase 2c field is either (a) one MCP call away from being detected
silently, (b) has a documented default that is correct for 95% of users, or
(c) can be safely stubbed as `[TODO: …]` and surfaced in the completion report
for the user to fix post-run. Asking instead of acting on these is friction
for zero value.

The Phase 1d MCP-conflict prompt is legitimate — when both Jira and T&R
(or both ADO and GitHub) MCPs are configured at the same precedence level,
the orchestrator genuinely cannot guess intent. But: the user already has a
zero-cost way to express intent — the invocation text. `/claudboard-workflow
use jira` should silently resolve the tracker dimension before the prompt ever
fires.

## What Changes

- **BREAKING — Phase 2c (per-field prompt loop) is deleted entirely.** The
  loop that loads `tracker-config-prompts.md` / `repo-config-prompts.md` and
  prompts every unresolved `config.json` field is removed from the
  orchestrator. The two reference files remain on disk as documentation but
  are no longer loaded during a run.
- **NEW — Phase 2a-bis (silent auto-fill).** A new phase between current
  Phase 2a (git remote) and Phase 2b (sibling inheritance) silently resolves
  every Jira/repo/git field via: one MCP call for the cheap signals
  (`getAccessibleAtlassianResources` for `jira.cloudId` and `jira.urlBase`),
  heuristic match for `jira.projectKey` (uppercase repo-name when it matches
  `^[A-Z]+$`, else `[TODO: JIRA_PROJECT_KEY]`), and documented defaults for
  the rest (`customfield_10001`, `customfield_12206`, transitions
  `In Progress`/`In Review`/`Blocked`, area labels `BE`/`FE`/`DevOps`/`Docs`,
  `github.linkingKeyword = "Closes"`, `git.branchTypes`/`branchPattern`/
  `ticketRegex`). `azureDevOps.repositoryId` is stubbed as
  `[TODO: ADO_REPO_ID]` silently. Any MCP failure on the one Atlassian call
  degrades silently to a `[TODO: …]` stub for the affected field.
- **NEW — Invocation-hint pre-resolution for Phase 1d.** Before the Phase 1d
  tracker/repo conflict prompt fires, the orchestrator scans the user's
  invocation text (the full message that triggered the skill, including any
  args after `/claudboard-workflow`) for backend hints via case-insensitive
  whole-word match. Hints: tracker → `jira`/`atlassian` resolves to
  `tracker_jira`, `tr`/`t&r`/`track`/`bosch` resolves to `tracker_tr`; repo →
  `ado`/`azure`/`devops` resolves to `repo_ado`, `github`/`gh` resolves to
  `repo_github`. A matched hint suppresses the conflicting backend silently
  for that dimension and records `"chosen via invocation hint"` in the
  detection log. Phase 1d's existing conflict prompt fires only when both
  MCPs are detected at the same precedence level AND no hint was present
  for that dimension.
- **MODIFIED — Completion report surfaces every stub.** Phase 7's completion
  report MUST list every `[TODO: …]` value written to `config.json`, with
  the exact JSON path the user needs to edit, so silent stubbing does not
  hide unfilled state.
- **MODIFIED — `references/tracker-config-prompts.md` and
  `references/repo-config-prompts.md` reclassified as documentation.** The
  Phase 2c load gates are deleted; the files remain so users who want to
  understand what each field means can read them, but the orchestrator
  never loads them at runtime.

## Capabilities

### New Capabilities
- `workflow-invocation-hints`: Case-insensitive whole-word parse of the
  user's invocation text to pre-resolve tracker/repo dimension before any
  conflict prompt fires.

### Modified Capabilities
- `feature-workflow-generation`: Phase 2 collapses from three tiers
  (auto-detect → sibling → prompt) to effectively two tiers (auto-detect-or-
  default → sibling inheritance, where Phase 2a-bis covers both detection
  and default-application). The "User prompted for missing values" scenario
  becomes "Field stubbed with `[TODO: …]` for missing values" — no prompt.
- `mcp-detection`: The "Precedence-prompt when two MCPs in a dimension are
  detected" requirement gains a pre-resolution step that consults the
  invocation text first and only prompts when no hint is present.

## Impact

**Affected files:**
- `skills/claudboard-workflow/SKILL.md` — Phase 2c section deleted; Phase 2a
  expanded with the auto-fill sub-steps; Phase 1d gains the invocation-hint
  pre-resolution step before its conflict prompt; Phase 7 completion report
  gains the stub-list section.
- `skills/claudboard-workflow/references/tracker-config-prompts.md` — header
  re-marked as "documentation-only — orchestrator no longer loads at
  runtime" (file kept for human reference; load gate removed from SKILL.md).
- `skills/claudboard-workflow/references/repo-config-prompts.md` — same
  treatment.
- `openspec/specs/feature-workflow-generation/spec.md` — delta updates per
  the spec rewrite below: "User prompted for missing values" scenario
  removed; new "Field stubbed silently" scenario added; "Sibling inheritance
  offer" wording unchanged (already covered by the
  `2026-06-03-skip-vacuous-sibling-inheritance` change).
- `openspec/specs/mcp-detection/spec.md` — delta adds the invocation-hint
  pre-resolution scenarios.

**User-facing behaviour changes:**
- A `/claudboard-workflow` run in the happy path (one tracker MCP, one repo
  MCP, repo-name matches `^[A-Z]+$`) produces **zero** mid-flow prompts.
- A run with both tracker MCPs configured AND no invocation hint produces
  **one** prompt (the Phase 1d conflict prompt). With a hint, zero.
- A run where `jira.projectKey` cannot be guessed (repo-name doesn't match
  `^[A-Z]+$`, e.g. `my-cool-service`) silently writes
  `"projectKey": "[TODO: JIRA_PROJECT_KEY]"` and the completion report lists
  it. The generated `feature-workflow` will not work for that project until
  the user fixes the stub — discoverable via the completion report.
- Users who relied on the old prompts to learn what each field means can
  still read `references/tracker-config-prompts.md` and
  `references/repo-config-prompts.md` — they are documentation now.

**Backwards compatibility:**
- The removed prompts are interactive only; no on-disk artifact format
  changes. Existing `config.json` files and generated `feature-workflow/`
  skills remain valid (the `feature-workflow/` SKILL.md upgrade path is
  unchanged — still "remove the directory and re-run" per v1 caveat).
- The Phase 1d invocation-hint parser is additive — invocations with no
  hint preserve the existing conflict-prompt behaviour exactly.

**Out of scope:**
- `/generate`, `/refresh`, `/techdebt` non-interactivity — still individual
  changes per the original deferral.
- Auto-detection of `jira.projectKey` via Jira MCP project enumeration
  (`getVisibleJiraProjects` filtered by repo-name match) — deferred per the
  decision to "stub silently on ambiguity"; revisit if the stub-rate proves
  high in practice.
- Persistent per-user backend preference (e.g. memory record "always
  prefers Jira") — explicitly rejected in favour of explicit invocation
  hints.
- Auto-detection of `azureDevOps.repositoryId` via ADO MCP — silent stub
  is the chosen behaviour; revisit only if the stub is consistently the
  only thing blocking happy-path runs.
