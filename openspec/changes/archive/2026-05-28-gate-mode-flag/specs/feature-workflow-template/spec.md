## Gate Mode Flag

### Parsing

The agent parses `--gate=<mode>` from the invocation message at workflow start, alongside the existing `--autonomy=<level>` flag.

- **Default:** `interactive` (when flag is absent or unrecognized)
- **Valid values:** `mcp`, `interactive`
- **Held as:** `<gateMode>` throughout the entire workflow — resolved once, never re-parsed

### Contract

| Mode | Gates | Clarification | Phase/Agent/Checkpoint lifecycle | Halts |
|------|-------|---------------|----------------------------------|-------|
| `mcp` | `mcp__bosch__gate_request` | `mcp__bosch__clarify_request` | `mcp__bosch__phase_start`, `phase_complete`, `agent_start`, `agent_complete`, `checkpoint_start`, `checkpoint_complete` | No halts — MCP tools suspend and resume the agent |
| `interactive` | `AskUserQuestion` / end-of-turn | `AskUserQuestion` | Omitted — no consumer for lifecycle signals | `AskUserQuestion` or end-of-turn |

**Hard rules:**
- In `mcp` mode: NEVER use `AskUserQuestion`. NEVER end a turn to wait for user input.
- In `interactive` mode: NEVER call any `mcp__bosch__*` tool. They do not exist.

---

## Call-Site Wrapping Patterns

### Lifecycle signals (phase, agent, checkpoint)

These are observability signals consumed by the bosch-sdlc server to update the UI. They have no interactive-mode equivalent.

```
**If gate=mcp:** Call `mcp__bosch__phase_start` with `{ num: N, title: "..." }`.
```

When `gate=interactive`, the call is simply omitted. The workflow logic proceeds identically.

### Gate request (spec + plan approval)

The spec+plan gate is the primary human review point. Both modes must pause for approval, but via different mechanisms.

```
**If gate=mcp:** Call `mcp__bosch__gate_request` with:
  { specPath: "...", planPath: "...", specContent: "...", planContent: "..." }
  The tool suspends until the reviewer approves or requests revisions in the browser UI.

**If gate=interactive:** Present the spec and plan summary. Use `AskUserQuestion`
  with options: "Approve", "Revise". If revisions requested, apply feedback and
  re-present. If `AskUserQuestion` unavailable, print summary and end turn —
  wait for user to respond with `approve` or revision feedback.
```

### Clarification (pre-spec questions)

```
**If gate=mcp:** Call `mcp__bosch__clarify_request` with structured questions.
  The tool suspends until the user answers in the browser UI.

**If gate=interactive:** Use `AskUserQuestion` with the clarification questions.
  If `AskUserQuestion` unavailable, print questions and end turn.
```

### Clarification autonomy prompt

The autonomy prompt is itself a gate — it asks the user to choose an autonomy level before work begins.

```
**If gate=mcp:** Call `mcp__bosch__clarify_request` with a single question:
  "Clarification autonomy" with options for each level (autopilot/balanced/guided/manual)
  and the config default pre-selected.

**If gate=interactive:** Use `AskUserQuestion` with the autonomy options.
  Fallback: print the prompt line and end turn.
```

---

## Halt Mechanics Documentation

The "Halt mechanics" section explains how the CLI pauses. The literal string `AskUserQuestion` is replaced with "the harness pause tool" to avoid pattern-matching issues. A clarifying sentence explains that the pause tool varies by gate mode:
- `gate=mcp`: `mcp__bosch__*` calls handle suspension
- `gate=interactive`: `AskUserQuestion` or end-of-turn

Same rewording applies at line 783 (correction loop reference).

---

## Block Catalog Update

A new "Runtime Flags" section is added to `block-catalog.md` at the end, after the 10 v1 capability flags:

```
## Runtime Flags (not capability flags)

Runtime flags are parsed from the invocation message at workflow start.
They are NOT resolved at generation time and do NOT use <!-- IF --> blocks.
Both paths appear in the rendered SKILL.md; the agent follows the one matching
the parsed flag.

### --gate

**Values:** `mcp` (orchestrated), `interactive` (standalone CLI, default)
**Parsed from:** Invocation message, e.g. "Start feature --gate=mcp: ..."
**Effect:** Selects between mcp__bosch__* tools and AskUserQuestion/end-of-turn
  for gates, clarification, and lifecycle signals.
**Set by:** bosch-sdlc prompt builder (always `--gate=mcp`).
  CLI users omit the flag (defaults to `interactive`).
```
