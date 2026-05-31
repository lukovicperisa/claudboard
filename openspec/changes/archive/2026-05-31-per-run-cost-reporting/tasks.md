## 1. Price table

- [x] 1.1 Create `skills/claudboard/references/pricing.md` with the documented Markdown structure (one row per `model_id`, columns: model_id, display_name, effective_from, base_input, cache_write_5m, cache_write_1h, cache_read, output)
- [x] 1.2 Populate initial rows for `claude-opus-4-7`, `claude-sonnet-4-6`, `claude-haiku-4-5-20251001` with the rates documented in the proposal (effective_from: 2026-05-31, the date of the measured GardenMind run that prompted this change)
- [x] 1.3 Add a header section to the file explaining: how to add a new model (append a row), how rate changes are versioned (append a new row with a later effective_from), and the script's selection rule (latest effective_from ≤ turn timestamp)

## 2. Cost script — core

- [x] 2.1 Create `skills/claudboard/scripts/compute-cost.sh` with the bash + jq shebang, `set -euo pipefail`, and a 10-line header comment summarising the dedup-by-requestId rule (so future readers don't naively sum lines)
- [x] 2.2 Implement argument parsing: positional JSONL path, `--since`, `--until`, `--format` (default `one-line`)
- [x] 2.3 Implement JSONL-path resolution: positional argument wins; fall back to `$CLAUDE_SESSION_JSONL`; if both absent, exit non-zero with named-inputs error
- [x] 2.4 Implement jq dedup pipeline: filter `type==assistant`, apply time-slice bounds when present, project `{requestId, model, input, c5, c1h, cr, output}`, sort-unique by `requestId`
- [x] 2.5 Implement price-table parsing: read `references/pricing.md`, build an in-memory map `model_id → {effective_from, rates}`. For v1 the latest-effective-from-row-per-model is the entry kept
- [x] 2.6 Implement per-turn pricing: look up turn's `model` in the table; on miss, emit the documented warn-once-per-unknown-model stderr line and fall back to Sonnet 4.6 rates
- [x] 2.7 Implement summation across turns: keep per-model totals (so multi-model slices render correctly) plus a single grand-total dollar number
- [x] 2.8 Implement output-token counter (sum across deduped turns) and unique-requestId call count

## 3. Cost script — output formats

- [x] 3.1 Implement `one-line` format: `Cost for /<cmd>: $<total> (<Model>, <N> calls, <K> out)` with `<total>` formatted `%.2f`, `<K>` formatted as `<n>K` if ≥1000 else raw count. When multi-model, render `<Model>` as `mixed`. The `<cmd>` is passed in via a `--task` flag (default: blank, in which case the prefix is `Cost:` not `Cost for /<cmd>:`)
- [x] 3.2 Implement `json` format: emit a single JSON object with the documented keys (`total_usd`, `model`, `api_calls`, `tokens`, `cost_breakdown_usd`, `slice`). Use `jq -n` to construct; verify it's valid JSON by piping through `jq .` in the script's self-test
- [x] 3.3 Add a `--help` flag that prints usage, the supported `--format` values, the `--since`/`--until` examples, and the `$CLAUDE_SESSION_JSONL` fallback

## 4. Cost script — schema-drift safety

- [x] 4.1 On the first processed assistant turn, assert that `.message.usage` exists and that `.requestId` exists. On failure, emit a clear stderr error naming the path to the failing turn (`<jsonl-path>:<line-number>`) and the assumed schema, then exit non-zero
- [x] 4.2 Document the asserted schema in a comment at the top of the script (the exact field paths the script relies on), so future schema migrations can audit against one location

## 5. Stop hook — wrapper script

- [x] 5.1 Create `skills/claudboard/scripts/stop-hook.sh` (the hook target, separate from `compute-cost.sh` so the hook logic and the cost-computation logic evolve independently)
- [x] 5.2 Implement JSONL-path resolution in the hook: prefer `$CLAUDE_SESSION_JSONL`; else compute `~/.claude/projects/$(pwd | sed 's|/|-|g')/<CLAUDE_CODE_SESSION_ID>.jsonl`
- [x] 5.3 Implement matching-trigger detection: walk back through `type: user` entries (most recent first), match `.message.content` (when string) or `.message.content[0].text` (when array) against `^\s*/(analyse|generate|refresh|techdebt)\b`. Capture the matched command name and the matching turn's `timestamp`. If no match found, exit 0 silently
- [x] 5.4 Implement in-progress detection: locate the most recent `type: assistant` entry whose `message.content[*].type == "tool_use"` and whose `message.content[*].name == "AskUserQuestion"`. If found and that entry's timestamp is later than the matched trigger's timestamp, set the in-progress flag
- [x] 5.5 Invoke `compute-cost.sh --since <matched-timestamp> --task <matched-cmd> <jsonl-path>` and capture stdout
- [x] 5.6 If in-progress flag is set, append ` (in progress)` to the captured line before printing to stdout

## 6. Hook registration documentation

- [x] 6.1 Add a "Per-task cost reporting (optional)" section to `README.md` with: one-paragraph rationale, the copy-pasteable `settings.json` block with the Stop hook entry pointing at `stop-hook.sh`, the absolute path users should expect, and one example of the resulting output line
- [x] 6.2 Document in the README: the four currently-gated triggers (`/analyse`, `/generate`, `/refresh`, `/techdebt`), the in-progress suffix, the $0-API-token property, and the known-limitation note about gate heuristics
- [x] 6.3 Cross-link the README section from `skills/claudboard/SKILL.md`'s "What this skill produces" area so users notice the opt-in during onboarding

## 7. Spec correction — automated-cost-computation Opus 4.7 rates

- [x] 7.1 (handled by /opsx:apply via the delta spec) Update `openspec/specs/automated-cost-computation/spec.md` "Compute actual total cost from JSONL" requirement's pricing-rates table: Opus 4.7 row from `$5.00 / $6.25 / $10.00 / $0.50 / $25.00` to `$15.00 / $18.75 / $30.00 / $1.50 / $75.00`
- [x] 7.2 Verify no other place in the repo embeds the old Opus 4.7 rates: `grep -rn '\$5\.00.*Opus\|Opus.*\$25\.00' skills/ openspec/specs/` and address any hits

## 8. Testing — unit-level on the script

- [x] 8.1 Create `skills/claudboard/scripts/tests/` directory with at least four JSONL fixtures: `single-task-opus.jsonl` (the measured GardenMind shape), `mixed-models.jsonl` (Opus + Sonnet in one session), `unknown-model.jsonl` (a `claude-opus-5-0` turn for the warn-once path), `topology-paused.jsonl` (a slice ending with an `AskUserQuestion` tool_use)
- [x] 8.2 Write `tests/run.sh` that invokes `compute-cost.sh` against each fixture and asserts: dollar total within a tolerance, model name rendering, multi-model handling, warning emitted on unknown model, JSON output is valid JSON
- [x] 8.3 Write `tests/hook-run.sh` that invokes `stop-hook.sh` against a fixture with the trigger gate satisfied and one without; assert silent exit on the second, asserted line shape on the first, and `(in progress)` suffix on the topology-paused fixture
- [x] 8.4 Run the full test suite locally on darwin (BSD `sed`, `grep`) — the canonical reference platform until CI is added; document any flag-portability fixes inline

## 9. Manual verification

- [x] 9.1 Install the documented hook into the repo's own `.claude/settings.local.json` (NOT the global settings; scoped to claudboard repo so other projects are unaffected)
- [ ] 9.2 Run `/analyse` against a small repo (e.g., a fresh tmp dir with one file) in a clean session; observe one cost line at task end; confirm the dollar amount is within ~5% of the conversation's `/cost` total for that period
- [ ] 9.3 Run `/analyse` followed by `/generate` in the same session; observe two distinct cost lines, second one's slice starting at the `/generate` prompt timestamp, not accumulating with the first
- [ ] 9.4 Provoke the in-progress path: invoke `/analyse` against a real monorepo, let it pause at the topology-confirm question, confirm the cost line emitted at that Stop event ends with `(in progress)`
- [ ] 9.5 Provoke the unknown-model path: temporarily edit one fixture turn to use `model: "claude-opus-5-0"`, re-run, confirm the warning lands on stderr exactly once

## 10. Memory and proposal cleanup

- [x] 10.1 Update the `cost-measurement-source` memory file with a pointer to the shipped `compute-cost.sh` so future sessions invoke the script directly rather than ad-hoc jq
- [x] 10.2 Update the `cost-visibility-priority` memory file: mark the v1 capability as shipped, note the deferred follow-ups (feature-workflow per-phase, live cost-estimation agent)
- [x] 10.3 Note in `MEMORY.md` index that the cost-measurement primitive is now a first-class scripted capability, not an ad-hoc procedure
