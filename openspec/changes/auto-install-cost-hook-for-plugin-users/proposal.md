## Why

The per-task cost line introduced by the archived `per-run-cost-reporting` change has never fired for a single plugin-installed user. **Four** latent bugs block it (the original two diagnosed in this proposal plus two more uncovered during the 2026-06-04 attempt to verify acceptance tasks 7.2–7.4 on craftsphere.cloud at plugin version `4.0.0-beta.9`):

1. `skills/claudboard/scripts/stop-hook.sh` only matched the bare slash forms (`/analyse`, `/generate`, `/refresh`, `/techdebt`), so the plugin-namespaced invocations users actually type (`/claudboard:claudboard-analyse`, etc.) silently exit 0. *(Fixed in this proposal's section 2 — verified to work via manual env-var invocation, but never reached in production due to bug 3.)*
2. The plugin ships no `hooks/hooks.json`, so Claude Code never registers the Stop hook in the first place — the install instructions live only as a comment block inside the script itself, and plugin users have no realistic path to discover and apply them. *(Fixed in this proposal's section 1.)*
3. **NEW (2026-06-04):** `stop-hook.sh` reads the session JSONL path from `$CLAUDE_SESSION_JSONL` / `$CLAUDE_CODE_SESSION_ID` env vars and silently `exit 0`s if neither is set. Claude Code's plugin hook runner does **not** set these env vars — it passes a JSON payload on **stdin** containing `transcript_path`, per the documented Stop-hook contract at code.claude.com/docs/en/hooks.md#common-input-fields. The script never reads stdin, so it always exits before the trigger-scan logic. This is why the marker dir `.claudboard-cost-emitted/` was never created on craftsphere.cloud despite the hook file shipping in `4.0.0-beta.9` and the regex+manual-replay both being correct.
4. **NEW (2026-06-04):** `/claudboard:claudboard-workflow` was excluded from the trigger regex by oversight. Users running the workflow generator see no cost line because the verb `workflow` is not in the alternation list, and the workflow orchestrator (unlike the *generated* feature-workflow) has no per-phase cost ticks of its own.

The result: the headline UX of the prior change ("see what each task cost") remains invisible to its intended audience.

## What Changes

- **NEW** `hooks/hooks.json` at the plugin root — declares a `Stop` event hook pointing at `${CLAUDE_PLUGIN_ROOT}/skills/claudboard/scripts/stop-hook.sh`. Claude Code auto-activates this when the plugin is installed; no user settings edit required.
- **MODIFIED** `skills/claudboard/scripts/stop-hook.sh` — three changes, in order of priority:
  1. **(new, bug 3)** Read the Stop-hook stdin payload before falling back to env vars. The script SHALL `cat` stdin, parse `.transcript_path` via `jq`, and use that as `JSONL_PATH` if present. The existing `$CLAUDE_SESSION_JSONL` and constructed-path branches remain as fallbacks for SDK / manual invocation. Without this, the script silently exits 0 in every real Claude Code Stop event.
  2. **(original, bug 1)** Widen the trigger regex from `/(?:analyse|generate|refresh|techdebt)\b` to `/(?:claudboard:claudboard-)?(?:analyse|generate|refresh|techdebt|workflow)\b` so all of (a) bare forms, (b) plugin-namespaced forms, and (c) the previously-omitted `workflow` verb match. The capture group is normalised so `$TRIGGER_CMD` is always the bare verb (`analyse`/`generate`/`refresh`/`techdebt`/`workflow`) before being passed to `compute-cost.sh --task`.
  3. The stale "Installation (in .claude/settings.json …)" comment block at the top of the script (lines ~12-18) is removed.
- **MODIFIED** `README.md` — adds a short note that plugin installs emit a per-task cost summary at the end of each `/claudboard:*` task automatically. The previous "copy-pasteable settings.json block" section (introduced by the archived per-run-cost-reporting change) is removed or marked as legacy — manual install is no longer the supported path.
- **NEW** `skills/claudboard/scripts/tests/namespaced-trigger.jsonl` — a fixture JSONL with a `/claudboard:claudboard-analyse` user turn (mirroring the existing `single-task-opus.jsonl` shape) so the widened regex is regression-tested.
- **NEW** `skills/claudboard/scripts/tests/namespaced-workflow.jsonl` — a fixture JSONL with a `/claudboard:claudboard-workflow` user turn so the workflow verb coverage is pinned.
- **MODIFIED** `skills/claudboard/scripts/tests/run.sh` and `tests/hook-run.sh` — add **two** new assertion modes:
  1. **stdin-mode assertion (closes the bug 3 detection gap):** invoke `stop-hook.sh` with the Claude Code hook payload (`{"transcript_path":"...","hook_event_name":"Stop"}`) piped to stdin while explicitly unsetting `CLAUDE_SESSION_JSONL` and `CLAUDE_CODE_SESSION_ID` (e.g. via `env -u`). Assert the cost line is still emitted. Without this assertion any future stdin-path regression is invisible to CI — exactly how the original change shipped broken.
  2. **per-verb assertions** for `namespaced-trigger.jsonl` and `namespaced-workflow.jsonl` covering both env-var and stdin invocation modes.

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
  - `skills/claudboard/scripts/tests/namespaced-workflow.jsonl`
- **Affected files (modified):**
  - `skills/claudboard/scripts/stop-hook.sh` (stdin payload read + widened regex with `workflow` verb + capture normalisation + comment-block removal)
  - `skills/claudboard/scripts/tests/run.sh` and/or `tests/hook-run.sh` (new fixtures wired in; stdin-mode assertions added that explicitly unset env vars)
  - `README.md` (new auto-install note; old manual-install block removed or marked legacy)
- **Affected files (unchanged):**
  - `skills/claudboard/scripts/compute-cost.sh`
  - `.claude-plugin/plugin.json` (no `hooks` field is needed — the plugin spec uses `hooks/hooks.json` at the plugin root, separate from `plugin.json`)
  - All sub-skill SKILL.md files
  - All feature-workflow template files (the live per-phase cost path is orchestrator-driven, not hook-driven)
- **User-visible effect:** After the next plugin publish, fresh installs and updates of `claudboard` will see one cost line of the form `Cost for /<verb>: $X.XX (...)` at the end of each `/claudboard:claudboard-{analyse,generate,refresh,techdebt,workflow}` run, with no user-side configuration step.
- **Cost of the change at runtime:** $0 additional API tokens — the hook is a bash script that reads the local session JSONL.
- **Risks:**
  - *Regex drift across Claude Code releases*: if Anthropic changes how plugin-namespaced slash commands appear in the user-turn JSONL text, the regex will silently stop matching. Mitigation: the new test fixture pins the current observed format; a CI run against the fixture catches regressions before publish.
  - *Hook registration silently failing*: if the `hooks/hooks.json` schema changes or the `${CLAUDE_PLUGIN_ROOT}` substitution breaks, no error surfaces to the user — they just see no cost line. Mitigation: add a one-line manual verification step to the README ("if you don't see a cost line after a `/claudboard:*` task, check `claude --debug` for hook errors").
  - *Existing already-installed users*: out of scope by design; users on `4.0.0-beta.2` and earlier will not see cost lines until they update.
