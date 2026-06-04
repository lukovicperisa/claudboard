## ADDED Requirements

### Requirement: Stop hook SHALL be auto-registered for plugin installs via `hooks/hooks.json`

The plugin distribution SHALL include a `hooks/hooks.json` file at the plugin root that registers a `Stop` event hook pointing at `${CLAUDE_PLUGIN_ROOT}/skills/claudboard/scripts/stop-hook.sh`. Claude Code SHALL activate this hook on plugin install and on every subsequent update without requiring the user to edit `.claude/settings.json` or any other configuration file.

The `command` field SHALL use the `${CLAUDE_PLUGIN_ROOT}` substitution variable rather than any hardcoded path, so the hook continues to fire after plugin version upgrades that change the install directory.

#### Scenario: Fresh plugin install activates the cost hook
- **WHEN** a user installs the claudboard plugin for the first time and runs `/claudboard:claudboard-analyse` in a fresh session
- **THEN** the Stop hook fires at the end of the task and the cost line appears in the session transcript, with no user-side configuration step performed between install and invocation

#### Scenario: Plugin update preserves hook activation
- **WHEN** a user updates an installed claudboard plugin from one version to the next and runs `/claudboard:claudboard-analyse` after the update
- **THEN** the hook continues to fire from the new version's installed path, with no user-side reinstallation step

#### Scenario: Manual settings.json edit is no longer required
- **WHEN** a user inspects their `.claude/settings.json` and `.claude/settings.local.json` after a plugin install
- **THEN** neither file contains any claudboard-specific hook entry; the hook activation derives entirely from the plugin's `hooks/hooks.json`

---

### Requirement: Trigger regex SHALL match both bare and plugin-namespaced slash forms, including the `workflow` verb

The Stop hook's trigger-detection regex SHALL match any of the following user-turn text patterns and emit a cost line for the matched task:
- `/analyse`, `/generate`, `/refresh`, `/techdebt`, `/workflow` (bare forms, retained for source-repo use)
- `/claudboard:claudboard-analyse`, `/claudboard:claudboard-generate`, `/claudboard:claudboard-refresh`, `/claudboard:claudboard-techdebt`, `/claudboard:claudboard-workflow` (plugin-namespaced forms)

The regex pattern SHALL be `/(?:claudboard:claudboard-)?(?:analyse|generate|refresh|techdebt|workflow)\b` with the anchor positioned to match anywhere in the user-turn content (not only at content start), so the wrapped `<command-name>/claudboard:claudboard-{verb}</command-name>` form that Claude Code records for plugin invocations is matched.

The captured task name SHALL be normalised to the bare verb (`analyse`, `generate`, `refresh`, `techdebt`, or `workflow`) before being passed to `compute-cost.sh --task`, so the cost-emission path is identical regardless of which slash form the user typed.

Any future user-facing claudboard slash command added to the dispatcher SHALL be added to this regex's verb alternation in the same change set; the per-verb test assertions (see "stdin-mode test fixtures" requirement below) enforce that no verb-coverage gap survives CI.

#### Scenario: Bare slash form fires the hook
- **WHEN** a session JSONL contains a user turn whose text begins with `/analyse <args>`
- **THEN** the hook emits a cost line tagged with task `analyse`

#### Scenario: Plugin-namespaced slash form fires the hook
- **WHEN** a session JSONL contains a user turn whose text contains `<command-name>/claudboard:claudboard-analyse</command-name>` as part of the standard slash-invocation wrapper
- **THEN** the hook emits a cost line tagged with task `analyse` (not `claudboard-analyse` or `claudboard:claudboard-analyse`)

#### Scenario: Non-claudboard slash command does not fire the hook
- **WHEN** a session JSONL contains a user turn for `/openspec-explore` or `/opsx:archive` or any other unrelated slash command, and contains no claudboard trigger
- **THEN** the hook exits silently with no cost line emitted

#### Scenario: All five task verbs in either form are recognised
- **WHEN** the hook is invoked against fixtures for each of the ten combinations (`/analyse`, `/generate`, `/refresh`, `/techdebt`, `/workflow`, `/claudboard:claudboard-analyse`, `/claudboard:claudboard-generate`, `/claudboard:claudboard-refresh`, `/claudboard:claudboard-techdebt`, `/claudboard:claudboard-workflow`)
- **THEN** every fixture produces a cost line and the task name in each line is the bare verb

#### Scenario: `/claudboard:claudboard-workflow` produces a cost line
- **WHEN** a session JSONL contains a user turn whose text contains `<command-name>/claudboard:claudboard-workflow</command-name>` as part of the standard slash-invocation wrapper
- **THEN** the hook emits a cost line tagged with task `workflow` (not `claudboard-workflow` or any prefix variant)

---

### Requirement: A test fixture SHALL pin the plugin-namespaced JSONL wrapper format

The test suite SHALL include a fixture file (`skills/claudboard/scripts/tests/namespaced-trigger.jsonl`) that contains a user turn matching the exact wrapped slash-invocation format Claude Code records for plugin commands today:

```
<command-message>claudboard-analyse</command-message>
<command-name>/claudboard:claudboard-analyse</command-name>
<command-args>...</command-args>
```

The test runner SHALL invoke `stop-hook.sh` against this fixture as part of `tests/run.sh` and assert a non-empty cost line is emitted. If a future Claude Code release changes the wrapper format, this assertion SHALL fail, surfacing the regression before publish.

#### Scenario: Fixture exercises the namespaced regex path
- **WHEN** `tests/run.sh` invokes `stop-hook.sh` with `namespaced-trigger.jsonl` as the session JSONL
- **THEN** stdout contains exactly one non-empty cost line whose task tag is the bare verb `analyse`

#### Scenario: Fixture failure halts release
- **WHEN** any change to Claude Code's wrapper format causes the regex to no longer match the fixture
- **THEN** `tests/run.sh` exits non-zero and the change is blocked from publish until the regex (and/or the fixture) is updated

---

### Requirement: Manual hook-install documentation SHALL be removed from the source-of-truth script and replaced with an automatic-install note in the README

The "Installation (in .claude/settings.json or settings.local.json):" comment block in `skills/claudboard/scripts/stop-hook.sh` (currently lines 12-18) SHALL be removed. The `README.md` "Per-task cost reporting" section SHALL replace its "Installation" subsection with a one-paragraph statement that plugin installs activate the hook automatically, plus a one-line troubleshooting hint pointing at `claude --debug` for users who do not see the expected cost line.

The source-repo manual-install workflow SHALL NOT be documented as a supported path. Source-repo contributors who want the cost line locally can invoke `compute-cost.sh` directly against a session JSONL.

#### Scenario: stop-hook.sh has no stale install instructions
- **WHEN** a reader opens `stop-hook.sh`
- **THEN** there is no comment block describing manual `settings.json` wiring

#### Scenario: README explains automatic activation
- **WHEN** a user reads the README's cost-reporting section
- **THEN** the section states that the cost line appears automatically after each `/claudboard:*` task on plugin installs, with no setup step required, and includes a single troubleshooting hint for when it fails to appear

---

### Requirement: Stop hook SHALL resolve the session JSONL path from the stdin payload that Claude Code provides, with env-var fallbacks for SDK and manual invocation

The Stop hook script SHALL read the JSON payload that Claude Code's hook runner pipes to stdin and SHALL extract the `transcript_path` field from it. When `transcript_path` is present and non-empty, the script SHALL use that absolute path as the session JSONL to analyse — this is the canonical Claude Code Stop-hook input contract (code.claude.com/docs/en/hooks.md#common-input-fields).

The script SHALL preserve, as fallbacks after the stdin path, the existing env-var resolution order: (i) `$CLAUDE_SESSION_JSONL`, then (ii) `$CLAUDE_CODE_SESSION_ID` plus a constructed `~/.claude/projects/<cwd-slug>/<sid>.jsonl` path. These fallbacks SHALL continue to function for SDK invocations that pre-populate env vars and for manual replay during development.

The script SHALL NOT silently `exit 0` when both stdin and env vars are empty without first making the stdin extraction attempt; the prior bug (stdin-never-read + env-vars-also-empty → silent exit) is exactly the failure mode this requirement closes.

#### Scenario: Real Claude Code Stop event uses stdin payload
- **WHEN** Claude Code fires a Stop event and pipes `{"transcript_path":"/abs/path/session.jsonl","session_id":"...","hook_event_name":"Stop", ...}` to the hook script's stdin, with NO `CLAUDE_SESSION_JSONL` or `CLAUDE_CODE_SESSION_ID` env vars set
- **THEN** the script reads stdin, extracts `.transcript_path`, parses that JSONL, and emits the cost line; the marker file `~/.claude/projects/<cwd-slug>/.claudboard-cost-emitted/<sid>__<ts>.marker` is written

#### Scenario: SDK invocation with env-var path still works
- **WHEN** the script is invoked with `CLAUDE_SESSION_JSONL=/abs/path/session.jsonl bash stop-hook.sh` and empty stdin
- **THEN** the script uses the env-var path and emits the cost line unchanged from prior behaviour

#### Scenario: stdin takes precedence over env vars
- **WHEN** the script is invoked with BOTH a stdin payload pointing at `A.jsonl` AND `CLAUDE_SESSION_JSONL=B.jsonl`
- **THEN** the script analyses `A.jsonl` (the stdin source wins)

#### Scenario: Empty stdin and empty env vars exits silently
- **WHEN** the script is invoked with no stdin payload and neither env var set
- **THEN** the script exits 0 with no output (no error, no false-positive cost line, no marker file)

---

### Requirement: Test suite SHALL include stdin-mode assertions that explicitly unset the env vars before invoking the hook

The test runner (`tests/run.sh` and/or `tests/hook-run.sh`) SHALL include assertion blocks that pipe a Claude Code-shaped hook payload (`{"transcript_path":"<abs-path-to-fixture>","hook_event_name":"Stop"}`) to `stop-hook.sh` via stdin WHILE explicitly removing `CLAUDE_SESSION_JSONL` and `CLAUDE_CODE_SESSION_ID` from the script's environment (e.g. via `env -u CLAUDE_SESSION_JSONL -u CLAUDE_CODE_SESSION_ID`). This is the only test mode that exercises the production input channel.

The stdin-mode assertion SHALL cover at minimum: `single-task-opus.jsonl`, `namespaced-trigger.jsonl`, and `namespaced-workflow.jsonl`. The pre-existing env-var-mode assertions SHALL remain; both modes are required to pass.

The test suite SHALL also include a fixture `skills/claudboard/scripts/tests/namespaced-workflow.jsonl` modelled on `namespaced-trigger.jsonl` but with the user turn containing `<command-name>/claudboard:claudboard-workflow</command-name>`, exercising the workflow verb coverage.

#### Scenario: stdin-mode assertion catches regression of stdin-path code
- **WHEN** a change to `stop-hook.sh` removes or breaks the stdin-payload-reading logic
- **THEN** the `env -u … bash stop-hook.sh` stdin-mode assertion fails (because env vars are unset and stdin is now ignored), blocking the change from publish

#### Scenario: Workflow fixture exercises the new verb
- **WHEN** `tests/run.sh` invokes the hook against `namespaced-workflow.jsonl` in either env-var mode or stdin mode
- **THEN** stdout contains one non-empty cost line tagged with task `workflow`

#### Scenario: Both modes must pass
- **WHEN** the test suite runs against any fixture
- **THEN** both the env-var-mode assertion AND the stdin-mode assertion must succeed for the suite to pass; a regression in either mode fails CI
