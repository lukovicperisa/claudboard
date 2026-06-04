## 1. Reshape legacy fixtures to the realistic wrapped form

- [x] 1.1 Reshape `skills/claudboard/scripts/tests/single-task-opus.jsonl` so the user turn's `.message.content` becomes a `[{"type":"text","text":"<command-message>claudboard-analyse</command-message>\n<command-name>/claudboard:claudboard-analyse</command-name>\n<command-args></command-args>"}]` array instead of the bare string `"/analyse"`. Leave assistant turns untouched (cost computation is unaffected).
- [x] 1.2 Reshape `skills/claudboard/scripts/tests/mixed-models.jsonl` analogously (user turn content uses the wrapped `<command-name>/claudboard:claudboard-generate</command-name>` form).
- [x] 1.3 Reshape `skills/claudboard/scripts/tests/topology-paused.jsonl` analogously (wrapped `<command-name>/claudboard:claudboard-analyse</command-name>`).
- [x] 1.4 Reshape `skills/claudboard/scripts/tests/unknown-model.jsonl` analogously (wrapped `<command-name>/claudboard:claudboard-analyse</command-name>`).
- [x] 1.5 Run `bash skills/claudboard/scripts/tests/run.sh` and confirm all `compute-cost.sh` assertions still pass (they should — only user-turn content shape changed).

## 2. Author new fixtures for the regression cases

- [x] 2.1 Create `skills/claudboard/scripts/tests/chat-mentions-trigger.jsonl` — a session JSONL with at least one free-text user turn whose `.message.content` mentions `/analyse` and `/claudboard:claudboard-generate` inline (no `<command-name>` wrapper anywhere), plus a minimal assistant turn so the file is a valid JSONL session shape. Pattern this after the real false-positive observed in `~/.claude/projects/.../aad4287a-*.jsonl`.
- [x] 2.2 Create `skills/claudboard/scripts/tests/multi-stop-single-trigger.jsonl` — a session JSONL with one wrapped `<command-name>/claudboard:claudboard-analyse</command-name>` trigger turn at a fixed timestamp, followed by at least one additional user turn (free-text, simulating a mid-task y/n confirmation) and matching assistant turns with token-usage data sufficient to produce a deterministic non-empty cost line.

## 3. Replace the trigger-detection logic in `stop-hook.sh`

- [x] 3.1 In `skills/claudboard/scripts/stop-hook.sh`, replace the existing `test(.../analyse|generate|refresh|techdebt.../)` jq filter with one that requires the `<command-name>...</command-name>` wrapper and anchor-matches the verb inside it. The capture group SHALL extract the bare verb (`analyse` | `generate` | `refresh` | `techdebt`) as `$TRIGGER_CMD`.
- [x] 3.2 Verify the jq filter still handles both `.message.content` shapes (JSON string and `[{type:"text", text:"..."}]` array) — the existing dispatch on `(.message.content | type)` should be reused.
- [x] 3.3 Manually invoke `CLAUDE_SESSION_JSONL=skills/claudboard/scripts/tests/chat-mentions-trigger.jsonl skills/claudboard/scripts/stop-hook.sh` and confirm stdout is empty (no `{"systemMessage":...}` envelope emitted).
- [x] 3.4 Manually invoke `CLAUDE_SESSION_JSONL=skills/claudboard/scripts/tests/namespaced-trigger.jsonl skills/claudboard/scripts/stop-hook.sh` and confirm a cost line tagged `/analyse` is still emitted.

## 4. Add the emit-once-per-trigger marker logic in `stop-hook.sh`

- [x] 4.1 After identifying the latest valid trigger (`$TRIGGER_TS`, `$TRIGGER_CMD`) and the session id (extract from JSONL or fall back to `$CLAUDE_CODE_SESSION_ID`), compute the marker path: `${HOME}/.claude/projects/$(pwd | sed 's|/|-|g')/.claudboard-cost-emitted/<sessionId>__<triggerTs>.marker`. Reuse the existing `cwd | sed` slug pattern already in the script.
- [x] 4.2 If the marker file exists, `exit 0` immediately (silent) before computing cost. Otherwise proceed to the existing cost-computation path.
- [x] 4.3 After emitting the cost-line `systemMessage` envelope, `mkdir -p` the marker dir and `printf '%s\n' "$COST_LINE" > <marker>`. Wrap both the `mkdir -p` and the marker write in `|| true` so a write failure degrades to the pre-fix behavior for that pathological session and never causes the hook to exit non-zero.
- [x] 4.4 Run the existing `bash skills/claudboard/scripts/tests/hook-run.sh` and confirm the existing positive-case assertions still pass against the reshaped fixtures.

## 5. Extend `tests/hook-run.sh` with the new assertions

- [x] 5.1 At the top of `tests/hook-run.sh`, refactor so each test case runs with `HOME=$(mktemp -d)` (or per-case env override) for its hook invocation, so each case has a fresh empty marker directory. Existing positive cases retain their current assertions but now run inside the isolated HOME.
- [x] 5.2 Add a `chat-mentions-trigger` test case: `out=$(HOME=$(mktemp -d) CLAUDE_SESSION_JSONL="$F/chat-mentions-trigger.jsonl" "$HOOK")`; assert `out` is empty.
- [x] 5.3 Add a `multi-stop-single-trigger` test case: set up one shared `HOME=$(mktemp -d)`, invoke the hook twice in succession against `multi-stop-single-trigger.jsonl` using that HOME, capture both outputs separately, assert the first is a cost line tagged `/analyse` and the second is empty.
- [x] 5.4 Add a sanity test that confirms a marker file is created in the expected location after the first invocation of the multi-stop fixture (use the same shared HOME from 5.3; check the `.claudboard-cost-emitted/` subdirectory contains exactly one `*.marker` file).
- [x] 5.5 Run `bash skills/claudboard/scripts/tests/hook-run.sh` and confirm every assertion passes (existing + new).

## 6. End-to-end validation against a real session

- [x] 6.1 Copy a recent real session JSONL from `~/.claude/projects/-Users-LUP1BG-Documents-BoschProjects-claude-repo-scan/` that contains a `/openspec-explore` invocation with no claudboard trigger, into a scratch location. Invoke `CLAUDE_SESSION_JSONL=<scratch>.jsonl skills/claudboard/scripts/stop-hook.sh` and confirm stdout is empty (today's behavior would emit `/analyse`).
- [x] 6.2 Bump the plugin version in `.claude-plugin/plugin.json` to the next beta (e.g. `4.0.0-beta.7`). Note the change in the commit message.

## 7. Wrap-up

- [x] 7.1 Run `openspec validate fix-stop-hook-spurious-emissions --strict` and resolve any structural issues it reports.
- [x] 7.2 Confirm the change is ready for archive: `openspec status --change fix-stop-hook-spurious-emissions` reports all artifacts done, `applyRequires` satisfied, no pending checklists.
