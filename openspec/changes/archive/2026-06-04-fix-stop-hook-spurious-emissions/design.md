## Context

The cost-reporting Stop hook (`skills/claudboard/scripts/stop-hook.sh`) was introduced by the in-flight `auto-install-cost-hook-for-plugin-users` change. Two bugs make the headline UX unusable in practice — every prompt emits a cost line, and the line always tags task `/analyse` regardless of what the user actually ran.

The diagnosis is grounded in inspection of real Claude Code session JSONLs under `~/.claude/projects/-Users-LUP1BG-Documents-BoschProjects-claude-repo-scan/`:

- **JSONL user-turn shape.** Each top-level entry has fields `cwd`, `entrypoint`, `gitBranch`, `isSidechain`, `message`, `parentUuid`, `promptId`, `sessionId`, `timestamp`, `type`, `userType`, `uuid`, `version`. The `message.content` field is either a JSON string or an array of `{type:"text", text:"..."}`. There is no structured `command` field — slash-command metadata is inlined as XML-ish tags inside the content text:
  ```
  <command-message>openspec-explore</command-message>
  <command-name>/openspec-explore</command-name>
  <command-args>... user's free-form args ...</command-args>
  ```
  The user-typed args, plus the appended skill prompt body, are all part of the same content blob — so substring scanning that blob will incidentally match any token mentioned anywhere.
- **Hook output is not in the JSONL.** The hook's `{"systemMessage": "..."}` envelope is consumed by the harness but never appears in the session JSONL. A grep for `"systemMessage"` or `"Cost for /"` across real session JSONLs returns zero hits. `type: "system"` entries that do exist are harness telemetry (`turn_duration` etc.), unrelated to hook output. So self-detection via re-scanning the JSONL for the hook's own prior emission is not viable; durable state must live elsewhere.
- **Task skills are multi-turn.** All four task verbs (`/analyse`, `/generate`, `/refresh`, `/techdebt`) have mid-task user-confirmation gates (e.g. `claudboard-analyse/SKILL.md:77` ecosystem y/n, `:142` topology confirmation, `:515` ambiguous-pattern questions; `claudboard-generate/SKILL.md:259` stale-catalog confirm; `claudboard-refresh/SKILL.md:118` updated-graph confirmation). So adjacency-based heuristics ("trigger must be the immediately prior user turn") would suppress the final cost line on every real run.

## Goals / Non-Goals

**Goals:**
- The hook emits a cost line if and only if the latest user turn matched as a trigger was a real claudboard slash-command invocation.
- The cost line for a given (sessionId, triggerTimestamp) is emitted at most once per session lifetime, regardless of how many Stop events fire afterwards or how many mid-task confirmation turns the user makes.
- Existing test fixtures are updated to the realistic JSONL shape so they continue to gate the regex on the actual format Claude Code writes, not on a hand-crafted minimal one.
- The fix is purely local to `stop-hook.sh` + tests; no API surface, no new dependencies, no new directories outside `~/.claude/projects/`.

**Non-Goals:**
- Changing `compute-cost.sh`, the pricing table, or per-phase cost ticks in feature-workflow.
- Cleanup of accumulated marker files. Markers are tiny and orphan naturally; a future change can add a sweep if it ever matters.
- Backporting to already-installed plugin versions.
- Tracking per-task aggregate cost across sessions or persisting cost history.

## Decisions

### Decision 1: Anchored extraction of `<command-name>` over free-text substring match

The trigger jq becomes (sketch):

```
[.[] | select(.type == "user")]
| map(
    .timestamp as $ts |
    (.message.content
      | if type == "string" then .
        elif type == "array" then (.[0].text? // "")
        else "" end) as $text |
    select($text | test("<command-name>/(?:claudboard:claudboard-)?(?:analyse|generate|refresh|techdebt)</command-name>")) |
    { timestamp: $ts,
      cmd: ($text
        | capture("<command-name>/(?:claudboard:claudboard-)?(?<c>analyse|generate|refresh|techdebt)</command-name>")
        | .c) }
  )
| last? // null
```

A user turn with no `<command-name>` block (free-form chat) never matches. A user turn whose `<command-name>` is `/openspec-explore` or any other non-claudboard command never matches even if its args mention the trigger verbs.

**Why this over other options:**
- *Parse the content as XML and read the `<command-name>` child element.* Same effect, much more machinery. The content is not real XML — it's a partial fragment — so a full parser would be over-engineered for a single tag extraction.
- *Match on the bare slash form anywhere in the content (today's pattern, just stricter).* Doesn't fix the false-positive: chat that quotes `/analyse` and slash-command arg bodies that mention the verbs still match.
- *Match adjacency (trigger must be the immediately prior user turn).* Ruled out by the multi-turn nature of all four task skills (see Context).

**Edge case — source-repo bare invocations:** Today's regex also accepts a bare `/analyse` not wrapped in a `<command-name>` tag (e.g. if a source-repo contributor invokes the skill directly outside the plugin-namespaced slash UI). With the new strict regex, such bare invocations no longer trigger. This is acceptable: plugin installs always go through the wrapped form, and source-repo contributors who want a cost line can call `compute-cost.sh` directly. The predecessor change's spec already states "source-repo `/analyse` invocation (plugin is not intended to run from the source repo — explicitly dropped)" out of scope.

### Decision 2: Sidecar marker file under `~/.claude/projects/<cwd-slug>/.claudboard-cost-emitted/`

After the latest valid trigger is identified (`sessionId S`, `triggerTs T`, `cmd C`), the hook checks for:

```
~/.claude/projects/<cwd-slug>/.claudboard-cost-emitted/<S>__<T>.marker
```

- If the file exists → exit silently.
- Else → compute and emit the cost line, then `printf '%s\n' "$COST_LINE" > <marker>`.

The `<cwd-slug>` is the same slug Claude already uses for the session JSONL directory (the `pwd | sed 's|/|-|g'` form already in `stop-hook.sh`). The hidden subdirectory `.claudboard-cost-emitted/` sits next to the JSONLs; `mkdir -p` is idempotent.

**Marker key:** `(sessionId, triggerTs)`. NOT just `sessionId` — a session can legitimately contain multiple task runs (e.g. `/analyse` then later `/generate`); each should get its own one-time cost line.

**Marker contents:** the literal cost line that was emitted, for ad-hoc debugging by anyone tailing the directory. The hook does not read the contents back.

**Why this over other options:**
- *Self-detect prior emission by re-scanning the JSONL for the hook's own systemMessage.* Doesn't work — hook output is not written into the JSONL (verified).
- *In-memory dedup per Stop event.* Stop events fire as separate process invocations; there is no shared in-memory state to consult.
- *Single per-session marker.* Would suppress legitimate cost lines for a second task verb run in the same session.
- *XDG_STATE_HOME / a brand-new directory under `$HOME`.* Adds platform machinery (XDG isn't standard on macOS, where the user runs). Co-locating with the JSONL keeps the marker scope intuitive — "this session's bookkeeping" — and orphans together with the session.

### Decision 3: Reshape four legacy fixtures to the realistic wrapped form

`single-task-opus.jsonl`, `mixed-models.jsonl`, `topology-paused.jsonl`, `unknown-model.jsonl` currently use bare `"/analyse"` / `"/generate"` as user-turn content. Under the new strict regex they no longer match. Two options were considered:

- *Keep the legacy bare form for compatibility, add a fallback regex branch.* Rejected — the bare form is not what Claude Code actually writes for any real invocation (verified across real session JSONLs). A fallback branch would exist only to keep unrealistic fixtures green; that pulls test fidelity in the wrong direction.
- *Reshape the fixtures to the wrapped form.* Adopted. This brings every fixture in line with what's actually in the wild and removes the temptation to special-case the bare form in production code.

The cost-emission assertion strings (e.g. `Cost for /analyse: $0.06 (Opus 4.7 (Vertex), 2 calls, 2K out)`) are unchanged — only the shape of the user-turn `content` block changes, not the assistant-turn token-usage data the cost line derives from.

### Decision 4: Test isolation via per-case `$HOME` override

The new marker behavior makes the test suite stateful by default — a test that emits writes a marker that would suppress later tests against the same fixture. Each test case in `tests/hook-run.sh` therefore runs with `HOME=$(mktemp -d)` (or equivalent) for the hook invocation, so each case gets a fresh empty marker directory. The "silent on repeat invocation" assertion intentionally does NOT reset the marker dir between its two hook invocations — that's the whole point of the assertion.

**Why not a `--clear-markers` debug flag on the hook?** Adds a code path that exists only for tests. The temp-`$HOME` pattern keeps production code unaware of testing concerns.

## Risks / Trade-offs

- **Risk: `<command-name>` wrapper format drifts in a future Claude Code release** → the strict regex silently stops matching, no cost line ever fires, and the regression is invisible until someone notices.
  → Mitigation: the namespaced fixture (existing) plus the new multi-stop fixture together pin the current wrapper format. CI fails on any drift. The README's existing "if you don't see a cost line, run `claude --debug`" hint surfaces user-visible drift too.

- **Risk: marker directory can't be created (read-only `$HOME`, filesystem full, permissions)** → the `mkdir -p` or marker write fails, the hook either errors out (with `set -euo pipefail` flowing through) or — if guarded — falls through to today's emit-every-Stop behavior for that pathological session.
  → Mitigation: wrap the marker write in `|| true` so a write failure degrades to today's behavior, not a hard exit that breaks the Stop hook for the user. Same for `mkdir -p`. This is no worse than the status quo (which is "emit every time") for the affected session, and almost no users hit this path.

- **Risk: marker accumulation** → over months, the `.claudboard-cost-emitted/` dir collects one marker per task invocation forever.
  → Trade-off accepted: ~50 bytes × N tasks per project is negligible. The directory orphans together with the session JSONLs if the user ever clears them. A future cleanup pass can be added when (if) it ever matters.

- **Risk: sessionId collisions across two different machines syncing the same project dir** → vanishingly unlikely (sessionIds are UUIDs), but if it ever happened the second machine could miss a legitimate cost line.
  → Trade-off accepted: not a realistic scenario.

- **Trade-off: source-repo bare invocations no longer trigger the hook** → previously, a bare `/analyse` typed in source-repo dev mode would emit a cost line. Now it won't, because the regex requires the `<command-name>` wrapper.
  → Acceptable per the predecessor change's "source-repo invocation explicitly out of scope" statement. Contributors can invoke `compute-cost.sh` directly.
