## MODIFIED Requirements

### Requirement: Trigger regex SHALL match both bare and plugin-namespaced slash forms

The Stop hook's trigger-detection logic SHALL identify a claudboard task invocation by extracting the inline `<command-name>...</command-name>` block from a user turn's `.message.content` (handling both the JSON-string and the `[{type:"text", text:"..."}]` array shapes Claude Code writes) and anchor-matching the extracted command name against the regex:

```
^/(?:claudboard:claudboard-)?(?<verb>analyse|generate|refresh|techdebt)$
```

User turns that contain no `<command-name>` block (free-form chat turns) SHALL NOT match — even if their content text incidentally contains the substring `/analyse`, `/claudboard:claudboard-generate`, or any of the other task tokens.

User turns whose `<command-name>` block is for a non-claudboard slash command (e.g. `/openspec-explore`, `/opsx:archive`) SHALL NOT match — even if the same turn's `<command-args>` body, or any appended skill prompt, mentions a claudboard task token.

The captured `verb` SHALL be passed to `compute-cost.sh --task` verbatim (always the bare verb `analyse`, `generate`, `refresh`, or `techdebt`), so the cost-emission path remains identical for bare and plugin-namespaced invocations.

#### Scenario: Plugin-namespaced slash form fires the hook
- **WHEN** a session JSONL contains a user turn whose `.message.content` contains the standard slash-invocation wrapper `<command-message>claudboard-analyse</command-message>\n<command-name>/claudboard:claudboard-analyse</command-name>\n<command-args>...</command-args>`
- **THEN** the hook emits a cost line tagged with task `analyse` (not `claudboard-analyse`, not `claudboard:claudboard-analyse`)

#### Scenario: Free-text chat that quotes a trigger token does NOT fire the hook
- **WHEN** a session JSONL contains a user turn whose `.message.content` is free-form chat such as `"the change matched /analyse instead of /claudboard:claudboard-analyse"` or `"why isn't /generate working"` — with no `<command-name>` wrapper anywhere in the turn
- **THEN** the hook exits silently with no cost line emitted

#### Scenario: Non-claudboard slash command whose args mention trigger tokens does NOT fire the hook
- **WHEN** a session JSONL contains a user turn whose `<command-name>` is `/openspec-explore` and whose `<command-args>` body mentions `/analyse` or `/claudboard:claudboard-generate`
- **THEN** the hook exits silently with no cost line emitted

#### Scenario: All four task verbs in the plugin-namespaced form are recognised
- **WHEN** the hook is invoked against fixtures containing each of `<command-name>/claudboard:claudboard-analyse</command-name>`, `<command-name>/claudboard:claudboard-generate</command-name>`, `<command-name>/claudboard:claudboard-refresh</command-name>`, `<command-name>/claudboard:claudboard-techdebt</command-name>`
- **THEN** every fixture produces a cost line and the task name in each line is the bare verb (`analyse`, `generate`, `refresh`, `techdebt` respectively)

#### Scenario: Most recent valid trigger in the session is the one reported
- **WHEN** a session JSONL contains two valid wrapped triggers (e.g. a `<command-name>/claudboard:claudboard-analyse</command-name>` turn followed later by a `<command-name>/claudboard:claudboard-generate</command-name>` turn)
- **THEN** the hook reports cost for the most recent trigger (`/generate` in this example) using its trigger timestamp as the `--since` lower bound

---

## ADDED Requirements

### Requirement: Hook SHALL emit a cost line at most once per (sessionId, triggerTimestamp)

After identifying the latest valid trigger in the session JSONL (sessionId `S`, triggerTimestamp `T`, verb `C`), the Stop hook SHALL consult a sidecar marker file at:

```
~/.claude/projects/<cwd-slug>/.claudboard-cost-emitted/<S>__<T>.marker
```

where `<cwd-slug>` is the same slug Claude Code uses for the session JSONL directory (the result of `pwd | sed 's|/|-|g'`).

- IF the marker file exists, the hook SHALL exit silently with no cost line emitted.
- ELSE the hook SHALL compute and emit the cost line, then write the marker file with the emitted cost line as its contents.

Marker-write failures (e.g. read-only home, full filesystem) SHALL NOT cause the hook to exit non-zero; the hook SHALL degrade gracefully to emitting on every Stop event for the affected pathological session.

The hook SHALL NOT delete or rotate marker files; accumulation is acceptable.

#### Scenario: First Stop after a real trigger emits the cost line and writes the marker
- **WHEN** a session JSONL contains exactly one valid `<command-name>/claudboard:claudboard-analyse</command-name>` trigger turn at timestamp `T`, and the marker file `~/.claude/projects/<cwd-slug>/.claudboard-cost-emitted/<sessionId>__<T>.marker` does not yet exist when the hook fires
- **THEN** the hook emits one cost line tagged `analyse` to stdout AND the marker file is created on disk with the emitted cost line as its contents

#### Scenario: Subsequent Stop in the same session for the same trigger is silent
- **WHEN** the same session JSONL is processed by the hook a second time (e.g. simulating a second Stop event after a mid-task user confirmation turn) and the marker file from the first emission already exists
- **THEN** the hook exits silently with no cost line emitted, and the marker file is left unchanged

#### Scenario: A second distinct trigger in the same session gets its own cost line
- **WHEN** a session JSONL contains a `<command-name>/claudboard:claudboard-analyse</command-name>` trigger at timestamp `T1` (already reported, marker exists) followed by a later `<command-name>/claudboard:claudboard-generate</command-name>` trigger at timestamp `T2`, and the marker for `T2` does not yet exist when the hook fires
- **THEN** the hook emits one cost line tagged `generate` and creates a second marker file keyed on `T2`

#### Scenario: Marker write failure does not break the hook
- **WHEN** the marker directory cannot be created or written (e.g. read-only `$HOME`)
- **THEN** the hook still emits its cost line to stdout (or degrades to emitting on every Stop for that session, matching pre-fix behavior) and exits zero

---

### Requirement: Test fixtures SHALL cover free-text false-positives and repeat-Stop emit-once semantics

The test suite (`skills/claudboard/scripts/tests/`) SHALL include fixtures and assertions that pin the two regression classes addressed by this change:

1. A **negative-case fixture** containing only free-form chat user turns that incidentally mention trigger tokens such as `/analyse`, `/claudboard:claudboard-generate`. The hook test runner SHALL assert that processing this fixture produces no cost line on stdout.

2. A **multi-stop fixture** containing one real wrapped trigger followed by at least one additional non-trigger user turn (mid-task confirmation simulation). The hook test runner SHALL invoke the hook against this fixture twice in succession and assert that the first invocation produces a cost line and the second invocation is silent.

Each test case in `tests/hook-run.sh` that exercises the marker logic SHALL run with an isolated marker directory (e.g. by pointing `$HOME` at a per-case temp dir) so test cases do not pollute each other's marker state. The repeat-invocation assertion SHALL intentionally NOT reset the marker dir between its two hook invocations.

Existing fixtures whose user-turn `.message.content` uses the unrealistic bare `"/analyse"` / `"/generate"` form SHALL be reshaped to the realistic wrapped form (`[{"type":"text","text":"<command-message>...</command-message>\n<command-name>/claudboard:claudboard-{verb}</command-name>\n<command-args></command-args>"}]`) so they continue to be exercised by the strict regex.

#### Scenario: Chat-mentions fixture asserts silent hook
- **WHEN** `tests/hook-run.sh` invokes `stop-hook.sh` with `chat-mentions-trigger.jsonl` as the session JSONL
- **THEN** stdout is empty and the test reports PASS

#### Scenario: Multi-stop fixture asserts emit-then-silent
- **WHEN** `tests/hook-run.sh` invokes `stop-hook.sh` twice in succession with `multi-stop-single-trigger.jsonl` as the session JSONL, sharing the same isolated `$HOME`
- **THEN** the first invocation emits a cost line tagged `analyse` AND the second invocation produces empty stdout

#### Scenario: Reshaped legacy fixtures still produce expected cost lines
- **WHEN** `tests/hook-run.sh` runs the existing single-task-opus / mixed-models / topology-paused / unknown-model assertions after the fixtures have been reshaped to the wrapped form
- **THEN** every existing assertion still passes with the same expected cost-line strings (the assistant-turn usage data is unchanged; only the shape of the user-turn content block changes)
