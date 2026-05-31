## 1. Bundle the cost-script and pricing table into the template

- [x] 1.1 In `skills/claudboard-workflow/references/feature-workflow.template/scripts/`, create the bundling mechanism: either a symlink to `skills/claudboard/scripts/compute-cost.sh` or a checked-in copy with a generator-time refresh step. Choose the approach that matches how `claude-pricing.md` is materialised today (consistency over novelty).
- [x] 1.2 Same for `skills/claudboard-workflow/references/feature-workflow.template/references/pricing.md` ← `skills/claudboard/references/pricing.md`.
- [x] 1.3 Verify the bundled `compute-cost.sh` is marked executable in the template tree (so the generator's verbatim copy preserves the mode).
- [x] 1.4 Smoke-test the bundled script standalone: `compute-cost.sh --help`, then `compute-cost.sh --since 2026-05-31T00:00:00Z <recent session.jsonl>` and confirm the output matches the unbundled invocation.

## 2. Author cost-tick.md (the per-phase tick contract)

- [x] 2.1 Create `skills/claudboard-workflow/references/feature-workflow.template/references/cost-tick.md`. It SHALL contain: the bash invocation template (with `{{SINCE}}` and `{{LABEL}}` slots resolved by the caller), the output format `Phase N (<label>): $X.XX │ session $Y.YY`, the `SESSION_COST_LOG` append rule, the phase-label vocabulary (`Spec+Plan`, `Branch`, `Implement`, `Commit`, `Review`, `PR`), and the SDK note (script accepts `--since`; honours `$CLAUDE_SESSION_JSONL`).
- [x] 2.2 Specify how the orchestrator parses the `$X.XX` and running total `$Y.YY` from the script's stdout to append to `SESSION_COST_LOG`. Pick a format the script already produces — either `compute-cost.sh --format one-line` or add a `--format tick` mode (prefer the former; minimise script changes).
- [x] 2.3 Include a failure-mode section: what to print if the script fails or returns no rows. Default: emit `Phase N (<label>): $0.00 │ session $Y.YY (cost unavailable)` and continue; do NOT block the workflow.

## 3. Wire the tick into the orchestrator template

- [x] 3.1 In `skills/claudboard-workflow/references/feature-workflow.template/SKILL.md.template`, at the workflow kickoff (Phase 1 entry), add the instruction to record `SESSION_JSONL_PATH` (already present per spec) and `PHASE_1_START` as an ISO 8601 UTC timestamp.
- [x] 3.2 At the end of Phase 1, add the one-line shorthand: `### 1-end. Cost tick → see references/cost-tick.md (label="Spec+Plan", since=PHASE_1_START)`. Immediately after, instruct: record `PHASE_2_START`.
- [x] 3.3 Repeat 3.2 for phases 2, 3, 4, 5, 6 with the appropriate labels (Branch, Implement, Commit, Review, PR) and `PHASE_N_START` references.
- [x] 3.4 After the Phase 6 tick, do NOT record `PHASE_7_START` — Phase 7 has its own (different) cost behaviour, not a tick.
- [x] 3.5 Confirm the template orchestrator (Opus/Sonnet) instruction style matches the existing slim shorthand convention (see `slim-feature-workflow-orchestrator` change). One line per call site, no inline bash blocks.

## 4. Replace Phase 7b inline Python with bundled-script + log read

- [x] 4.1 In `skills/claudboard-workflow/references/feature-workflow.template/references/phase7-cost-analysis.md`, remove the `python3 - <<'PYEOF' ... PYEOF` block entirely.
- [x] 4.2 Replace Step 2 with: `Run compute-cost.sh once over the full session: bash scripts/compute-cost.sh --format one-line "$SESSION_JSONL_PATH"`. Capture the printed total as `ACTUAL_TOTAL`.
- [x] 4.3 Replace Step 3 with: `Read SESSION_COST_LOG to obtain per-phase measured costs (P1_COST..P6_COST). For any missing phase, treat as $0.00.`
- [x] 4.4 Add a new Step 4 (reconciliation): `Compute RECONCILIATION = ACTUAL_TOTAL − (P1+P2+P3+P4+P5+P6). If |RECONCILIATION| > $0.01, set the unaccounted-annotation flag to "(unaccounted: $|RECONCILIATION|.XX)".` Compute `ORCH_COST = max(0, RECONCILIATION)`.
- [x] 4.5 Update Step 5 (compose comment) so the per-phase bullets use measured `P1_COST..P6_COST` from the log, the orchestrator bullet uses the clamped `ORCH_COST`, and the footnote sentence becomes `Measured per phase from session token log. Phase 7 finalization included in Orchestrator.` with the optional `(unaccounted: $X.XX)` or `(no per-phase ticks recorded — session total only)` suffix.
- [x] 4.6 Remove the legacy "sub-agent profiles overestimated; orchestrator cost absorbed" branch from Step 4 (it no longer applies — measured ticks can't overestimate). Confirm no other references to SPAWN_LOG × profile remain in `phase7-cost-analysis.md` for cost purposes.

## 5. Update the generator to ship the bundled assets

- [x] 5.1 In `skills/claudboard-workflow/SKILL.md` (the generator), add `scripts/compute-cost.sh` to the asset-materialisation list (Phase 4 / "Materialise verbatim assets" section), sourced from `claudboard/scripts/`. Preserve executable mode.
- [x] 5.2 Add `references/pricing.md` to the asset-materialisation list, sourced from `claudboard/references/`.
- [x] 5.3 Add `references/cost-tick.md` to the rendered-template list (it's rendered from the template, not copied from claudboard).
- [x] 5.4 Update the post-generation completion report so it announces the bundled cost-tick capability (one line, mirroring the existing capability announcements).
- [x] 5.5 Update the workspace-mode generation path to ensure the same three files are written through the symlink into the meta-repo, not into per-repo `.claude/skills/` (covered by existing path-violation guards but worth explicit verification).

## 6. Refresh skill exclusions and docs

- [x] 6.1 Confirm `claudboard-refresh` skips `scripts/compute-cost.sh` and `references/pricing.md` inside generated `feature-workflow/` directories (the existing "refresh skips feature-workflow" rule should cover this; verify).
- [x] 6.2 Update `CLAUDE.md` (this repo's, not the generated one) to document the new files in the "Skill anatomy" tree for `feature-workflow.template/`.
- [x] 6.3 Update the v1 caveat language in `CLAUDE.md` / generator README if needed: regenerating to pick up the live tick remains a manual delete-and-regen operation.

## 7. Validate

- [x] 7.1 Run `openspec validate live-per-phase-cost-tally --strict` and fix any spec issues.
- [x] 7.2 Generate a fresh feature-workflow into a throwaway test project (single-repo); verify the generated tree contains `scripts/compute-cost.sh` (executable), `references/pricing.md`, `references/cost-tick.md`, and that `SKILL.md` references cost-tick at each of phases 1-6.
- [x] 7.3 Inspect a few of the generated SKILL.md phase-end shorthands by eye to confirm the slim convention (one line per call site, not a re-fattened block).
- [x] 7.4 Dry-run an end-to-end feature-workflow against a test ticket. Confirm: six tick lines appear in user-visible output (one per phase end); SESSION_COST_LOG accumulates six entries; Phase 7b's posted comment shows measured per-phase costs; reconciliation footnote is either absent or has a small positive `(unaccounted: ...)` value (Phase 7 finalisation cost).
- [x] 7.5 Skip a phase deliberately (or simulate a missed tick) and confirm the reconciliation footnote surfaces the gap rather than silently hiding it.
- [x] 7.6 Run under the Claude Agent SDK (or simulate by setting `$CLAUDE_SESSION_JSONL` to a fixed path) and confirm the ticks still work — bundled script honours the env var.

## 8. Update memory and document outcomes

- [x] 8.1 Update `cost-visibility-priority` memory: move "Live cost availability inside workflows" from "Deferred" to shipped, with the live-per-phase-tally implementation pattern noted.
- [x] 8.2 Leave `cost-measurement-source` memory unchanged — the script reference is still authoritative; bundle path simply makes it self-contained in generated workflows.
