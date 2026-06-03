## Why

The per-task cost line introduced by the archived `per-run-cost-reporting` change has never fired for a single plugin-installed user. Two latent bugs block it: (1) `skills/claudboard/scripts/stop-hook.sh:50,52` only matches the bare slash forms (`/analyse`, `/generate`, `/refresh`, `/techdebt`), so the plugin-namespaced invocations users actually type (`/claudboard:claudboard-analyse`, etc.) silently exit 0; and (2) the plugin ships no `hooks/hooks.json`, so Claude Code never registers the Stop hook in the first place — the install instructions live only as a comment block inside the script itself, and plugin users have no realistic path to discover and apply them. The result is that the headline UX of the prior change ("see what each task cost") is invisible to its intended audience.

## What Changes

- **NEW** `hooks/hooks.json` at the plugin root — declares a `Stop` event hook pointing at `${CLAUDE_PLUGIN_ROOT}/skills/claudboard/scripts/stop-hook.sh`. Claude Code auto-activates this when the plugin is installed; no user settings edit required.
- **MODIFIED** `skills/claudboard/scripts/stop-hook.sh` — widens the trigger regex from `/(?:analyse|generate|refresh|techdebt)\b` to `/(?:claudboard:claudboard-)?(?:analyse|generate|refresh|techdebt)\b` so both the bare and plugin-namespaced slash forms match. The capture group is normalised so `$TRIGGER_CMD` is always the bare verb (`analyse`/`generate`/`refresh`/`techdebt`) before being passed to `compute-cost.sh --task`. The stale "Installation (in .claude/settings.json …)" comment block at the top of the script (lines ~12-18) is removed.
- **MODIFIED** `README.md` — adds a short note that plugin installs emit a per-task cost summary at the end of each `/claudboard:*` task automatically. The previous "copy-pasteable settings.json block" section (introduced by the archived per-run-cost-reporting change) is removed or marked as legacy — manual install is no longer the supported path.
- **NEW** `skills/claudboard/scripts/tests/namespaced-trigger.jsonl` — a fixture JSONL with a `/claudboard:claudboard-analyse` user turn (mirroring the existing `single-task-opus.jsonl` shape) so the widened regex is regression-tested.
- **MODIFIED** `skills/claudboard/scripts/tests/run.sh` and `tests/hook-run.sh` — exercise the new fixture and assert a non-empty cost line is emitted (mirrors the existing positive-case assertion).

Out of scope:
- Any change to `compute-cost.sh` or the per-model pricing table.
- Any change to feature-workflow per-phase cost ticks (live-per-phase-cost-tally already shipped that path).
- Source-repo `/analyse` invocation (plugin is not intended to run from the source repo — explicitly dropped).
- Backporting to plugin versions already installed (`4.0.0-beta.2` and earlier stay as-is; the hook arrives in the next published version).

## Capabilities

### New Capabilities
- `cost-reporting`: per-task cost emission via a plugin-registered Stop hook, scoped to claudboard task slash commands in both bare and plugin-namespaced forms. (This capability was authored in the archived `per-run-cost-reporting` change but its delta spec was never synced into `openspec/specs/`; this change introduces it as a new synced capability with the requirements that materially differ from the archived design.)

### Modified Capabilities
None.

## Impact

- **Affected files (new):**
  - `hooks/hooks.json`
  - `skills/claudboard/scripts/tests/namespaced-trigger.jsonl`
- **Affected files (modified):**
  - `skills/claudboard/scripts/stop-hook.sh` (regex + capture normalisation + comment-block removal)
  - `skills/claudboard/scripts/tests/run.sh` and/or `tests/hook-run.sh` (new fixture wired in)
  - `README.md` (new auto-install note; old manual-install block removed or marked legacy)
- **Affected files (unchanged):**
  - `skills/claudboard/scripts/compute-cost.sh`
  - `.claude-plugin/plugin.json` (no `hooks` field is needed — the plugin spec uses `hooks/hooks.json` at the plugin root, separate from `plugin.json`)
  - All sub-skill SKILL.md files
  - All feature-workflow template files (the live per-phase cost path is orchestrator-driven, not hook-driven)
- **User-visible effect:** After the next plugin publish, fresh installs and updates of `claudboard` will see one cost line of the form `Task /analyse — $X.XX (Y model calls)` at the end of each `/claudboard:claudboard-{analyse,generate,refresh,techdebt}` run, with no user-side configuration step.
- **Cost of the change at runtime:** $0 additional API tokens — the hook is a bash script that reads the local session JSONL.
- **Risks:**
  - *Regex drift across Claude Code releases*: if Anthropic changes how plugin-namespaced slash commands appear in the user-turn JSONL text, the regex will silently stop matching. Mitigation: the new test fixture pins the current observed format; a CI run against the fixture catches regressions before publish.
  - *Hook registration silently failing*: if the `hooks/hooks.json` schema changes or the `${CLAUDE_PLUGIN_ROOT}` substitution breaks, no error surfaces to the user — they just see no cost line. Mitigation: add a one-line manual verification step to the README ("if you don't see a cost line after a `/claudboard:*` task, check `claude --debug` for hook errors").
  - *Existing already-installed users*: out of scope by design; users on `4.0.0-beta.2` and earlier will not see cost lines until they update.
