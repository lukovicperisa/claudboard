## 1. Halt mechanics callout

- [x] 1.1 In `skills/claudboard-workflow/references/feature-workflow.template/SKILL.md.template`, add a new subsection `## Halt mechanics` immediately after the "Project configuration" / config-validation block and before `## Clarification autonomy`
- [x] 1.2 The subsection states the two-mechanism rule in one paragraph: the CLI pauses ONLY when the orchestrator calls `AskUserQuestion` OR ends the turn (no further tool calls, no further text in the same response). Plain text output does NOT pause the CLI.
- [x] 1.3 The subsection states that every later instruction in the template using the words "prompt", "HALT", "wait for user", "halt and tell the user", or `proceed` MUST be interpreted under this rule.

## 2. Autonomy prompt rewrite

- [x] 2.1 In the `## Clarification autonomy` section, replace the bare "Accept the response and hold..." instruction with: "Use `AskUserQuestion` with options `Accept default (<default>)`, `a — autopilot`, `b — balanced`, `c — guided`, `d — manual`."
- [x] 2.2 Add an "If `AskUserQuestion` is unavailable" fallback paragraph: print the existing one-line prompt verbatim and **end the turn immediately** — do not call another tool, do not summarize, do not continue until the user has replied.
- [x] 2.3 Keep the existing prompt-text block, no-persistence rule, no-per-feature-memory rule, and scope guardrail unchanged.

## 3. HALT definition under autonomy behavior table

- [x] 3.1 Immediately below the autonomy-behavior table (the `autopilot` / `balanced` / `guided` / `manual` row table), insert one short paragraph: "**HALT means: end the turn immediately after printing.** Do not call any further tool until the user replies. The CLI does not pause on plain text — only `AskUserQuestion` or end-of-turn returns control."
- [x] 3.2 In the `manual` row, change "continues only when user types `proceed`" so that `proceed` is reached only after the orchestrator has ended the turn (not while still emitting tool calls).

## 4. Audit existing wait/halt points for consistent wording

- [x] 4.1 Grep the template for `prompt the user`, `halt and tell`, `wait for guidance`, `wait for user`, `Halt immediately` and add the phrase "end the turn" next to each, OR link them to the Halt-mechanics callout from §1.
- [x] 4.2 No semantic changes — wording only.

## 5. Spec delta

- [x] 5.1 Add the new requirement to `openspec/changes/pause-on-prompts/specs/feature-workflow-generation/spec.md` (already drafted with this proposal).

## 6. Migration note for downstream projects

- [x] 6.1 Add a short paragraph to `proposal.md` (or a separate `MIGRATION.md`) telling operators that already-generated `feature-workflow/SKILL.md` files in downstream projects must either be regenerated via `/claudboard-workflow` OR hand-patched at the same two locations (autonomy section + HALT row paragraph).
- [x] 6.2 List the two patch locations with line-range hints so an operator can apply them quickly.
