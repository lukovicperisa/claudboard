## Why

Today the generated `feature-workflow` skill only reports cost **once**, at the end of Phase 7b, by running an inline Python script that (a) does not dedup by `requestId` (over-counts 3-4×), (b) carries stale Opus 4.7 prices that the `per-run-cost-reporting` change just corrected in `claudboard/references/pricing.md` but not here, and (c) shows the user nothing while the workflow runs — they only see the bill after the work is done.

The user explicitly flagged "live cost availability inside workflows" as a deferred-but-high-priority capability (see `cost-visibility-priority` memory): the moment the v1 measurement surfaced `$8.17` for a single `/analyse` run, post-hoc reporting stopped being enough. They want to see cost accumulate phase-by-phase so they can reason about which phases are expensive and stop a runaway feature mid-stream.

The v1 deferral note named the obstacle: "the workflow has multiple phase boundaries per session; hook gating becomes ambiguous". This proposal sidesteps that by having the orchestrator itself — which already knows the phase boundary it just crossed — invoke the shared `compute-cost.sh` deterministically in bash, with no extra model spawn.

## What Changes

- **NEW** `skills/claudboard-workflow/references/feature-workflow.template/scripts/compute-cost.sh` — verbatim copy of the canonical script from `skills/claudboard/scripts/compute-cost.sh`, bundled into the template so generated workflows ship with it.
- **NEW** `skills/claudboard-workflow/references/feature-workflow.template/references/cost-tick.md` — the per-phase tick contract: how to invoke the bundled script with a `--since PHASE_N_START` slice, the output format (`Phase N (<name>): $X.XX │ session $Y.YY`), and the append-to-`SESSION_COST_LOG` rule. Referenced once from the orchestrator template; called from each of phases 1-6.
- **MODIFIED** `skills/claudboard-workflow/references/feature-workflow.template/SKILL.md.template` — at the end of each of phases 1, 2, 3, 4, 5, 6 the orchestrator records `PHASE_N_END` and runs the cost tick shorthand. Phase 1 records `SESSION_JSONL_PATH` (already required) and `PHASE_1_START` at kickoff before any directory change.
- **MODIFIED** `skills/claudboard-workflow/references/feature-workflow.template/references/phase7-cost-analysis.md` — drops the inline Python; instead reads the accumulated `SESSION_COST_LOG`, then runs `compute-cost.sh` **once** for the full session to get `ACTUAL_TOTAL` and computes `RECONCILIATION = ACTUAL_TOTAL − Σ(per-phase ticks)`. If `|RECONCILIATION| > $0.01`, appends `(unaccounted: $X.XX)` to the comment footnote. The per-agent profile multiplication (SPAWN_LOG × profile) is removed for cost purposes; the per-phase rows in the tracker comment now show the **measured** per-phase costs from the log instead of estimates.
- **MODIFIED** `skills/claudboard-workflow/SKILL.md` (generator) — Phase 4 (asset materialisation) copies `compute-cost.sh` from `claudboard/scripts/` to the generated workflow's `scripts/` directory, and copies `pricing.md` from `claudboard/references/` to the generated workflow's `references/` directory, alongside the existing verbatim copies of `claude-pricing.md` and `ticket-description-template.md`. The existing `claude-pricing.md` is retained for the agent profile section but the cost calculation now sources prices from the bundled `pricing.md` exclusively (single source of truth).
- **No change** to `skills/claudboard/scripts/compute-cost.sh` itself — it stays the source of truth in the claudboard repo; the generator copies it.
- **No change** to claudboard's own Stop hook (`stop-hook.sh`) or its gating for `/analyse`, `/generate`, `/refresh`, `/techdebt`. Feature-workflow does not use the Stop hook; this change is orchestrator-driven, so the gating-ambiguity blocker that deferred v1 does not apply.
- **No new agent** is spawned. The "live cost-estimation agent" framing from the deferred-features memory is intentionally resolved as deterministic bash in the orchestrator — same visibility, zero per-tick API cost, portable to the Claude Agent SDK.

Out of scope (explicitly):
- Pre-flight projection / cost-history file across runs (deferred to a v2 change).
- Mid-flight reasoning ("you're over budget, downgrade impl to Sonnet?") — would require a real spawned agent; not in this change.
- A `/cost` slash command for on-demand snapshots.

## Capabilities

### New Capabilities

None. This extends existing capabilities rather than introducing a new one — the work fits squarely within "compute cost for a feature-workflow run" which is already owned by `automated-cost-computation`.

### Modified Capabilities

- `automated-cost-computation`: shifts from a single Phase-7b post-hoc Python computation to a live per-phase tick model. New requirements: per-phase tick at the end of phases 1-6 (bash invocation of the bundled script with a `--since PHASE_N_START` slice); `SESSION_COST_LOG` memo format; reconciliation requirement in Phase 7b (`ACTUAL_TOTAL` vs `Σ(per-phase ticks)` with an `unaccounted` footnote when divergence exceeds $0.01); per-phase rows in the tracker comment now show measured costs (from the log) instead of `SPAWN_LOG × profile` estimates. The "Locate session JSONL autonomously" and "Compute actual total cost from JSONL" requirements survive but the computation is delegated to the bundled script rather than inline Python.
- `feature-workflow-template`: adds a new lifecycle signal — the per-phase cost tick at end of phases 1-6 — and a new referenced file (`cost-tick.md`) that the orchestrator loads once and follows at each phase boundary. The Phase-7b instruction set is replaced (Python out, log-read + reconciliation in).
- `feature-workflow-generation`: generator's Phase 4 (asset materialisation) gains two new verbatim copies — `compute-cost.sh` into `scripts/`, `pricing.md` into `references/` — pulled from the claudboard repo so generated workflows are self-contained and don't reach back into the parent repo at runtime.

## Impact

- **Affected files (new in the template):**
  - `skills/claudboard-workflow/references/feature-workflow.template/scripts/compute-cost.sh` (verbatim copy stub or copy directive)
  - `skills/claudboard-workflow/references/feature-workflow.template/references/cost-tick.md`
- **Affected files (modified):**
  - `skills/claudboard-workflow/references/feature-workflow.template/SKILL.md.template` — six new tick call-sites + Phase 1 start-timestamp recording
  - `skills/claudboard-workflow/references/feature-workflow.template/references/phase7-cost-analysis.md` — inline Python removed; log-read + reconciliation in
  - `skills/claudboard-workflow/SKILL.md` — generator Phase 4 copies two assets
  - `openspec/specs/automated-cost-computation/spec.md` — via delta in this change
  - `openspec/specs/feature-workflow-template/spec.md` — via delta in this change
  - `openspec/specs/feature-workflow-generation/spec.md` — via delta in this change
- **Affected files (unchanged):**
  - `skills/claudboard/scripts/compute-cost.sh` — source of truth, no edits
  - `skills/claudboard/references/pricing.md` — source of truth, no edits
  - `skills/claudboard/scripts/stop-hook.sh` — feature-workflow path does not use it
  - All other claudboard sub-skills
- **Generated-skill regeneration:** existing generated `feature-workflow` skills will NOT auto-update (v1 has no upgrade path — known caveat from `claudboard-workflow`). Projects that want the new behaviour delete their generated workflow and re-run `/claudboard-workflow`. The hand-edited Bosch copies are unaffected.
- **SDK compatibility:** the tick is bash + a script the SDK runs via its Bash tool, reading a JSONL the SDK writes to the same `~/.claude/projects/<slug>/` location. The SDK case is satisfied by the same code path as Claude Code; no SDK-specific branch is introduced. The script already accepts JSONL path as an argument or via `$CLAUDE_SESSION_JSONL`, which the orchestrator records once in Phase 1.
- **Cost of the change itself:** ~$0 additional API cost per workflow run (the ticks are bash; the only model-side cost is the orchestrator reading and emitting one extra line of output at each phase boundary, which is negligible compared to the phase's actual work).
- **Risks:**
  - *Tick discipline*: the orchestrator (Opus/Sonnet) must reliably follow the "end-of-phase tick" instruction. Mitigation: the reconciliation in 7b catches missed ticks and surfaces them in the footnote as `(unaccounted: $X.XX)` — drift becomes visible rather than silent.
  - *Two pricing tables*: until the existing `claude-pricing.md` (agent profiles) is consolidated with `pricing.md` (cost computation), the template has two price refs. Mitigation: this change keeps them separate (claude-pricing.md = profile reasoning, pricing.md = exact computation); future refactor can merge them.
  - *Bundle drift*: if `claudboard/scripts/compute-cost.sh` is edited but the generator isn't re-run, generated workflows ship a stale script. Mitigation: generator copy is the canonical materialisation point — same risk pattern as `claude-pricing.md` and `ticket-description-template.md` today.
