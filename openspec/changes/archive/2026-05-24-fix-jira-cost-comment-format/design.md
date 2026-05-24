## Context

Phase 7b of the generated `feature-workflow` skill posts an "AI-Assisted Development — Cost Analysis" comment to the workflow's tracker ticket (JIRA via `mcp__atlassian__addCommentToJiraIssue`, or T&R via `mcp__bosch-jira-mcp__jira_add_comment`). The current rendered output on Jira is a single `<h2>` element containing literal `\n\n` characters, fake `</n></n>` tags, and raw markdown table syntax — see all 9 tickets in batch MEAS-8329..8338 from the 2026-05-22 run.

Root cause: the orchestrator composes a multi-section markdown body (heading + bold lines + two tables + blockquote) and embeds it inside a JSON object literal in the `addComment` agent's INPUT CONTEXT. The JSON literal lives in the agent prompt as text. Real newlines in the body get JSON-escaped to the two-character sequence `\n` so the JSON stays valid. The agent then passes the value verbatim to the MCP tool with `contentFormat: "markdown"`. The MCP markdown→ADF converter sees one line of text, parses inline marks (`**bold**`, `[link]()`) correctly, but cannot reconstruct block-level structure — it greedily extends the first `##` heading to swallow the entire blob. The `</n></n>` artifact appears to be a model improvisation: when the body is large, the model writing the JSON literal occasionally invents pseudo-newline tags when its escape logic strains.

Worklog calls (`addWorklog` action) are unaffected: their `comment` field is a single-line label so JSON escaping is a no-op. However, the orchestrator currently composes a multi-paragraph aggregated body for the worklog comment in workspace mode (per the existing `multirepo-feature-workflow` requirement), which is wrong on a second axis — Jira surfaces worklogs in a tabular log view where long bodies are noise.

## Goals / Non-Goals

**Goals:**

- Phase 7b cost comments render as readable structured content on Jira, every workflow run, every ticket.
- Comment shape is fixed: only dollar values vary across runs.
- Worklog comments are terse one-liners suitable for Jira's worklog log view.
- The fix is robust against the model occasionally improvising fake newline sequences.
- JIRA and T&R backends behave identically.

**Non-Goals:**

- Backfilling or editing the 9 already-broken comments on MEAS-8329..8338.
- Switching `contentFormat` from `markdown` to `adf`. Markdown stays the wire format.
- Reworking the cost computation script (`python3 - <<PYEOF ...`). Only the comment body that consumes its output changes.
- Adding any new tracker actions or MCP tools.
- Adding PR links, merge-order text, or time-logged data to *any* Jira comment or worklog. They live in the PR description.

## Decisions

### D1. Simplify the comment body to a fixed flat-markdown shape; drop tables entirely

The Phase 7b comment becomes:

```markdown
## AI-Assisted Development — Cost Analysis

**Session total:** $<total>
**This ticket's share:** $<share> (<n> of <N>)

### Per-phase cost

- Phase 1 — Spec + Plan: $<p1>
- Phase 2 — Branch: $<p2>
- Phase 3 — Implement: $<p3>
- Phase 4 — Commit: $<p4>
- Phase 5 — Review: $<p5>
- Phase 6 — PR: $<p6>
- Orchestrator: $<orch>

> Estimated from session token log. Phase 7 finalization not included.
```

Always 7 bullets (Phase 1–6 + Orchestrator), even when a phase cost $0.00. Share line always rendered (`(1 of 1)` in single-ticket mode is mildly redundant but keeps the shape truly fixed).

**Alternatives considered:**

- **Compose ADF JSON directly and use `contentFormat: "adf"`.** Round-trip safe but verbose; locks the comment shape into hand-written ADF templates that are awkward to evolve. Rejected — markdown stays the source of truth.
- **Write the body to a temp file and have jira-agent read it.** Fixes the JSON-escape boundary generically but is heavyweight for a single call site. Rejected as primary fix; partially addressed via D3 instead.
- **Keep the per-agent breakdown table but drop nothing else.** Tables specifically are the most fragile element when newlines collapse, and the per-agent rows are not useful to ticket readers. Rejected.

### D2. Strip everything non-cost from the Phase 7b comment

Removed from the body: PR links, merge-order line, out-of-scope notes, "Total time logged" sentence, per-phase token counts (e.g. `(~489K tokens, 4 agents)`), pricing rates section, model-name footnote. The comment is cost only; PR-side context lives in the PR description.

**Rationale:** the user requested a single fixed-shape cost comment per workflow run, nothing else. Mixing cost + release notes + scope notes is what produced the bloated body that triggered the model improvisation in the first place.

### D3. Defensive normalizer in `jira-agent.md` `addComment` action

Before calling `mcp__atlassian__addCommentToJiraIssue`, the agent normalizes `commentBody`:

1. Replace every literal `</n>` substring with the empty string.
2. Replace every literal `\n` (the two-character backslash-n sequence) with a real `
` newline.

This is a string replacement, not regex parsing — exact-substring matching only. Operations are idempotent: no-op when input is already clean. Order matters: `</n>` strip first (in case the model wrote `\n</n>` adjacency), then `\n` decode.

**Alternatives considered:**

- **Only fix the body shape, no normalizer.** Most direct, but doesn't protect against a future regression where some other Phase composes a longer multi-line body. Rejected — the `</n></n>` artifact in MEAS-8329 proves the model improvises under stress.
- **Stricter regex-based parser to detect "this might be JSON-escaped" and full-decode.** Too clever; risks misinterpreting legitimate backslash-n sequences in code blocks. Rejected.

### D4. Mirror in `tr-agent.md`

The T&R variant gets the same comment-body shape (Phase 7 in `<!-- IF TRACKER_TR -->` branch), the same terse-worklog rule (in T&R's case the orchestrator already folds time into the comment per `tracker-backends` v1 limitations — so we simply ensure the cost comment is the *only* comment posted, no separate time/PR comment), and the same defensive normalizer in `tr-agent.md` `addComment` action. JIRA and T&R must not diverge on the cost-comment shape.

### D5. Worklog comments collapse to a fixed terse label

The `addWorklog` action's `comment` field SHALL be one of: `"Requirement refinement work"` (Phase 1 worklog) or `"Implementation work"` (Phase 6/7 worklog). This applies in both single-repo and workspace (multi-repo) modes. The pre-existing `multirepo-feature-workflow` requirement that mandated an aggregated multi-repo worklog body (with per-repo PR URLs and merge-order summary) is REMOVED — PR URLs live in PR descriptions, merge-order is a PR-review concern.

### D6. Version bump policy

`.claude-plugin/plugin.json` bumps from `3.8.0` to `3.8.1`. This is a bugfix-only release: the comment body the user *intended* to post is now correctly rendered. No new capabilities, no behavior changes outside the rendered comment shape.

## Risks / Trade-offs

- **[Risk]** The fixed bullet list always includes Phase 5 even if the workflow has not actually been instrumented for Phase 5 cost tracking in SPAWN_LOG. → **Mitigation:** the cost script's per-phase aggregation treats missing phase entries as zero spawns (existing `automated-cost-computation` requirement covers this); the bullet renders `$0.00` cleanly.
- **[Risk]** Removing the per-agent breakdown reduces operator visibility into where session cost goes. → **Mitigation:** the operator runs the session — they already have the token log locally and `/cost` available. The Jira comment serves teammates reading the ticket; per-phase totals are the right granularity for them.
- **[Risk]** The defensive normalizer could in theory corrupt a legitimate `\n` literal inside a code block that the comment body actually wants to preserve. → **Mitigation:** Phase 7b never composes a comment that contains a code block with literal backslash-n; the new fixed shape contains no code blocks at all. If future use cases require literal backslash-n preservation, the normalizer can be made code-fence-aware then.
- **[Trade-off]** Dropping the merge-order summary from Jira means a teammate reading the ticket in isolation won't see merge guidance — they have to click into the PRs. → **Accepted:** PRs are the canonical home for merge-order context; duplicating it on Jira invites drift.
- **[Trade-off]** `(1 of 1)` in single-ticket mode is mildly redundant. → **Accepted:** keeping the shape truly fixed simplifies template authoring and reader expectations.

## Migration Plan

1. Edit the four files listed in the proposal Impact section.
2. Bump `.claude-plugin/plugin.json` to `3.8.1` as the final edit before committing.
3. No downstream migration: the next workflow run that hits Phase 7b on any project using the regenerated template will post the new shape. Projects with hand-edited `feature-workflow/` skills (Bosch craftsphere, MEAS workspace) are *not* auto-updated — that's the standing v1 "no upgrade path" policy. To pick up the fix manually, those projects can copy the Phase 7b block and the jira-agent normalizer step from the template into their hand-edited copies.
4. The 9 broken comments on MEAS-8329..8338 stay as-is per explicit scope decision.

**Rollback:** revert the four edits and the version bump in one commit. No state or migration to undo.

## Open Questions

None. Shape, scope, normalizer behavior, version bump policy, and out-of-scope items were all settled before this proposal was drafted.
