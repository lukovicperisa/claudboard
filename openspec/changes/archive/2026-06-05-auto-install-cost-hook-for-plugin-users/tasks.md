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

> **2026-06-04 verification result:** Tasks 7.2–7.4 were attempted on craftsphere.cloud at `4.0.0-beta.9`. All three failed — no cost line appeared for `/analyse`, `/generate`, or `/workflow`. Root cause traced to the stdin-contract gap (section 8) and the missing `workflow` verb (section 9). Re-run 7.2–7.4 after sections 8–10 land.

## 8. stdin contract fix (bug 3, primary)

- [ ] 8.1 At the top of `stop-hook.sh`, before any JSONL-path resolution, capture stdin: `HOOK_INPUT=$(cat 2>/dev/null || true)`. Stdin may be empty in non-hook invocations (manual testing, SDK with env vars) — empty stdin must not error.
- [ ] 8.2 Attempt to parse `.transcript_path` from `HOOK_INPUT` via `jq -r '.transcript_path // empty'` (route stderr to `/dev/null`; treat `null`/empty as "not present"). If parsing yields a non-empty value, use that as `JSONL_PATH`.
- [ ] 8.3 Preserve the existing precedence chain as fallbacks **after** the stdin path: (i) `$CLAUDE_SESSION_JSONL`, (ii) `$CLAUDE_CODE_SESSION_ID` → constructed path. The stdin source MUST win when present; the env-var sources MUST keep working for SDK and manual invocation.
- [ ] 8.4 Confirm by re-running the existing `single-task-opus.jsonl` fixture via the env-var path that output is unchanged (backward compat).
- [ ] 8.5 Confirm by piping `{"transcript_path":"<path-to-fixture>","hook_event_name":"Stop"}` to the script with `env -u CLAUDE_SESSION_JSONL -u CLAUDE_CODE_SESSION_ID` that output is non-empty and identical to the env-var-path output for the same fixture.

## 9. `workflow` verb added to trigger regex

- [ ] 9.1 In `stop-hook.sh`, extend the trigger-detection regex alternation from `(?:analyse|generate|refresh|techdebt)` to `(?:analyse|generate|refresh|techdebt|workflow)` at **both** call sites (the `test()` filter and the `capture()` named group).
- [ ] 9.2 Confirm `$TRIGGER_CMD` after the jq pipeline yields `workflow` (not `claudboard-workflow` or any prefix variant) for a `/claudboard:claudboard-workflow` user turn.
- [ ] 9.3 Confirm `compute-cost.sh --task workflow` does not error and emits a cost line tagged with the `workflow` task name. If the script's `--task` arg is a free-form passthrough this is automatic; if it validates against a fixed verb list, add `workflow` to that list.
- [ ] 9.4 Re-run `single-task-opus.jsonl` and `namespaced-trigger.jsonl` after the regex change to confirm no regression for the four pre-existing verbs.

## 10. stdin-mode test fixture + workflow fixture

- [ ] 10.1 Create `skills/claudboard/scripts/tests/namespaced-workflow.jsonl` modelled on `namespaced-trigger.jsonl` but with the user turn containing `<command-name>/claudboard:claudboard-workflow</command-name>`. Include enough assistant turns with `usage` fields that `compute-cost.sh` produces a non-empty cost line.
- [ ] 10.2 In `tests/run.sh` (or `tests/hook-run.sh` — whichever is the active runner), add **stdin-mode** assertion blocks: for each of `single-task-opus.jsonl`, `namespaced-trigger.jsonl`, and `namespaced-workflow.jsonl`, invoke the hook with `env -u CLAUDE_SESSION_JSONL -u CLAUDE_CODE_SESSION_ID bash stop-hook.sh` and stdin set to `{"transcript_path":"<abs-path-to-fixture>","hook_event_name":"Stop"}`. Assert a non-empty cost line on stdout in each case.
- [ ] 10.3 Keep the existing env-var-mode assertions for the same three fixtures; both modes must pass.
- [ ] 10.4 Add a workflow-verb-specific assertion that the cost line tag is `workflow` (or whatever the canonical task label is for workflow) — mirrors the `analyse` tag check in section 5.
- [ ] 10.5 Run the full test suite; capture pass/fail counts; all should pass.

## 11. Re-verify end-to-end after sections 8–10

- [ ] 11.1 Bump `.claude-plugin/plugin.json` to the next beta (after `4.0.0-beta.10`).
- [ ] 11.2 Re-run task 7.2 against craftsphere.cloud (or any plugin-installed workspace) — observe one cost line for `/claudboard:claudboard-analyse`.
- [ ] 11.3 Re-run task 7.3 — observe a second distinct cost line for `/claudboard:claudboard-generate`.
- [ ] 11.4 Run `/claudboard:claudboard-workflow` and observe one cost line tagged `workflow`.
- [ ] 11.5 Confirm via `ls ~/.claude/projects/<cwd-slug>/.claudboard-cost-emitted/` that the per-task marker file is now being written (proves the script ran to completion, not just that it printed).
- [ ] 11.6 If `claude --debug` is needed to diagnose any remaining miss, capture the output and attach to this change before publish.
