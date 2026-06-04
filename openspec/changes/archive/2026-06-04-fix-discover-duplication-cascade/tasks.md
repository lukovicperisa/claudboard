## 1. Reproduction & regression baseline

- [x] 1.1 Capture pre-change `discover.sh` output on `meas.cloud.datahandler` to a temp file (expected: empty stdout, exit 0). Document in scratch notes.
- [x] 1.2 Capture pre-change `discover.sh` output on `craftsphere.cloud` (or any known-happy single-module repo) to a temp file. This becomes the regression baseline for D2.
- [x] 1.3 Confirm via `xxd` that the failing case captures `JAVA_DUPS = "[]\n[]"` (5 bytes: `5b 5d 0a 5b 5d`). Pin this evidence to the change PR description.

## 2. Implement DISCOVER_DEBUG wrapper (D4)

- [x] 2.1 Add a header comment to `scripts/discover.sh` documenting `DISCOVER_DEBUG=1` as a debugging escape hatch (one paragraph).
- [x] 2.2 Add the `_q` wrapper function near the top of `discover.sh` (after the preflight checks, before Phase 1): when `DISCOVER_DEBUG` is unset/empty/`0`, runs the command with `2>/dev/null`; otherwise runs it unredirected.
- [x] 2.3 Replace each `command ... 2>/dev/null` site in Phase 1 (grep counts, language detection) with `_q command ...`.
- [x] 2.4 Replace each `command ... 2>/dev/null` site in Phase 4 duplication blocks (grep and inner jq) with `_q command ...`.
- [x] 2.5 Replace each `command ... 2>/dev/null` site in Phase 5 (`compute_*_signal` calls and helpers in `lang/_common.sh`) with `_q command ...`. Sourced helpers SHALL have access to `_q` (defined before `source` lines, OR re-defined in `_common.sh` with the same contract).

## 3. Fix Java duplication path (D2)

- [x] 3.1 In the Phase 4 Java duplication block (currently lines ~113-121), change the `grep` target from `"${REPO_PATH}/src/main"` to `"$REPO_PATH"`.
- [x] 3.2 Verify the grep still uses `--include='*.java'` and exclusions remain unchanged (the global exclusions list, if any, is honoured).
- [x] 3.3 Run `bash scripts/discover.sh /path/to/meas/meas.cloud.datahandler` (no DEBUG); confirm the Java grep now traverses module subdirectories.

## 4. Fix double-emit pattern in both duplication blocks (D1)

- [x] 4.1 Rewrite the Java duplication block to use the init-then-conditional-assign pattern: initialise `JAVA_DUPS='[]'`, run the pipeline into a temp var with `if _out=$(pipeline); then JAVA_DUPS="$_out"; fi`.
- [x] 4.2 Rewrite the TypeScript duplication block (currently lines ~123-134) with the identical pattern (init `TS_DUPS='[]'`, conditional assign). Defensive — same latent bug.
- [x] 4.3 Remove the now-redundant `|| echo '[]'` tails from both blocks.
- [x] 4.4 Confirm both blocks no longer use the `pipeline 2>/dev/null || echo '...'` shape via `grep -n '|| echo' scripts/discover.sh` → expect no matches in Phase 4.

## 5. Add intermediate-JSON validation (D3)

- [x] 5.1 Before the final Phase 6 `jq -n` assembly (around line 147), add a validation block that pipes each `--argjson` input through `jq -e . >/dev/null` and on failure emits the named diagnostic to stderr and exits 1.
- [x] 5.2 Variables to validate (in order): `LANGUAGES`, `BUILD_FILES`, `WIDE_SCAN_JSON`, `DUPLICATION_JSON`, `REF_MESSAGING`, `REF_STREAMING`, `REF_GRAPHQL`, `REF_ARCHITECTURAL`, `SOURCE_FILE_COUNT` (numeric — validate it parses as a JSON number).
- [x] 5.3 Diagnostic format: `discover.sh: <VAR_NAME> is not valid JSON (first 120 chars: <truncated>...); re-run with DISCOVER_DEBUG=1 for full stderr` to stderr, followed by the JSON error object `{"error":"invalid intermediate JSON","var":"<VAR_NAME>"}` on stderr.
- [x] 5.4 Manually trigger the diagnostic: temporarily set `DUPLICATION_JSON='{"broken'` in the script, re-run, confirm stderr names DUPLICATION_JSON and the script exits 1. Revert.

## 6. Verification

- [x] 6.1 Run `bash scripts/discover.sh /path/to/meas/meas.cloud.datahandler` → exit 0, stdout is single-line JSON, `schema_version=="1"`, `wide_scan` populated, `duplication.candidates` is an array (possibly empty).
- [x] 6.2 Run on `craftsphere.cloud` → stdout equivalent to pre-change baseline from task 1.2 (modulo timestamps/paths). No regression.
- [x] 6.3 Run `DISCOVER_DEBUG=1 bash scripts/discover.sh /path/to/meas/meas.cloud.datahandler 2>/tmp/debug-stderr.txt` → stderr contains some grep diagnostics (proving DEBUG works); stdout JSON unchanged from 6.1.
- [x] 6.4 Run on a small repo with <30 source files (e.g. a fresh `git init` with a single `Hello.java`). Confirm Phase 4 is skipped (`duplication.candidates == []`) per the existing `SOURCE_FILE_COUNT >= 30` guard.
- [x] 6.5 Run `/analyse` end-to-end against meas (or invoke the analyse SKILL flow that calls discover.sh) and confirm the fallback message `"discover.sh is erroring out"` no longer appears.

## 7. Documentation & wrap-up

- [x] 7.1 Update the discover.sh header comment to mention `DISCOVER_DEBUG=1` (one line near the existing `Usage:` line).
- [x] 7.2 Update `MEMORY.md` with a new feedback memory: `pipeline || echo '<fallback>'` under `set -o pipefail` double-emits — use init-then-conditional-assign instead. Reason: shipped bug in discover.sh, June 2026.
- [x] 7.3 Run `openspec status --change "fix-discover-duplication-cascade"` and confirm all tasks completed; archive readiness check passes.
