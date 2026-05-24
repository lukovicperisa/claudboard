## 1. Phase 7b cost comment body (JIRA path)

- [x] 1.1 In `skills/claudboard-workflow/references/feature-workflow.template/SKILL.md.template`, locate the Phase 7b "Step 4: Compose the JIRA comment" block (around lines 2149–2172) and replace the comment-body template with the new fixed flat-markdown shape from `design.md` D1 (heading + bold meta lines + 7 phase bullets + footnote blockquote — no tables, no pricing rates, no model name)
- [x] 1.2 Update the Phase 7b cost-script section to ensure all 7 phase buckets (Phase 1, 2, 3, 4, 5, 6, Orchestrator) are computed and exposed as variables for the new bullet shape; missing phases must yield `$0.00` rather than being skipped
- [x] 1.3 Remove all lines from the Phase 7b section that compose or reference: PR links, "Total time logged" sentence, "Merge order:" line, "Out of scope:" line, per-phase token counts (e.g. `(~489K tokens, 4 agents)`), the pricing-rates table, the model-name footnote, and the "Cost shared equally across N tickets" sentence
- [x] 1.4 Ensure the share line `**This ticket's share:** $<share> (<n> of <N>)` is always rendered including when `<n>` = `<N>` = 1 (no single-ticket conditional)
- [x] 1.5 Format all dollar values with two decimal places (`$0.00`, `$1.08`, `$12.45`)

## 2. Phase 7 cost comment body (T&R path)

- [x] 2.1 In `SKILL.md.template`, locate the `<!-- IF TRACKER_TR -->` Phase 7 block (around line 2225+) and replace the cost-comment body to match the JIRA shape exactly (same heading, same bullets, same footnote)
- [x] 2.2 Remove from the T&R Phase 7 comment any folded-in time data, per-repo PR URLs, merge-order text, or any other non-cost content. The cost comment SHALL be the only comment posted to the T&R ticket by Phase 7
- [x] 2.3 Verify the T&R path uses the identical 7-bullet phase structure (Phase 1–6 + Orchestrator) as the JIRA path so the two backends stay behaviorally identical

## 3. Worklog comment bodies

- [x] 3.1 In `SKILL.md.template`, locate every `addWorklog` invocation across Phase 1 (post-approval), Phase 6, and Phase 7 (both JIRA and T&R branches, single-repo and workspace mode). Replace any composed multi-line / multi-repo aggregated body with one of the fixed terse labels: `"Requirement refinement work"` (Phase 1) or `"Implementation work"` (Phase 6/7)
- [x] 3.2 Remove any orchestrator logic that composes a per-repo PR breakdown or merge-order summary intended for a worklog body (this was the workspace-mode aggregation pattern). Confirm via grep that no remaining template lines reference building a multi-line worklog `comment` value
- [x] 3.3 Verify worklog `timeSpent` handling is unchanged — only the `comment` field is being tightened

## 4. Jira-agent defensive normalizer

- [x] 4.1 In `skills/claudboard-workflow/references/feature-workflow.template/agents/jira-agent.md`, in the `## Action: addComment` section, add a numbered "Step 1: Normalize commentBody" instruction block before the existing MCP tool call. The instruction SHALL specify the two-step substring replacement from design D3: (1) strip every `</n>`, (2) replace every two-character `\n` sequence with a real LF newline. State explicitly that these are exact substring matches, idempotent on clean input, and SHALL be applied in that order
- [x] 4.2 Renumber the existing `addComment` MCP tool call as Step 2 so the normalizer is unambiguously the first operation
- [x] 4.3 In the `## Action: addWorklog` section, add a note immediately under the action heading stating: "The `comment` field SHALL be a fixed terse single-line label — either `Requirement refinement work` or `Implementation work` — never a multi-line, multi-paragraph, or multi-repo aggregated body. The orchestrator is responsible for passing the correct label; the agent SHALL forward it verbatim."

## 5. TR-agent defensive normalizer

- [x] 5.1 In `skills/claudboard-workflow/references/feature-workflow.template/agents/tr-agent.md`, in the `addComment` action section, add the same "Normalize commentBody first" instruction block as jira-agent (identical replacement rules), as the first step before `mcp__bosch-jira-mcp__jira_add_comment`
- [x] 5.2 Update the v1 limitations section in tr-agent (and any completion-report text in `SKILL.md.template`'s claudboard-workflow flow) to say "no worklog (time is not posted to Jira — neither via worklog nor folded into a comment)" instead of "no worklog (time folded into final comment)"

## 6. Plugin version bump

- [x] 6.1 Edit `.claude-plugin/plugin.json` and bump `"version"` from `"3.8.0"` to `"3.8.1"`. This SHALL be the last template/code edit before commit

## 7. Verification

- [x] 7.1 Grep the template tree for the strings `Pricing Rates`, `Sonnet 4.6`, `Total time logged`, `Merge order:`, `Out of scope:` to confirm none remain in any cost-comment composition or worklog composition site. (Other unrelated occurrences elsewhere in the template are fine if any exist.)
- [x] 7.2 Grep for any remaining markdown-table pipe `|` characters in the Phase 7b / Phase 7 cost-comment composition blocks specifically — should be zero pipes in the composed body
- [x] 7.3 Re-read the Phase 7b (JIRA) and Phase 7 (T&R) cost-comment composition blocks end-to-end and verify the rendered body exactly matches the shape in `specs/automated-cost-computation/spec.md` "Post non-blocking cost comment" requirement, with only the placeholder variables differing
- [x] 7.4 Run `openspec validate fix-jira-cost-comment-format --strict` and confirm it passes
