## Context

The `per-run-cost-reporting` change (just shipped) gave claudboard a canonical cost-measurement primitive: `compute-cost.sh` (requestId-dedup, slice filtering, versioned `pricing.md`) plus a Stop hook that emits cost lines after `/analyse`, `/generate`, `/refresh`, `/techdebt`. The hook is gated on the leading slash command in the last user message — fine for single-stop sessions, ambiguous for feature-workflow which crosses many phase boundaries inside one session.

The deferred follow-up named in v1's proposal: "Feature-workflow per-phase cost emission (the workflow has multiple phase boundaries per session; hook gating becomes ambiguous)." and "Live cost-estimation agent that projects cost of prospective actions before they run."

The user has now selected the slice they want first (see exploration transcript): **live per-phase tally, no history, no pre-flight projection**, with an **SDK-portable** implementation. They explicitly opted into reconciliation in Phase 7b because it's "free" given the ticks already accumulate a log.

The current Phase 7b is doing this badly: it embeds its own Python (no `requestId` dedup, so it over-counts 3-4× any time an assistant message has multiple content blocks — common with tool_use), uses a stale Opus price row (the per-run-cost-reporting change patched the spec but not this template's inline copy), and produces per-phase "estimates" by multiplying `SPAWN_LOG × profile` rather than reading the real slice cost from the JSONL.

## Goals / Non-Goals

**Goals:**
- The user sees a one-line cost summary at the end of each of phases 1-6, including this phase's cost and the running session total.
- Phase 7b's tracker comment shows **measured** per-phase costs (sourced from the per-phase ticks) rather than spawn-count × profile estimates.
- Phase 7b reconciles `ACTUAL_TOTAL` (one final `compute-cost.sh` run over the whole session) against `Σ(per-phase ticks)`; any drift over $0.01 is surfaced as `(unaccounted: $X.XX)` in the comment footnote.
- Single source of truth for cost computation: the bundled `compute-cost.sh`. No inline jq or inline Python anywhere in the template.
- Works identically when the workflow runs under the Claude Agent SDK as under Claude Code — same JSONL location, same Bash tool, same script invocation.
- Zero additional model-side API cost per tick (no spawned agent; one bash call per phase end).

**Non-Goals:**
- No pre-flight projection ("this feature will cost ~$X"). Deferred to a v2 change once we have a cost-history file to project from.
- No mid-flight steering ("over budget — downgrade impl to Sonnet?"). Would require a real spawned agent and a budget primitive we don't yet have.
- No `/cost` on-demand slash command. Out of scope for this change.
- No replacement of the claudboard Stop hook (`stop-hook.sh`) — that path remains the right answer for `/analyse`, `/generate`, etc. Feature-workflow is the path that needs orchestrator-driven ticks instead.
- No consolidation of `claude-pricing.md` (agent profile table for reasoning) with `pricing.md` (exact computation table). Both files coexist in the generated workflow; the cost computation reads only `pricing.md` (via the bundled script). A future refactor can merge them.
- No auto-upgrade for previously-generated feature-workflow skills. Users who want the new behaviour delete and regenerate (consistent with the v1 caveat already documented in `claudboard-workflow`).
- No changes to the hand-edited Bosch copies (`craftsphere.cloud`, MEAS repos). The template is the source of generated skills; hand-edited copies are deliberately out of scope.

## Decisions

### Decision 1: Deterministic bash tick in the orchestrator, not a spawned agent

The deferred-features memory called this a "cost-estimation agent". After exploring (transcript above), the user agreed: the value here is **visibility**, not reasoning. Spawning a Haiku tick agent at each phase boundary would cost ~$0.05 × 6 = ~$0.30 per workflow run with no compensating capability that bash can't deliver. Bash is free, instant, deterministic, and trivially portable to the SDK.

**Alternative considered:** A Haiku sub-agent invoked at each phase boundary that reads the JSONL slice, computes cost, optionally judges "is this expensive for this kind of work", and posts a one-liner. Rejected because (a) the cost-judgement value requires a comparison baseline (cost history) which is explicitly deferred, and (b) bash gives the same number for $0.

**Alternative considered:** Extend the claudboard Stop hook to also fire on feature-workflow phase boundaries. Rejected for the same reason v1 deferred it — the hook fires on session Stop, not on the orchestrator's internal phase boundaries. There is no harness signal for "phase N just ended". The orchestrator is the only thing that knows.

### Decision 2: Bundle `compute-cost.sh` and `pricing.md` into the generated workflow

The script lives in `skills/claudboard/scripts/compute-cost.sh` (claudboard repo). Generated workflows in other projects have no path back to that file at runtime. Two options:

1. **Bundle (chosen)**: the generator copies both files verbatim into the generated workflow's `scripts/` and `references/`. The generated workflow is self-contained; the source of truth stays in the claudboard repo. Pattern matches today's verbatim copies (`claude-pricing.md`, `ticket-description-template.md`).
2. **Reference an external path**: not viable — generated workflows ship to projects that don't have claudboard installed.
3. **Embed the logic inline in the template**: rejected because it's exactly the problem we're fixing (the current Phase 7b's inline Python).

The bundle is the materialisation point. Same drift risk as any other verbatim copy (edit upstream → re-run generator). Documented.

### Decision 3: `SESSION_COST_LOG` is an in-context memo, not a file

The per-phase ticks emit to the user **and** append a line to a `SESSION_COST_LOG` block the orchestrator holds in its context, alongside the existing `SPAWN_LOG`. Phase 7b reads from context, no file IO needed.

Format:
```
SESSION_COST_LOG:
  phase1: $0.42 │ session $0.42
  phase2: $0.03 │ session $0.45
  phase3: $1.18 │ session $1.63
  ...
```

**Alternative considered:** Write a file (`.claude/skills/feature-workflow/state/cost-log-<session>.txt`). Rejected because (a) it adds a new state directory and file lifecycle, (b) the log is single-session-scoped and dies with the session anyway, (c) cross-process recovery isn't a use case (the orchestrator is the only reader and it's in the same process), (d) it's consistent with how SPAWN_LOG already works (in-context).

### Decision 4: One referenced file (`cost-tick.md`), six call-sites in the orchestrator

We just slimmed the orchestrator template (`slim-feature-workflow-orchestrator`). Adding six full tick blocks would re-fatten it by ~30 lines. Pattern from the slim work: state the contract once in a referenced file, use a shorthand at each call site.

`cost-tick.md` (new template reference) contains:
- The bash invocation template (with `PHASE_N_START` and `PHASE_N_LABEL` slots).
- The expected output format (`Phase N (<name>): $X.XX │ session $Y.YY`).
- The `SESSION_COST_LOG` append rule.

Each of phases 1-6 in the orchestrator gets a one-line shorthand at the end:
```
### N-end. Cost tick → see references/cost-tick.md (label="<phase-name>", since=PHASE_N_START)
```

Phase 1 also records `SESSION_JSONL_PATH` and `PHASE_1_START` at kickoff (the JSONL path recording is already a requirement — this just makes it explicit; the timestamp is new). Each subsequent phase records its `PHASE_N_START` immediately after the previous phase's tick.

### Decision 5: Reconciliation in Phase 7b is belt-and-suspenders, not the source of truth

The per-phase ticks are the source of truth for per-phase cost rows in the Phase 7b tracker comment. The reconciliation step runs `compute-cost.sh` **once** over the whole session to get `ACTUAL_TOTAL`, then compares:

```
RECONCILIATION = ACTUAL_TOTAL − Σ(SESSION_COST_LOG phase totals)
```

Threshold: `|RECONCILIATION| > $0.01` triggers an `(unaccounted: $X.XX)` line in the comment footnote. Under threshold, no annotation (clean comment).

This catches:
- A missed tick (the orchestrator skipped the instruction for some phase).
- Phase 7 finalization cost itself (the final `compute-cost.sh` runs *during* Phase 7 so 7's cost is partially unaccounted by construction — expected, surfaced as small positive drift).
- Any drift between slice arithmetic (`--since` time-windowed sums) and full-session sum.

The user asked for this only because it's free given the log already exists. It is.

### Decision 6: Per-phase rows in the tracker comment switch from estimates to measured costs

Today's `phase7-cost-analysis.md` computes per-phase rows as `Σ(spawn count × mid-range profile)` across agents in that phase. That's an estimate built from `SPAWN_LOG × claude-pricing.md profiles`. Now that we have measured per-phase costs in `SESSION_COST_LOG`, the per-phase rows in the tracker comment come from the log. The agent-profile multiplication is removed for cost purposes (the profile table stays in `claude-pricing.md` because the orchestrator still uses it for agent model-selection reasoning).

Side effect: the "orchestrator residual" bullet that today carries `actual_total − Σ(phase estimates)` becomes `actual_total − Σ(phase measured)` — same arithmetic, but the residual now only contains genuine orchestrator-side cost (orchestrator turns between phases) rather than estimation error.

### Decision 7: Tick output goes to stdout (visible to user) AND to context memo

The bash invocation prints the formatted line. The orchestrator template instructs the model to also append the parsed values to `SESSION_COST_LOG` in context. Two redundant paths to the same information — one for the human, one for Phase 7b's machine-reader.

## Risks / Trade-offs

- **Orchestrator forgets to tick** → reconciliation in 7b surfaces the gap as `(unaccounted: $X.XX)`; the comment is still posted, the workflow doesn't fail. Operator sees the drift and can investigate. Acceptable for v1.

- **Two pricing tables in the generated workflow** (`claude-pricing.md` for profiles, `pricing.md` for exact computation) → some risk of them diverging if Anthropic changes prices and only one is updated. Mitigation: claude-pricing.md is documentation for agent-selection reasoning (round numbers, no `effective_from`); `pricing.md` is the canonical source consumed by the script. Future refactor can consolidate.

- **Bundle drift** (script in `claudboard/scripts/` changes, generated workflows ship a stale copy) → same risk class as existing verbatim copies. Mitigation: documented as part of the regeneration story; the v1 caveat ("no upgrade path") already covers it.

- **Slice arithmetic divergence** (sums of `--since A` + `--since B` slices ≠ sum over `--since 0`) → in practice, the script processes line-by-line filtered by timestamp; the slice math is associative as long as timestamps are monotonic and no lines straddle the boundary. The reconciliation catches any anomaly.

- **JSONL not written yet at tick time** (the harness writes asynchronously) → the tick runs at end-of-phase, after the orchestrator has already received tool results, so the relevant JSONL lines exist. If a tick reads a fractionally-late line, the next tick or the 7b reconciliation picks it up. No data loss.

- **SDK custom session IDs** → already handled by the script (`$CLAUDE_SESSION_JSONL` env var or positional arg). Phase 1 records the path; subsequent ticks use the recorded value. No SDK-specific branch needed.

- **User runs only half the workflow** (`--ticket-only-mode` or aborts at a gate) → ticks fired before the abort are still printed and still in `SESSION_COST_LOG`; 7b never runs so no reconciliation. The user has live visibility up to the abort point — same value as a complete run, no regression.

## Open Questions

- **Tick label vocabulary**: should `cost-tick.md` define the phase labels (`Spec+Plan`, `Branch`, `Implement`, `Commit`, `Review`, `PR`) inline or pull them from the orchestrator's existing phase headings? Default to inline in `cost-tick.md` for self-containment; the orchestrator passes the label as a parameter at each call site. Resolved during implementation.

- **Should the tick be optional**? Conceivably some teams want zero cost annotation. Out of scope for v1; if it comes up, a `cost.tickMode = "off" | "live" | "final-only"` config knob lives in a future change. v1 is always-on.

- **Reconciliation message wording**: `(unaccounted: $X.XX)` is one option. Alternatives: `(Phase 7 finalization + drift: $X.XX)`, `(measured−ticks: $X.XX)`. Defer to implementation taste; the spec just requires the annotation, not the exact words.
