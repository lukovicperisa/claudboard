## Why

The Phase 7b cost comment posted to JIRA by every workflow run is unreadable: the entire body is rendered as a single `<h2>` element with literal `\n\n` and model-improvised `</n></n>` sequences as plain text, plus markdown table syntax visible verbatim (see all 9 tickets in batch MEAS-8329..8338). Newlines get JSON-escaped to literal `\n` at the orchestrator → jira-agent prompt boundary, and the MCP markdown→ADF converter can't reconstruct block structure from a single line. Worklog calls are unaffected (single-line bodies survive escaping), but they also currently carry multi-paragraph narrative that has no place in a time-tracking record. Net effect: the workflow's tracker side-channel produces noise instead of signal.

## What Changes

- **Phase 7b cost comment** SHALL use a fixed flat-markdown shape (heading + two bold meta lines + 7 phase bullets + footnote blockquote). No tables. No pricing-rates section. No model name hardcoded. Always 7 bullets covering Phase 1–6 + Orchestrator, even if a phase cost $0.00. Share line always rendered (no single-vs-batch conditional).
- **Phase 7b comment** SHALL drop all non-cost content currently embedded: PR links, merge-order line, out-of-scope notes, "Total time logged" sentence, per-phase token counts, pricing rates, model footnote. Cost only.
- **Worklog comments** (Phase 6 and Phase 7 `addWorklog`) SHALL be a terse one-line label only: `"Requirement refinement work"` or `"Implementation work"`. No multi-line, no multi-repo aggregation body.
- **`jira-agent.md` `addComment` action** SHALL normalize defensively before calling the MCP tool: strip literal `</n>` substrings; replace literal `\n` (the 2-character backslash-n sequence) with real newlines in `commentBody`. No-op when input is already clean.
- **Both tracker backends** (JIRA and T&R) SHALL apply the same comment-body shape, worklog-terseness rule, and defensive normalizer. `tr-agent.md` and the `<!-- IF TRACKER_TR -->` Phase 7 path receive parallel edits.
- **Plugin version** bumps from `3.8.0` to `3.8.1` (bugfix).
- **BREAKING (for the generated multi-repo workflow contract)**: the prior multi-repo worklog aggregation requirement (per-repo PR URLs + merge-order summary folded into the Jira worklog body) is removed. PR URLs live in the PR description; merge-order is communicated at PR-review time, not via Jira.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `automated-cost-computation`: cost-comment body shape changes from multi-section (totals + per-phase table + pricing table + footnote) to a fixed flat-markdown bullet shape; pricing-rates section and model name are removed from the rendered comment.
- `tracker-backends`: `addComment` action gains a pre-send normalization requirement; `addWorklog` action gains a "comment body must be a fixed terse label" requirement applicable to both JIRA and T&R backends.
- `multirepo-feature-workflow`: Phase 7 multi-repo worklog aggregation requirement is removed; worklog bodies are uniformly terse regardless of single-repo vs multi-repo mode.

## Impact

- `skills/claudboard-workflow/references/feature-workflow.template/SKILL.md.template`: Phase 7b (JIRA, lines ~2083–2190); Phase 7 (T&R, lines ~2225+); Phase 6 and Phase 7 worklog steps in both branches.
- `skills/claudboard-workflow/references/feature-workflow.template/agents/jira-agent.md`: `addComment` action gets normalizer step; `addWorklog` action gets "short label only" note.
- `skills/claudboard-workflow/references/feature-workflow.template/agents/tr-agent.md`: parallel `addComment` normalizer.
- `.claude-plugin/plugin.json`: version `3.8.0` → `3.8.1`.

Out of scope (explicit non-goals):

- No backfill of the 9 already-broken comments on MEAS-8329..8338. They remain as historical noise.
- No change to ticket descriptions, PR descriptions, or other Atlassian content surfaces.
- No switch of `contentFormat` from `markdown` to `adf`. Markdown stays the wire format; the body is simplified to render correctly through the existing converter.
- No change to the cost computation script itself — only the comment body it feeds into. Phase 5 row will be added even if the script currently emits `$0.00` for it.
