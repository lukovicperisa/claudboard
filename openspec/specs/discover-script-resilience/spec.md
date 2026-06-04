## ADDED Requirements

### Requirement: discover.sh SHALL emit valid JSON on all supported repo layouts

`scripts/discover.sh` (the Phase 1c discovery script consumed by `claudboard-analyse`) SHALL emit a single, well-formed JSON document to stdout whose top-level field `schema_version` equals `"1"`, regardless of whether the target repository uses a single-module or multi-module Gradle/Maven layout, and regardless of whether any Phase 4 duplication grep matches zero, some, or many lines.

The script SHALL NOT depend on the literal directory `<repo-path>/src/main` existing. Java source detection and duplication grepping SHALL traverse from the repo root using `grep -r` (or equivalent) so that sources under `<module>/src/main/` in multi-module repos are reached.

#### Scenario: Multi-module Gradle repo produces valid JSON
- **WHEN** `discover.sh` runs against a multi-module Gradle repo whose sources live under `<module>/src/main/` (e.g. `meas.cloud.datahandler` with `datahandler-api/`, `datahandler-service/`, `datahandler-docker/`)
- **THEN** stdout is a single valid JSON document with `schema_version: "1"` and a populated `wide_scan` and `duplication` field; exit code is 0

#### Scenario: Single-module Maven repo unchanged
- **WHEN** `discover.sh` runs against a single-module repo whose sources live under `<repo>/src/main/` (e.g. `craftsphere.cloud`)
- **THEN** stdout is byte-equivalent (modulo timestamps and absolute paths) to the pre-change output; exit code is 0

#### Scenario: Repo with no Java duplications
- **WHEN** `discover.sh` runs against a repo whose Java duplication grep matches zero lines
- **THEN** `duplication.candidates` is an empty array `[]` (not `null`, not missing); stdout JSON validates; exit code is 0

---

### Requirement: discover.sh SHALL NOT double-emit fallback values under set -o pipefail

`scripts/discover.sh` runs with `set -o pipefail`. The script SHALL NOT use the `pipeline 2>/dev/null || echo '<fallback>'` pattern for capturing JSON into variables, because this pattern concatenates the (potentially valid) pipeline stdout with the fallback string when the pipeline exits non-zero, producing invalid JSON like `"[]\n[]"`.

Instead, intermediate JSON variables that have a fallback value SHALL be initialised to the fallback first, then overwritten only if a stdout-capture-into-temporary succeeds. Equivalent patterns (e.g. tmp-file capture, `set +o pipefail` subshell with explicit re-entry) are acceptable provided they exhibit no double-emit behaviour.

This requirement applies at minimum to the Java duplication block and the TypeScript duplication block in Phase 4 (currently lines ~113-121 and ~123-134), and to any future block that uses the same capture-with-fallback shape.

#### Scenario: Pipefail-triggered failure does not corrupt JSON
- **WHEN** an upstream grep in a Phase 4 capture block exits non-zero (e.g. because a source directory does not exist) AND the downstream `jq` step still emits valid `[]` on stdout
- **THEN** the captured shell variable contains exactly `[]` (not `"[]\n[]"`, not any concatenation); subsequent `jq --argjson` calls parse it successfully

#### Scenario: Both Java and TS duplication blocks behave identically
- **WHEN** the patterns of Java and TS duplication blocks are inspected
- **THEN** neither uses `pipeline 2>/dev/null || echo '<fallback>'`; both use an init-then-conditional-assign equivalent

---

### Requirement: discover.sh SHALL surface a named diagnostic when intermediate JSON is invalid

Before the final Phase 6 `jq -n` assembly invocation, `scripts/discover.sh` SHALL validate each `--argjson` input variable (at minimum: `LANGUAGES`, `BUILD_FILES`, `WIDE_SCAN_JSON`, `DUPLICATION_JSON`, `REF_MESSAGING`, `REF_STREAMING`, `REF_GRAPHQL`, `REF_ARCHITECTURAL`). If any variable is not valid JSON, the script SHALL:

1. Emit a one-line diagnostic to stderr naming the variable and the first ~120 chars of its value:
   ```
   discover.sh: <VAR_NAME> is not valid JSON (first 120 chars: <content>...); re-run with DISCOVER_DEBUG=1 for full stderr
   ```
2. Emit a JSON error object on stderr:
   ```json
   {"error":"invalid intermediate JSON","var":"<VAR_NAME>"}
   ```
3. Exit with code 1.

The diagnostic SHALL be emitted *before* the failing `jq -n` invocation so the failure can be attributed to the correct variable.

#### Scenario: Invalid intermediate JSON names the broken variable
- **WHEN** `discover.sh` is run under conditions where some intermediate variable (e.g. `DUPLICATION_JSON`) contains invalid JSON
- **THEN** stderr contains a line beginning with `discover.sh: DUPLICATION_JSON is not valid JSON` AND a JSON error object naming that variable AND the exit code is 1

#### Scenario: Valid JSON passes through without diagnostic
- **WHEN** all intermediate `--argjson` inputs are valid JSON
- **THEN** no validation diagnostic is emitted; the final JSON is produced on stdout normally

---

### Requirement: discover.sh SHALL honour the DISCOVER_DEBUG environment variable

When the environment variable `DISCOVER_DEBUG` is set to any non-empty value other than `0`, `scripts/discover.sh` SHALL NOT redirect command stderr to `/dev/null` for the intentionally-silenced commands in Phases 1, 4, and 5. This allows users to run `DISCOVER_DEBUG=1 bash scripts/discover.sh <path>` and see real grep/jq stderr alongside the JSON output, for debugging script issues.

When `DISCOVER_DEBUG` is unset, empty, or `0`, the existing quiet behaviour is preserved — silenced commands stay silenced.

The implementation MAY use a wrapper function (e.g. `_q cmd args...`) or any equivalent mechanism that toggles the redirect based on the env var, as long as the contract above is met.

`DISCOVER_DEBUG` is a debugging affordance only; it is NOT part of the discover.sh JSON output contract and SHALL NOT alter the structure or content of stdout. The variable is documented in the discover.sh header comment.

#### Scenario: DEBUG unset → quiet behaviour
- **WHEN** `discover.sh` runs against a happy-path repo with `DISCOVER_DEBUG` unset
- **THEN** stderr is empty (or contains only the script's own intentional error reports); stdout contains the JSON document

#### Scenario: DEBUG=1 → grep stderr surfaced
- **WHEN** `discover.sh` runs against a repo whose duplication grep targets a missing directory, with `DISCOVER_DEBUG=1`
- **THEN** stderr contains the grep's "No such file or directory" message; stdout still contains the valid JSON document (the fix in the double-emit requirement ensures the JSON is well-formed)

#### Scenario: DEBUG=0 treated as unset
- **WHEN** `discover.sh` runs with `DISCOVER_DEBUG=0`
- **THEN** behaviour is identical to `DISCOVER_DEBUG` unset (quiet mode)
