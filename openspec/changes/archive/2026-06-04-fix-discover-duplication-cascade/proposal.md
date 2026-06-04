## Why

`scripts/discover.sh` silently produces invalid JSON on any multi-module Gradle/Maven repo (and anywhere `<repo>/src/main` does not exist as a literal directory). Reproduced on `meas.cloud.datahandler`: the script exits 0, but stdout is empty — so the analyse SKILL's "schema_version != '1'" guard fires and the run falls back to the slower manual-scan path. The user-visible symptom is the cryptic `"discover.sh is erroring out (jq merge issue)"` from the SKILL fallback contract; the actual failure is two compounding bugs in the duplication-detection block (Phase 4) that the fallback message attributes to the wrong phase.

The two bugs:

1. **Hard-coded `${REPO_PATH}/src/main`** in the Java duplication grep (line 115). Multi-module Gradle/Maven repos have sources under `<module>/src/main`, never at the repo root. `grep` exits with code 2 (no such file).
2. **`pipeline 2>/dev/null || echo '[]'` double-emits under `set -o pipefail`.** When `grep` fails upstream but `jq -sc .` downstream still produces valid `[]`, pipefail flips the pipeline exit to non-zero — and `|| echo '[]'` then APPENDS another `[]`. `JAVA_DUPS` captures `"[]\n[]"`, which is invalid JSON. `jq -n --argjson j "$JAVA_DUPS"` rejects it, `DUPLICATION_JSON` becomes empty, the final Phase 6 assembly fails silently, and stdout is empty.

The errors are also fully swallowed by `2>/dev/null`, so neither the user nor the SKILL fallback contract can name what failed.

## What Changes

- **Fix the Java duplication grep** to drop the `/src/main` suffix; grep recursively from `$REPO_PATH` (matches the TS block at line 127, which already does this).
- **Replace the `pipeline || echo '[]'` pattern** in both the Java and TS duplication blocks with a non-double-emitting equivalent (initialise the var to `'[]'` first, then assign only if the pipeline-output capture succeeded). Eliminates the latent bug in both blocks.
- **Add a `DISCOVER_DEBUG=1` env var.** When set, `discover.sh` SHALL NOT redirect command stderr to `/dev/null`. Default unset → existing quiet behaviour preserved.
- **Emit a one-line diagnostic to stderr** when any `--argjson` input to the final Phase 6 `jq -n` assembly is not valid JSON. The diagnostic SHALL name which variable broke (e.g. `discover.sh: DUPLICATION_JSON is not valid JSON`) and SHALL be emitted *before* the failing jq call, so the SKILL fallback message can quote it instead of just "errored out".
- **No SKILL.md change.** The fallback contract at SKILL.md §1c "Fallback (discover.sh unavailable)" already covers this case; the diagnostic improves what the user sees but does not change the contract.

## Capabilities

### New Capabilities
- `discover-script-resilience`: discover.sh's failure-mode contract — what it guarantees about its output JSON under common upstream-grep failures, multi-module repo layouts, and how it surfaces diagnostics when intermediate JSON is malformed.

### Modified Capabilities
<!-- None — analyse-performance owns model tiers and cost claims; convention-catalog owns the catalog schema. Neither covers the discover.sh internal failure-mode contract that this change introduces. -->

## Impact

- **Code:** `skills/claudboard-analyse/scripts/discover.sh` only — duplication block (lines ~108-138) and Phase 6 assembly (lines ~147-176). No language-pack changes. No SKILL.md changes.
- **APIs / output schema:** unchanged. `schema_version` stays at `"1"`. Stdout JSON shape and field semantics are identical; only the path that produces them is fixed.
- **Failure mode:** previously silent (empty stdout, exit 0). Now: stdout JSON is produced reliably on multi-module repos; when something else breaks, stderr names the broken variable.
- **Reverse compatibility:** none broken. Repos that were already happy (e.g. `craftsphere.cloud` — single-module layout with `src/main` at root) still produce identical output. Multi-module repos that previously triggered the manual-scan fallback now stay on the fast path.
- **No new dependencies.** Uses only `bash`, `jq`, `grep`, `awk` — already required.
