## 1. Add gate mode section to SKILL.md.template

- [x] 1.1 In `skills/claudboard-workflow/references/feature-workflow.template/SKILL.md.template`, add a "Gate mode" section after the clarification autonomy section (after line ~454). The section must:
  - Document parsing `--gate=<mode>` from the invocation message, default `interactive`.
  - Define two modes in a table: `mcp` (all gates/lifecycle via `mcp__bosch__*`, never `AskUserQuestion`) and `interactive` (all gates via `AskUserQuestion` / end-of-turn, never `mcp__bosch__*`).
  - State the hard contract: this is not a preference, it is a binding instruction. Violating the contract (e.g. calling `AskUserQuestion` in `mcp` mode) is an error.
  - Instruct the agent to hold the resolved mode as `<gateMode>` throughout the workflow.

## 2. Reword halt mechanics documentation

- [x] 2.1 In the "Halt mechanics" section (lines 386-397), replace the literal string `AskUserQuestion` with "the harness pause tool". Add a sentence: "In `gate=mcp` mode, pauses are handled by `mcp__bosch__*` lifecycle calls. In `gate=interactive` mode, the pause tool is `AskUserQuestion`."
- [x] 2.2 At line 783, replace `AskUserQuestion or end-of-turn returns control` with `the harness pause tool or end-of-turn returns control` and reference the gate mode section.

## 3. Wrap clarification autonomy in gate-mode conditionals

- [x] 3.1 The existing `AskUserQuestion` instruction for clarification autonomy (lines 407-418) becomes the `gate=interactive` path.
- [x] 3.2 Add a `gate=mcp` alternative before it: "**If gate=mcp:** Call `mcp__bosch__clarify_request` with structured questions for scope clarification. The tool suspends until the user responds in the browser UI."
- [x] 3.3 The fallback block (lines 420-428, "If `AskUserQuestion` is unavailable") stays inside the `gate=interactive` section — it's only relevant when not orchestrated.

## 4. Wrap phase_start / phase_complete calls

- [x] 4.1 For each of the 16 `mcp__bosch__phase_start` and `mcp__bosch__phase_complete` call sites, add a gate-mode conditional. Pattern:
  ```
  **If gate=mcp:** Call `mcp__bosch__phase_start` with `{ num: N, title: "..." }`.
  ```
  No `gate=interactive` alternative — phase signals are observability-only and have no vanilla equivalent. The workflow proceeds without them.

## 5. Wrap agent_start / agent_complete calls

- [x] 5.1 For each of the 18 `mcp__bosch__agent_start` and `mcp__bosch__agent_complete` call sites, add the same gate-mode conditional pattern as task 4. No interactive alternative.

## 6. Wrap checkpoint_start / checkpoint_complete calls

- [x] 6.1 For each of the 8 `mcp__bosch__checkpoint_start` and `mcp__bosch__checkpoint_complete` call sites, add the same gate-mode conditional pattern. No interactive alternative.

## 7. Wrap gate_request calls

- [x] 7.1 At line 1208 (primary gate_request), wrap in a multi-line conditional:
  ```
  **If gate=mcp:** Call `mcp__bosch__gate_request` with: { ... existing payload ... }
  **If gate=interactive:** Present the spec and plan to the user via `AskUserQuestion` for approval. Wait for user to respond with `approve`, `revise`, or specific feedback.
  ```
- [x] 7.2 At line 1276 (re-issue gate_request after revision), apply the same pattern.

## 8. Update block-catalog.md

- [x] 8.1 In `skills/claudboard-workflow/references/block-catalog.md`, add a "Runtime Flags" section at the end, documenting `--gate` as a runtime flag (parsed from invocation message at workflow start) distinct from the 10 v1 capability flags (resolved at generation time from MCP config and analysis report).

## 9. Verify template renders correctly

- [x] 9.1 Read through the full rendered SKILL.md.template to ensure gate-mode conditionals are syntactically consistent and don't break the `<!-- IF -->` capability block nesting.
- [x] 9.2 Verify no remaining bare `mcp__bosch__` calls exist outside a gate-mode conditional.
- [x] 9.3 Verify no remaining bare `AskUserQuestion` instructions exist outside a gate-mode conditional (documentary references in halt mechanics reworded in task 2 are acceptable).
