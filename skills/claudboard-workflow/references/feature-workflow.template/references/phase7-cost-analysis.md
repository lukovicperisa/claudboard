# Phase 7 Cost Analysis

This file contains the cost computation rules and comment template for Phase 7b.
Both TRACKER_JIRA and TRACKER_TR paths use the same steps and template — only the
posting tool and optional time-data prefix differ.

Per-phase costs come from `SESSION_COST_LOG` (accumulated by the orchestrator at
each of phases 1–6). A full-session run of `compute-cost.sh` provides the
authoritative total and enables reconciliation.

---

## Step 1 — Read the pricing reference (for agent-selection context only)

```
Read: .claude/skills/feature-workflow/references/claude-pricing.md
```

This file is used for agent model-selection reasoning in the comment. Cost
computation uses the bundled `compute-cost.sh` script, not this file.

## Step 2 — Run compute-cost.sh for the full session

```bash
bash .claude/skills/feature-workflow/scripts/compute-cost.sh \
  --format one-line "$SESSION_JSONL_PATH" 2>/dev/null || true
```

Extract the dollar amount from the output (e.g., `Cost: $1.95 (...)` → `$1.95`).
Hold it as `ACTUAL_TOTAL`. If the script fails or the output contains no dollar
amount, set `ACTUAL_TOTAL=unavailable`.

## Step 3 — Read SESSION_COST_LOG for per-phase measured costs

Read the `SESSION_COST_LOG` context memo (held alongside `SPAWN_LOG`). Extract
`P1_COST` through `P6_COST` from the `phaseN` entries. For any missing phase,
treat its cost as `$0.00`.

Format: strip the ` │ session $Y.YY` suffix from each entry to isolate the phase
cost. Hold all six values for the comment composition below.

## Step 4 — Reconciliation

```
P_SUM = P1_COST + P2_COST + P3_COST + P4_COST + P5_COST + P6_COST
RECONCILIATION = ACTUAL_TOTAL − P_SUM
```

- If `|RECONCILIATION| > $0.01`: set `UNACCOUNTED_NOTE = "(unaccounted: $|RECONCILIATION|)"`.
- Otherwise: `UNACCOUNTED_NOTE = ""` (no annotation needed).
- Compute `ORCH_COST = max(0, RECONCILIATION)` — the orchestrator's own cost
  (orchestrator turns between phases, plus Phase 7 finalisation).

If `ACTUAL_TOTAL = unavailable`, skip reconciliation: set `ORCH_COST = unavailable`
and use the footnote `(no session log — cost unavailable)` instead of the standard
footnote.

If `SESSION_COST_LOG` has no entries at all (no phase ticks recorded), set
`P1_COST` through `P6_COST` to `$0.00`, set `UNACCOUNTED_NOTE = "(no per-phase
ticks recorded — session total only)"`, and set `ORCH_COST = ACTUAL_TOTAL`.

Determine ticket batch context: `TICKET_N` (this ticket's 1-based index in the batch)
and `TICKET_TOTAL` (total tickets sharing this session). For a single-ticket run use
`TICKET_N = 1`, `TICKET_TOTAL = 1`. Compute `SHARE = ACTUAL_TOTAL / TICKET_TOTAL`
(formatted to two decimal places).

## Step 5 — Compose the comment

```markdown
## AI-Assisted Development — Cost Analysis

**Session total:** $<ACTUAL_TOTAL>
**This ticket's share:** $<SHARE> (<TICKET_N> of <TICKET_TOTAL>)

### Per-phase cost

- Phase 1 — Spec + Plan: $<P1_COST>
- Phase 2 — Branch: $<P2_COST>
- Phase 3 — Implement: $<P3_COST>
- Phase 4 — Commit: $<P4_COST>
- Phase 5 — Review: $<P5_COST>
- Phase 6 — PR: $<P6_COST>
- Orchestrator: $<ORCH_COST>

> Measured per phase from session token log. Phase 7 finalization included in Orchestrator.<UNACCOUNTED_NOTE>
```

Append `UNACCOUNTED_NOTE` directly after the period (no space) when non-empty, e.g.:
> Measured per phase from session token log. Phase 7 finalization included in Orchestrator.(unaccounted: $0.12)

When `SESSION_COST_LOG` had no entries, use:
> (no per-phase ticks recorded — session total only)

When `ACTUAL_TOTAL = unavailable`, use:
> (no session log — cost unavailable)
