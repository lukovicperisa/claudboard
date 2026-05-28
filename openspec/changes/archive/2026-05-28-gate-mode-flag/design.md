## Context

The feature-workflow SKILL.md template (`SKILL.md.template`) hardcodes 46 `mcp__bosch__*` tool calls for phase lifecycle, gates, checkpoints, and agent signals. These tools only exist when the workflow is driven by the bosch-sdlc server via the Agent SDK — they are injected at runtime as an MCP server. When a user runs `/start-feature` from the Claude Code CLI, these tools don't exist and the workflow fails.

Separately, the template contains `AskUserQuestion` references — some as documentation (halt mechanics), some as actual instructions (clarification autonomy). The bosch-sdlc server rejects any SKILL.md that mentions `AskUserQuestion` because it considers them "un-instrumented gate patterns".

The root problem: the template was written as if every user runs under bosch-sdlc orchestration. It needs to support both contexts from a single generated artifact.

The agreed approach: a `--gate=<mode>` runtime flag parsed from the invocation message. `--gate=mcp` forces the MCP path (sent by bosch-sdlc's prompt builder). No flag or `--gate=interactive` uses the vanilla `AskUserQuestion` / end-of-turn path (CLI users).

## Goals / Non-Goals

**Goals:**
- A single generated SKILL.md works correctly in both orchestrated (bosch-sdlc) and standalone (CLI) environments.
- The `--gate` flag is a hard contract: in `mcp` mode the agent never uses `AskUserQuestion`; in `interactive` mode it never calls `mcp__bosch__*`.
- The flag follows the established `--autonomy` pattern already parsed from invocation messages.
- Non-bosch CLI users get a working workflow without broken `mcp__bosch__*` calls.

**Non-Goals:**
- Adding a generation-time capability flag. The `--gate` flag is runtime, not a v1 capability block.
- Changing the `<!-- IF FLAG -->` template rendering system. Gate mode conditionals are prose instructions in the rendered SKILL.md, not build-time blocks.
- Removing `mcp__bosch__*` calls from the template. They stay, wrapped in gate-mode prose conditionals.

## Decisions

### D1. Prose conditionals, not template IF blocks

**Choice:** Gate-mode branching is expressed as prose in the rendered SKILL.md (e.g. "**If gate=mcp:** Call `mcp__bosch__phase_start`... **If gate=interactive:** Print phase header and continue."), not as `<!-- IF ORCHESTRATED -->` template blocks that are stripped at generation time.

**Why:** The `--gate` flag is resolved at invocation time from the user's message, not at generation time from MCP config. A single rendered SKILL.md must contain both paths. The v1 `<!-- IF -->` system strips content at generation time — wrong lifecycle for a runtime flag.

**Trade-off:** The SKILL.md is longer because it carries both paths. This is acceptable — the agent only follows the path matching the parsed flag, and the extra text is bounded (one alternative line per call site, not duplicated sections).

### D2. Call-site grouping strategy

46 `mcp__bosch__` call sites is a lot of conditionals. Rather than wrapping each individually, group by pattern:

| Tool | Count | Strategy |
|------|-------|----------|
| `phase_start` / `phase_complete` | 16 | One-line conditional per call: "**If gate=mcp:** Call `mcp__bosch__phase_start`..." Interactive mode: skip (phases are an orchestrator concept). |
| `agent_start` / `agent_complete` | 18 | Same one-line pattern. Interactive mode: skip. |
| `checkpoint_start` / `checkpoint_complete` | 8 | Same one-line pattern. Interactive mode: skip. |
| `gate_request` | 2 | Multi-line conditional — the interactive alternative is `AskUserQuestion` with spec/plan payload. |
| `clarify_request` | 1 (new, replaces AskUserQuestion) | Multi-line conditional — interactive alternative is the existing `AskUserQuestion` clarification autonomy prompt. |

For `phase_start/complete`, `agent_start/complete`, and `checkpoint_start/complete`, the interactive alternative is simply to omit the call — these are observability signals that only the bosch-sdlc server consumes. The workflow logic (spec writing, plan writing, branching, coding, testing) is identical in both modes.

### D3. Define gate mode section after clarification autonomy

**Choice:** Place the "Gate mode" section immediately before Phase 1 begins, after the clarification autonomy section. The section documents flag parsing, the two modes, and the hard contract. All subsequent instructions reference the parsed `<gateMode>` value.

### D4. Reword halt mechanics documentation

**Choice:** Replace literal `AskUserQuestion` in the halt mechanics documentation (lines 386-397, 783) with the phrase "the harness pause tool", followed by a clarification that in `gate=mcp` mode the pause mechanism is `mcp__bosch__*` calls, and in `gate=interactive` mode it is `AskUserQuestion`.

**Why:** Avoids the literal string that bosch-sdlc's relaxed validation might still flag in future. Also more accurate — the halt mechanism genuinely depends on the execution context.

## File Map

| File | Change |
|------|--------|
| `skills/claudboard-workflow/references/feature-workflow.template/SKILL.md.template` | Add gate mode section; wrap all `mcp__bosch__*` calls in gate=mcp conditionals; wrap `AskUserQuestion` paths in gate=interactive conditionals; reword halt mechanics docs |
| `skills/claudboard-workflow/references/block-catalog.md` | Add "Runtime flags" section documenting `--gate` as distinct from the 10 v1 capability flags |
