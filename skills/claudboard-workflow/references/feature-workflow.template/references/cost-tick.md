# Per-Phase Cost Tick

Reference contract for emitting a one-line cost summary at the end of each workflow
phase. The orchestrator loads this file once and follows it at every phase boundary
(phases 1–6). Phase 7 uses a different cost behaviour — do NOT run a tick there.

---

## Invocation slots

Each call site in the orchestrator passes two values into this contract:

| Slot | Description | Example |
|------|-------------|---------|
| `{{SINCE}}` | ISO 8601 UTC timestamp recorded at the **start** of this phase | `2026-05-31T13:06:00Z` |
| `{{LABEL}}` | Human-readable phase label from the vocabulary below | `Spec+Plan` |

---

## Phase-label vocabulary

| Phase | Label |
|-------|-------|
| 1 | `Spec+Plan` |
| 2 | `Branch` |
| 3 | `Implement` |
| 4 | `Commit` |
| 5 | `Review` |
| 6 | `PR` |

---

## Bash invocation

Run two invocations sequentially. Capture stdout; route stderr to `/dev/null`
so a script failure does not disrupt the workflow output.

```bash
# Phase slice cost (from PHASE_N_START to now)
TICK_PHASE_RAW=$(bash .claude/skills/feature-workflow/scripts/compute-cost.sh \
  --format one-line --since {{SINCE}} "$SESSION_JSONL_PATH" 2>/dev/null || true)
TICK_PHASE=$(echo "$TICK_PHASE_RAW" | grep -oE '\$[0-9]+\.[0-9]+' | head -1)

# Full session cost (no --since filter)
TICK_SESSION_RAW=$(bash .claude/skills/feature-workflow/scripts/compute-cost.sh \
  --format one-line "$SESSION_JSONL_PATH" 2>/dev/null || true)
TICK_SESSION=$(echo "$TICK_SESSION_RAW" | grep -oE '\$[0-9]+\.[0-9]+' | head -1)
```

`$SESSION_JSONL_PATH` was recorded once at workflow kickoff (Phase 1 start) and
is held throughout. It resolves to the session JSONL written by Claude Code or
the Claude Agent SDK (via `$CLAUDE_SESSION_JSONL` when running under the SDK).

---

## Output format

After the two invocations, print this line to the user:

```
Phase N ({{LABEL}}): ${TICK_PHASE:-$0.00} │ session ${TICK_SESSION:-$0.00}
```

Replace `N` with the actual phase number. Replace `{{LABEL}}` with the label
from the vocabulary above (e.g., `Spec+Plan`).

---

## SESSION_COST_LOG append rule

After printing, append a line to the `SESSION_COST_LOG` context memo (held
alongside `SPAWN_LOG`). Use this format exactly — Phase 7b reads it by key:

```
SESSION_COST_LOG:
  phase1: $0.42 │ session $0.42
  phase2: $0.03 │ session $0.45
  phase3: $1.18 │ session $1.63
  phase4: $0.07 │ session $1.70
  phase5: $0.21 │ session $1.91
  phase6: $0.04 │ session $1.95
```

Key format: `phaseN` (lowercase, no space). Value format: `$X.XX │ session $Y.YY`.
If `TICK_PHASE` or `TICK_SESSION` resolved to empty (script failed), use `$0.00`
as the placeholder value.

---

## Failure mode

If either script invocation fails (non-zero exit, empty output, or no dollar
amount found in stdout), fall back gracefully:

1. Set `TICK_PHASE=$0.00` and/or `TICK_SESSION=$0.00` for the missing value.
2. Print the output line with a `(cost unavailable)` suffix:
   ```
   Phase N ({{LABEL}}): $0.00 │ session $0.00 (cost unavailable)
   ```
3. Still append the fallback line to `SESSION_COST_LOG` with `$0.00` values.
4. **Do NOT block or halt the workflow.** Continue to the next phase immediately.

The reconciliation step in Phase 7b will surface any missed or zeroed ticks as
an `(unaccounted: $X.XX)` footnote — drift is visible, not silently hidden.

---

## SDK compatibility note

Under the Claude Agent SDK, `SESSION_JSONL_PATH` is resolved at Phase 1 start
from `$CLAUDE_SESSION_JSONL` (set by the SDK) or by constructing the default
path: `~/.claude/projects/$(pwd | sed 's|/|-|g')/$CLAUDE_CODE_SESSION_ID.jsonl`.
The bundled script honours both the env var and the positional argument — no
SDK-specific branch is needed in the orchestrator.
