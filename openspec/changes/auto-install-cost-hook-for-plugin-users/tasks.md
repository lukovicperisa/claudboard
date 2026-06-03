## 1. Plugin-level hook registration

- [x] 1.1 Create `hooks/hooks.json` at the repo root with a `Stop` event entry whose `command` is `${CLAUDE_PLUGIN_ROOT}/skills/claudboard/scripts/stop-hook.sh` and whose `matcher` is `""` (fire on every Stop)
- [x] 1.2 Verify the JSON parses cleanly with `python3 -m json.tool hooks/hooks.json`
- [x] 1.3 Verify the path resolves to the existing script when `CLAUDE_PLUGIN_ROOT` is substituted with the repo root (sanity check via `ls "$(pwd)/skills/claudboard/scripts/stop-hook.sh"`)

## 2. Trigger regex — widen and normalise

- [x] 2.1 In `skills/claudboard/scripts/stop-hook.sh`, change the `jq` `test()` regex from `^[[:space:]]*/(?:analyse|generate|refresh|techdebt)\b` to `/(?:claudboard:claudboard-)?(?:analyse|generate|refresh|techdebt)\b` (drop the line-start anchor; add the optional namespace prefix)
- [x] 2.2 In the same `capture()` call, change the `<c>` named capture group from `(?<c>analyse|generate|refresh|techdebt)` to extract just the bare verb after an optional `claudboard:claudboard-` prefix — pattern: `(?:claudboard:claudboard-)?(?<c>analyse|generate|refresh|techdebt)\b`
- [x] 2.3 Confirm `$TRIGGER_CMD` after the jq pipeline is always one of `analyse`/`generate`/`refresh`/`techdebt` regardless of input form (no `claudboard-` or `claudboard:claudboard-` prefix leaks through)
- [x] 2.4 Run the existing positive-case fixture (`single-task-opus.jsonl`) through the modified script and confirm output is unchanged from before the change

## 3. Stale comment-block removal

- [x] 3.1 Delete lines 12-18 of `stop-hook.sh` (the "Installation (in .claude/settings.json or settings.local.json):" comment block)
- [x] 3.2 Confirm the script's remaining header comment still correctly describes the runtime behaviour ("Fires on every Stop event. Scans the session JSONL …")
- [x] 3.3 Confirm `shellcheck stop-hook.sh` (or equivalent) does not regress

## 4. Test fixture for namespaced form

- [x] 4.1 Create `skills/claudboard/scripts/tests/namespaced-trigger.jsonl` modelled on `single-task-opus.jsonl` but with one user turn whose `.message.content[0].text` contains the literal wrapped form:
  ```
  <command-message>claudboard-analyse</command-message>
  <command-name>/claudboard:claudboard-analyse</command-name>
  <command-args>...</command-args>
  ```
  followed by enough assistant turns with `usage` fields that `compute-cost.sh` produces a non-empty cost line (mirror the existing fixture's turn count and shape)
- [x] 4.2 Verify by hand: `bash skills/claudboard/scripts/stop-hook.sh` with `CLAUDE_SESSION_JSONL=skills/claudboard/scripts/tests/namespaced-trigger.jsonl` emits one non-empty cost line whose task tag is `analyse`

## 5. Test runner — wire in the new fixture

- [x] 5.1 Open `skills/claudboard/scripts/tests/run.sh` (or `tests/hook-run.sh` if that's the active runner — pick the one already invoked by the test suite) and add an assertion block that invokes `stop-hook.sh` against `namespaced-trigger.jsonl` and asserts the output is non-empty and contains the substring ` analyse ` or `Task analyse` (whatever the cost-line format uses today — verify against existing `single-task-opus.jsonl` output)
- [x] 5.2 Confirm the existing fixtures still pass after the regex change (`no-trigger.jsonl`, `topology-paused.jsonl`, `unknown-model.jsonl`, `mixed-models.jsonl`, `single-task-opus.jsonl`)
- [x] 5.3 Run the full test suite and capture pass/fail counts; all should pass

## 6. README

- [x] 6.1 Open `README.md` and locate the per-task cost reporting section introduced by the archived `per-run-cost-reporting` change
- [x] 6.2 Replace the "Installation" subsection (the copy-pasteable `settings.json` block) with a one-paragraph "Automatic" statement: cost line appears after each `/claudboard:*` task on plugin install, no setup required
- [x] 6.3 Add a single troubleshooting line: "If you don't see a cost line, run `claude --debug` and look for hook errors"
- [x] 6.4 Preserve the existing explanation of what the cost line means and the example output line — only the install path changes
- [x] 6.5 Skim the README for any other reference to the manual-install path and remove or update as needed

## 7. End-to-end acceptance (manual, post-merge, pre-publish)

- [x] 7.1 Bump the plugin version in `.claude-plugin/plugin.json` per the existing version-bump convention (next beta after `4.0.0-beta.3`)
- [ ] 7.2 In a scratch directory with claudboard installed via the local marketplace at the new version, run `/claudboard:claudboard-analyse` against a small fixture repo; observe one cost line appears at task end with no settings.json edit
- [ ] 7.3 Run `/claudboard:claudboard-generate` in the same session immediately after; observe a second distinct cost line, slice starts at the `/generate` prompt timestamp (not accumulating with the first)
- [ ] 7.4 In a separate session, confirm a non-claudboard task (e.g., `/openspec-explore`) produces no cost line
- [ ] 7.5 If 7.2-7.4 all pass: commit and tag for publish. If any fail: capture `claude --debug` output and iterate on the regex or the `hooks.json` schema
