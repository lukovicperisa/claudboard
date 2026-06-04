## Context

`scripts/discover.sh` is a single bash file invoked as one tool call from the analyse SKILL Phase 1c. Its contract: emit a versioned JSON document on stdout (`schema_version: "1"`), or exit non-zero with a JSON error object on stderr.

The script's current Phase 4 (duplication detection, lines ~108-138) violates that contract on multi-module Gradle/Maven repos. The combination of `set -o pipefail` (line 10), `2>/dev/null` (used liberally to silence noisy greps), and `|| echo '[]'` fallbacks produces a value that *looks* like a graceful fallback but is actually `"[]\n[]"` — two `[]` literals concatenated by a newline. The downstream Phase 6 `jq -n --argjson` then fails to parse it and the whole script returns empty stdout. SKILL.md's schema-version guard fires, and the run falls back to the slower manual-scan path. The user-facing message is the SKILL fallback prose, which (truthfully) cannot name what broke because the bash script swallowed its own diagnostics.

A short repro proves the cascade: on `meas.cloud.datahandler`, `xxd` of `JAVA_DUPS` is `5b 5d 0a 5b 5d` (`[]\n[]`). The same bug exists in the TS block (line 127) but only surfaces when its grep also returns no matches AND TS has been detected — until now the meas case never hit it because TS wasn't detected.

This change is one-file, mechanical. The design pass exists primarily to capture *why* the double-emit happens (subtle pipefail interaction that future maintainers will trip over) and to lock in the diagnostic contract so the next failure mode is easier to debug.

## Goals / Non-Goals

**Goals:**
- discover.sh produces valid JSON on multi-module Gradle/Maven repos (the failing meas case).
- discover.sh never silently produces invalid JSON. If something is wrong, stderr names which intermediate variable broke, in a single line, *before* the failing jq call.
- `DISCOVER_DEBUG=1` env var unblocks deeper debugging by skipping the `2>/dev/null` redirects.
- Zero behaviour change on repos that currently work (craftsphere.cloud single-module layout).

**Non-Goals:**
- Auto-discovering all `src/main` roots in multi-module repos and producing per-module duplication candidates. Current behaviour after the fix — grep recursively from `$REPO_PATH` — already finds duplications across modules; we just don't separate them by module. Per-module attribution is a future capability (Option B in the original explore session) and warrants its own proposal.
- Restructuring discover.sh into a more disciplined error-handling shape (e.g. wrapping every command-substitution in a helper that asserts JSON validity). Worth doing eventually, but out of scope here — the change set stays minimal so it can ship without coordinated downstream updates.
- Changing SKILL.md's fallback contract or the JSON schema. Both stay at v1. The "Fallback (discover.sh unavailable)" section already handles the "discover.sh failed" case correctly; we just make the failure rarer and the diagnostics better.
- Removing `set -o pipefail`. The flag is correct — it catches real bugs. The fix is to use it correctly, not to remove it.

## Decisions

### D1: Use `pipeline-output capture + conditional assignment` instead of `pipeline || echo`

**Decision:** Replace both
```bash
VAR=$(pipeline 2>/dev/null || echo '[]')
```
blocks with:
```bash
VAR='[]'
if _out=$(pipeline 2>/dev/null); then
  VAR="$_out"
fi
```

**Why:** The original idiom looks idiomatic but is wrong under `set -o pipefail`. When the upstream `grep` exits 2 (no file), pipefail flips the pipeline exit to non-zero — but the downstream `jq -sc .` *still produced valid `[]` on stdout* before the pipeline aborted. Command substitution captures all stdout, then `|| echo '[]'` ALSO runs because the pipeline exit was non-zero, and APPENDS another `[]`. Final captured stdout is `[]\n[]`.

The capture-into-tmp-var pattern decouples "did the pipeline succeed?" from "what did it print" — if the pipeline fails, the tmp var is set to whatever partial junk was on stdout but is then *discarded* (because `if` falls through). VAR stays at its initialised `'[]'`. Clean fallback, no concatenation.

**Alternatives considered:**
- Drop `set -o pipefail` for this block via subshell: `( set +o pipefail; ... )`. Works but hides the discipline; future readers will not know which commands were intentionally allowed to fail.
- Write to a tmp file and read it back. Two extra fs ops per call; no benefit over a shell var.
- Use `|| true` instead of `|| echo '[]'`: then the captured stdout is `[]` only when the pipeline succeeded, and empty otherwise. We'd still need to default VAR somewhere — same number of lines, less obvious intent. The "init to default, override on success" pattern reads clearly.

### D2: Drop `${REPO_PATH}/src/main` from the Java grep, use `$REPO_PATH` directly

**Decision:** Change line 115 from
```bash
grep -rh '...' --include='*.java' "${REPO_PATH}/src/main" 2>/dev/null
```
to
```bash
grep -rh '...' --include='*.java' "$REPO_PATH" 2>/dev/null
```

**Why:** The TS block at line 127 already greps from `$REPO_PATH` and recurses. The `/src/main` restriction was presumably an attempt to scope to non-test Java sources, but it only worked for single-module Maven/Gradle layouts. Multi-module layouts (any Bosch repo, Spring Cloud monorepos, half of OSS Java projects) put sources at `<module>/src/main/`, never at the root.

Grepping the whole repo will incidentally include test sources too (`<module>/src/test/java/...`). This is an acceptable trade for v1: duplication patterns like `return null;` and `catch (Exception` are equally bad in test code, and the grep is the prefilter for a human-eyed top-5 list anyway. If test-source noise becomes a problem later, add `--exclude-dir=test` (a per-language detail, not a general approach).

**Alternatives considered:**
- `find $REPO_PATH -type d -name 'main' -path '*/src/main'` → loop over each → grep. More precise but adds a fork-exec round trip per module. Not worth it for a duplication grep that is itself a heuristic.
- Read `build.gradle`/`pom.xml` to compute the source roots. Way over-engineered for this purpose.
- Skip Java duplication entirely on multi-module repos. Loses signal on the most important class of repo we care about.

### D3: Diagnostic emission on invalid intermediate JSON

**Decision:** Before the final Phase 6 `jq -n` assembly (line ~147), validate each `--argjson` input and emit a one-line stderr diagnostic if any is invalid. Form:
```
discover.sh: <VAR_NAME> is not valid JSON (first 120 chars: <content>...); re-run with DISCOVER_DEBUG=1 for full stderr
```
Then exit 1 with the standard error JSON on stderr (`{"error":"invalid intermediate JSON","var":"<VAR>"}`).

**Why:** Today the script swallows everything. The SKILL fallback message reads "discover.sh is erroring out" because that's literally all it can say — the bash script's exit code might still be 0 (Phase 6 `jq -n` failure doesn't propagate through command substitution back to a calling shell — but here, we're running discover.sh directly, so a Phase 6 failure DOES exit non-zero. Empty stdout is the smoking gun.). Naming the variable lets the user open discover.sh, find that one block, and see the bug. For maintainers iterating on discover.sh itself, the diagnostic catches the bug in the right phase.

**Alternatives considered:**
- Always run with `set -x`. Too noisy; SKILL.md would see the trace as part of stdout.
- Emit the diagnostic to stdout as part of the error JSON. Possible, but mixing diagnostics into the structured output makes the schema-assertion logic harder. stderr is the right channel.
- Skip the diagnostic, just exit non-zero with a generic message. Fixes the immediate bug but leaves the next discover.sh bug equally invisible. Marginal extra code (~5 lines per var × 4 vars = 20 lines) for a meaningful debuggability win.

### D4: `DISCOVER_DEBUG=1` env var contract

**Decision:** Introduce a single env var:
- Unset / `0` / empty → existing behaviour: `2>/dev/null` redirects in place.
- Any non-empty value other than `0` → all `2>/dev/null` redirects in the script are bypassed (using a `_REDIR` variable that resolves to `2>/dev/null` or empty, expanded into the commands).

Implementation sketch:
```bash
if [ -n "${DISCOVER_DEBUG:-}" ] && [ "${DISCOVER_DEBUG}" != "0" ]; then
  _Q=""    # no redirect
else
  _Q="2>/dev/null"
fi
# use as: grep ... $_Q     (NOT eval'd; deferred via eval where needed)
```

In practice, since bash doesn't expand `2>/dev/null` from a variable (it's parsed at tokenisation time), the simplest correct implementation is a wrapper function:
```bash
_q() {
  if [ -n "${DISCOVER_DEBUG:-}" ] && [ "${DISCOVER_DEBUG}" != "0" ]; then
    "$@"
  else
    "$@" 2>/dev/null
  fi
}
```
Then replace `grep ... 2>/dev/null` with `_q grep ...`. One small wrapper, applied at each silenced site.

**Why:** Future failures of the same shape need a debugging escape hatch. `DISCOVER_DEBUG` is the lowest-ceremony option — no config file, no flag plumbing, just `DISCOVER_DEBUG=1 bash scripts/discover.sh <path>`.

**Alternatives considered:**
- A `--debug` CLI flag. More discoverable in `--help`, but discover.sh has no flag parsing today; adding flag parsing is more change than the bug warrants.
- Always emit stderr (drop `2>/dev/null` entirely). Would flood SKILL output with benign "no such file" greps. Bad UX in the happy path.
- Use `set -x` when DEBUG is on. Easy but firehose — the wrapper-function pattern lets us preserve `2>/dev/null` for *intentional* silencing (e.g. greps that we know often return no matches) while still letting users see them under DEBUG.

## Risks / Trade-offs

| Risk | Mitigation |
|---|---|
| Wrapper function `_q` adds a process layer; might confuse future readers. | Defined inline near the top of the script with a 1-line comment explaining the DEBUG contract. Pattern is short and standard. |
| Grepping the whole `$REPO_PATH` includes test sources and may pull in vendored deps. | Existing exclusions list (`node_modules`, `.git`, `target`, etc.) is honoured by the wider script via grep `--exclude-dir` patterns elsewhere; for the duplication grep we accept slight noise — it's a top-5 frequency filter, not an exhaustive list. |
| Diagnostic-on-invalid-JSON adds ~20 lines and 4 jq validation calls before Phase 6. Tiny runtime cost. | Acceptable; runtime impact is sub-millisecond against an analysis that runs for tens of seconds. |
| Adding `DISCOVER_DEBUG` is a new public surface — once shipped, removing it would be a soft break. | Surface is tiny (1 env var, 1 sentence in design.md). Not formally part of the SKILL fallback contract; documented in discover.sh header comment only. |
| Someone re-introduces the `\|\| echo` pattern in a future block. | The validation-diagnostic block catches it immediately (whichever new VAR is malformed gets named in stderr). Self-correcting. |

## Migration Plan

No migration needed.

- No schema bump (`SCHEMA_VERSION` stays `"1"`).
- No SKILL.md change.
- Existing happy-path repos produce byte-identical JSON before and after.
- Multi-module repos that were silently falling through to manual scan switch to the fast path on next `/analyse` invocation — observable as faster analysis runs and no `"discover.sh is erroring out (jq merge issue)"` fallback message. No user action required.
- Rollback: revert the single commit.

## Open Questions

None — scope is well-defined and the fix is mechanical. If `DISCOVER_DEBUG` turns out to be needed often, the next iteration can promote it into the SKILL fallback contract (e.g. SKILL.md instructs users to re-run with the env var when the fallback triggers).
