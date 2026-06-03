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

### Requirement: Trigger regex SHALL match both bare and plugin-namespaced slash forms

The Stop hook's trigger-detection regex SHALL match any of the following user-turn text patterns and emit a cost line for the matched task:
- `/analyse`, `/generate`, `/refresh`, `/techdebt` (bare forms, retained for source-repo use)
- `/claudboard:claudboard-analyse`, `/claudboard:claudboard-generate`, `/claudboard:claudboard-refresh`, `/claudboard:claudboard-techdebt` (plugin-namespaced forms)

The regex pattern SHALL be `/(?:claudboard:claudboard-)?(?:analyse|generate|refresh|techdebt)\b` with the anchor positioned to match anywhere in the user-turn content (not only at content start), so the wrapped `<command-name>/claudboard:claudboard-{verb}</command-name>` form that Claude Code records for plugin invocations is matched.

The captured task name SHALL be normalised to the bare verb (`analyse`, `generate`, `refresh`, or `techdebt`) before being passed to `compute-cost.sh --task`, so the cost-emission path is identical regardless of which slash form the user typed.

#### Scenario: Bare slash form fires the hook
- **WHEN** a session JSONL contains a user turn whose text begins with `/analyse <args>`
- **THEN** the hook emits a cost line tagged with task `analyse`

#### Scenario: Plugin-namespaced slash form fires the hook
- **WHEN** a session JSONL contains a user turn whose text contains `<command-name>/claudboard:claudboard-analyse</command-name>` as part of the standard slash-invocation wrapper
- **THEN** the hook emits a cost line tagged with task `analyse` (not `claudboard-analyse` or `claudboard:claudboard-analyse`)

#### Scenario: Non-claudboard slash command does not fire the hook
- **WHEN** a session JSONL contains a user turn for `/openspec-explore` or `/opsx:archive` or any other unrelated slash command, and contains no claudboard trigger
- **THEN** the hook exits silently with no cost line emitted

#### Scenario: All four task verbs in either form are recognised
- **WHEN** the hook is invoked against fixtures for each of the eight combinations (`/analyse`, `/generate`, `/refresh`, `/techdebt`, `/claudboard:claudboard-analyse`, `/claudboard:claudboard-generate`, `/claudboard:claudboard-refresh`, `/claudboard:claudboard-techdebt`)
- **THEN** every fixture produces a cost line and the task name in each line is the bare verb

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
