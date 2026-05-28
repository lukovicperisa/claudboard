## Why

The feature-workflow SKILL.md template hardcodes 46 `mcp__bosch__*` tool calls for phase lifecycle and gates, but also references `AskUserQuestion` for halt mechanics documentation and clarification autonomy. This creates two problems:

1. **Bosch-sdlc rejects the generated SKILL.md** because its validation does `content.includes('AskUserQuestion')` and treats any mention as an un-instrumented gate pattern. Feature runs cannot start from the UI.

2. **Non-bosch users get a broken SKILL.md** full of `mcp__bosch__*` tool calls that don't exist in their environment. The workflow fails at the first `mcp__bosch__phase_start` call.

The template needs to support both execution contexts from a single generated artifact. The mechanism: a `--gate` flag parsed from the invocation message at runtime, not a generation-time capability flag.

Companion change in bosch-sdlc: `Bosch-sdlc-tool/openspec/changes/gate-mode-flag/`.

## What Changes

### 1. Add "Gate mode" section to SKILL.md.template

Add a new top-level section after "Clarification autonomy" that documents the `--gate` flag:

```
## Gate mode

Parse `--gate=<mode>` from the invocation message. Default: `interactive`.

| Mode          | Gates & lifecycle             | Clarification              |
|---------------|-------------------------------|----------------------------|
| `mcp`         | mcp__bosch__gate_request      | mcp__bosch__clarify_request|
|               | mcp__bosch__phase_start/complete | (structured questions)  |
|               | mcp__bosch__checkpoint_start/complete |                      |
|               | mcp__bosch__agent_start/complete |                          |
| `interactive` | AskUserQuestion / end-of-turn | AskUserQuestion            |

This is a hard contract:
- gate=mcp: NEVER use AskUserQuestion. ALL gates and lifecycle
  signals go through mcp__bosch__* tools.
- gate=interactive: NEVER call mcp__bosch__* tools. They do not exist.
```

### 2. Wrap all mcp__bosch__* calls in gate-mode conditionals

Every `mcp__bosch__*` instruction in the template (46 occurrences across phase_start, phase_complete, gate_request, clarify_request, checkpoint_start, checkpoint_complete, agent_start, agent_complete) gets wrapped:

```
**If gate=mcp:** Call `mcp__bosch__phase_start` with `{ num: 1, title: "..." }`.
**If gate=interactive:** Print phase header and continue.
```

For the gate_request call (spec+plan gate):
```
**If gate=mcp:** Call `mcp__bosch__gate_request` with the spec and plan payload.
**If gate=interactive:** Use AskUserQuestion to present the spec and plan
for approval, or end the turn and wait for user confirmation.
```

### 3. Wrap clarification autonomy in gate-mode conditionals

The existing clarification autonomy section (lines 401-428) becomes:

```
**If gate=mcp:** Call `mcp__bosch__clarify_request` with structured
questions for scope clarification.
**If gate=interactive:** Use `AskUserQuestion` with the autonomy prompt.
If AskUserQuestion is unavailable, print the prompt and end the turn.
```

### 4. Reword halt mechanics documentation

The "Halt mechanics" section (lines 386-397) references `AskUserQuestion` as documentation about how the CLI works. Reword to avoid the literal string in a way that won't confuse gate-mode parsing:

Replace:
> "calls `AskUserQuestion` or ends its turn"

With:
> "calls the harness pause tool or ends its turn"

And add a note:
> "In gate=mcp mode, the harness pause tool is replaced by mcp__bosch__* calls. In gate=interactive mode, the harness pause tool is `AskUserQuestion`."

### 5. Update block-catalog.md

No new capability flag is needed. The `--gate` flag is not a generation-time capability — it is parsed at invocation time from the user's message. Document this distinction in block-catalog.md under a new "Runtime flags" section to differentiate from the 10 v1 capability flags.

## Capabilities

### Modified capabilities

- `feature-workflow-template` — SKILL.md.template supports dual-mode execution via `--gate` runtime flag; all `mcp__bosch__*` calls and `AskUserQuestion` paths are wrapped in gate-mode conditionals; halt mechanics docs reworded to avoid literal pattern strings.
