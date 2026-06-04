## Why

The just-introduced cost-reporting Stop hook fires a cost line on **every** prompt in a session — not just at the end of a claudboard task — and the line always reads `Cost for /analyse: ...` regardless of which task (if any) the user actually ran. The headline UX of "see what each task cost" is unusable: users see noise on unrelated prompts and cannot trust the task tag.

Two compounding bugs in `skills/claudboard/scripts/stop-hook.sh` are responsible. Both were verified by inspecting real Claude Code session JSONLs in this repo:

1. **Trigger regex matches incidental text in any user turn**, not real slash invocations. The current `test("/(?:claudboard:claudboard-)?(?:analyse|generate|refresh|techdebt)\b")` fires on chat that quotes those tokens (e.g. "the change matched /analyse instead of /claudboard:claudboard-analyse") and on the inline body of any other slash command (`<command-args>`, appended skill prompts). `capture()` returns the first match in the scanned text, which is alphabetically `analyse` almost every time — hence "always /analyse".

2. **No emit-once gate.** Once a real or false-positive trigger exists in the session JSONL, every subsequent Stop event re-finds it via `last?`, recomputes cost `--since` that timestamp (including all unrelated work that happened after), and re-emits — for the entire lifetime of the session.

## What Changes

- **MODIFIED** `skills/claudboard/scripts/stop-hook.sh` — replace the free-text substring match with an anchored extraction of the `<command-name>...</command-name>` inline block, then anchor-match the verb. User turns with no `<command-name>` wrapper are free-form chat and never match. Then, after identifying the latest valid trigger, consult a sidecar marker file keyed on `(sessionId, triggerTimestamp)`: if the marker exists, exit silently; otherwise emit the cost line and write the marker.
- **NEW** `skills/claudboard/scripts/tests/chat-mentions-trigger.jsonl` — fixture with a free-text user turn that quotes `/analyse` and `/claudboard:claudboard-generate` inline (mirrors the real-world false-positive observed in this repo's session JSONLs). Assertion: hook emits nothing.
- **NEW** `skills/claudboard/scripts/tests/multi-stop-single-trigger.jsonl` — fixture with one real wrapped `<command-name>/claudboard:claudboard-analyse</command-name>` trigger followed by two more user turns simulating mid-task confirmations. Assertion: running the hook twice in a row against this fixture produces a cost line on the first run and a silent exit on the second.
- **MODIFIED** `skills/claudboard/scripts/tests/{single-task-opus,mixed-models,topology-paused,unknown-model}.jsonl` — replace the unrealistic bare `"/analyse"` / `"/generate"` user-turn content with the realistic wrapped form Claude Code actually writes (`<command-message>...</command-message>\n<command-name>/claudboard:claudboard-{verb}</command-name>\n<command-args></command-args>` inside a `[{type:"text", text:"..."}]` content array). Required because the new strict regex no longer matches the unrealistic bare form, and the existing fixtures don't reflect real Claude Code JSONL output anyway.
- **MODIFIED** `skills/claudboard/scripts/tests/hook-run.sh` — wire in the two new fixtures and add the "silent on repeat invocation" assertion. Each test case must isolate its own marker directory (e.g. by pointing `$HOME` at a scoped temp dir) so cases stay hermetic.

Out of scope:
- Any change to `compute-cost.sh` or the per-model pricing table.
- Any change to feature-workflow per-phase cost ticks (orchestrator-driven, not hook-driven).
- A marker-cleanup sweep — markers are ~50 bytes per task per session and orphan naturally with their session JSONLs.
- Backporting the fix to plugin versions already installed; the fix arrives in the next published version like any other change.

## Capabilities

### New Capabilities
None.

### Modified Capabilities
- `cost-reporting`: trigger-detection semantics tighten from free-text substring match to anchored `<command-name>` extraction, and a new emit-once-per-trigger invariant is added. **Ordering dependency:** the `cost-reporting` capability is introduced by the in-flight `auto-install-cost-hook-for-plugin-users` change and is not yet synced into `openspec/specs/`. This change MUST archive after that predecessor; the delta requirements here build on the requirements that change defines.

## Impact

- **Affected files (new):**
  - `skills/claudboard/scripts/tests/chat-mentions-trigger.jsonl`
  - `skills/claudboard/scripts/tests/multi-stop-single-trigger.jsonl`
- **Affected files (modified):**
  - `skills/claudboard/scripts/stop-hook.sh` (regex replaced + marker check/write added)
  - `skills/claudboard/scripts/tests/hook-run.sh` (two new fixtures wired, repeat-invocation assertion added, marker-dir isolation per case)
  - `skills/claudboard/scripts/tests/{single-task-opus,mixed-models,topology-paused,unknown-model}.jsonl` (user-turn content reshaped to the realistic wrapped form)
- **Affected files (unchanged):**
  - `skills/claudboard/scripts/compute-cost.sh`
  - `hooks/hooks.json` (registration unchanged; only the script's internal logic changes)
  - `.claude-plugin/plugin.json`
  - All sub-skill SKILL.md files
- **User-visible effect:** After the next plugin publish, the cost line appears at most once per real `/claudboard:claudboard-{analyse,generate,refresh,techdebt}` run (at the end of the task) and never appears on unrelated prompts. The task tag in the line reflects the actual task verb the user typed.
- **Runtime cost:** $0 additional API tokens — the hook is still a bash + jq script that reads local session JSONLs and writes a small marker file.
- **Risks:**
  - *Wrapper format drift across Claude Code releases.* If Anthropic changes the inline `<command-name>...</command-name>` envelope for plugin slash commands, the new strict regex will silently stop matching. Mitigation: the namespaced fixture (already shipped) plus the new multi-stop fixture pin the current observed format; any wrapper change will fail tests before publish.
  - *Marker file accumulation.* Markers persist for the lifetime of the project's JSONL directory. ~50 bytes per task per session is negligible, and no cleanup sweep is in scope. If accumulation ever becomes a concern, a follow-up change can add a "delete markers older than N days" pass at hook start.
  - *Marker-dir write failure.* If the marker directory can't be created or written (read-only home, etc.), the hook will silently fall through to emitting on every Stop — i.e. revert to today's behavior for that specific case. Acceptable: the user gets noisy output instead of a hard error, which is no worse than the status quo.
