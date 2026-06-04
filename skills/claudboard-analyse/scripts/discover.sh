#!/usr/bin/env bash
# discover.sh — claudboard-analyse discovery script (v1)
# Usage: bash scripts/discover.sh [<repo-path>]
# Emits a single JSON document to stdout. The analyse SKILL.md asserts
# schema_version == "1" before consuming any fields.
#
# Debugging: set DISCOVER_DEBUG=1 to bypass all 2>/dev/null redirects and see
# raw grep/jq diagnostics on stderr. Default (unset or 0) keeps output quiet.
#
# Exit codes: 0 = success (JSON on stdout)
#             1 = error (JSON error object on stderr, nothing on stdout)

set -uo pipefail

SCHEMA_VERSION="1"
REPO_PATH="${1:-.}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LANG_DIR="$SCRIPT_DIR/lang"

# ── Preflight: jq ────────────────────────────────────────────────────────
if ! command -v jq &>/dev/null; then
  printf '{"error":"jq not found","hint":"brew install jq  (macOS)  or  apt install jq  (Linux/WSL)"}\n' >&2
  exit 1
fi

# ── Preflight: repo path ──────────────────────────────────────────────────
if ! REPO_PATH="$(cd "$REPO_PATH" 2>/dev/null && pwd)"; then
  printf '{"error":"path not found: %s"}\n' "${1:-.}" >&2
  exit 1
fi

# ── Temp dir (cleaned up on exit) ────────────────────────────────────────
TMPDIR_DISCOVER="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_DISCOVER"' EXIT

# ── DISCOVER_DEBUG wrapper ────────────────────────────────────────────────
# _q: when DISCOVER_DEBUG is unset/empty/0, redirects stderr to /dev/null.
# When DISCOVER_DEBUG is any other non-empty value, runs unredirected so grep
# and jq diagnostics appear on stderr. Usage: _q grep ..., _q jq ...
_q() {
  if [ -n "${DISCOVER_DEBUG:-}" ] && [ "${DISCOVER_DEBUG}" != "0" ]; then
    "$@"
  else
    "$@" 2>/dev/null
  fi
}

# ── Source helpers ────────────────────────────────────────────────────────
# shellcheck source=lang/_common.sh
source "$LANG_DIR/_common.sh"

# ── Phase 1: Counts & detection ──────────────────────────────────────────
SOURCE_FILE_COUNT=$(count_source_files "$REPO_PATH")
LANGUAGES=$(detect_languages "$REPO_PATH")
BUILD_FILES=$(detect_build_files "$REPO_PATH")

# ── Phase 2: Language pack dispatch ──────────────────────────────────────
# Each pack writes a JSON fragment to $TMPDIR_DISCOVER/scan_<lang>.json
# The fragments are merged below into wide_scan.

_lang_detected() {
  echo "$LANGUAGES" | _q jq -e --arg l "$1" '. | index($l) != null' >/dev/null
}

if _lang_detected "java"; then
  # shellcheck source=lang/java.sh
  source "$LANG_DIR/java.sh"
  run_java_scan "$REPO_PATH" "$TMPDIR_DISCOVER/scan_java.json"
fi

if _lang_detected "typescript"; then
  # shellcheck source=lang/typescript.sh
  source "$LANG_DIR/typescript.sh"
  run_typescript_scan "$REPO_PATH" "$TMPDIR_DISCOVER/scan_typescript.json"
fi

if _lang_detected "python"; then
  # shellcheck source=lang/python.sh
  source "$LANG_DIR/python.sh"
  run_python_scan "$REPO_PATH" "$TMPDIR_DISCOVER/scan_python.json"
fi

if _lang_detected "go"; then
  # shellcheck source=lang/go.sh
  source "$LANG_DIR/go.sh"
  run_go_scan "$REPO_PATH" "$TMPDIR_DISCOVER/scan_go.json"
fi

if _lang_detected "rust"; then
  # shellcheck source=lang/rust.sh
  source "$LANG_DIR/rust.sh"
  run_rust_scan "$REPO_PATH" "$TMPDIR_DISCOVER/scan_rust.json"
fi

if _lang_detected "dotnet"; then
  # shellcheck source=lang/dotnet.sh
  source "$LANG_DIR/dotnet.sh"
  run_dotnet_scan "$REPO_PATH" "$TMPDIR_DISCOVER/scan_dotnet.json"
fi

# ── Phase 3: Merge language scan fragments ────────────────────────────────
SCAN_FILES=("$TMPDIR_DISCOVER"/scan_*.json)
if [ ${#SCAN_FILES[@]} -eq 0 ] || [ ! -e "${SCAN_FILES[0]}" ]; then
  # No language detected — emit empty wide_scan
  WIDE_SCAN_JSON='{"skill_triggers":{},"anti_patterns":{},"conventions":{},"god_class_candidates":[],"inheritance_map":[]}'
else
  WIDE_SCAN_JSON=$(jq -sc '
    reduce .[] as $x (
      {skill_triggers: {}, anti_patterns: {}, conventions: {},
       god_class_candidates: [], inheritance_map: []};
      .skill_triggers      += ($x.skill_triggers      // {}) |
      .anti_patterns       += ($x.anti_patterns       // {}) |
      .conventions         += ($x.conventions         // {}) |
      .god_class_candidates += ($x.god_class_candidates // []) |
      .inheritance_map     += ($x.inheritance_map     // [])
    )
  ' "${SCAN_FILES[@]}" 2>/dev/null || echo '{"skill_triggers":{},"anti_patterns":{},"conventions":{},"god_class_candidates":[],"inheritance_map":[]}')
fi

# ── Phase 4: Duplication candidates (skip when < 30 source files) ────────
# Uses init-then-conditional-assign to avoid double-emit under set -o pipefail:
# when the upstream grep exits non-zero, jq -sc still produces [] before the
# pipeline fails; || echo '[]' would then append a second [] (invalid JSON).
DUPLICATION_JSON='{"candidates":[]}'
if [ "${SOURCE_FILE_COUNT:-0}" -ge 30 ] 2>/dev/null; then
  JAVA_DUPS='[]'
  if _lang_detected "java"; then
    _out=''
    if _out=$(
      _q grep -rh 'return null;\|catch (Exception' \
        --include='*.java' "$REPO_PATH" \
      | sort | uniq -c | sort -rn \
      | awk '$1 >= 5 {$1=""; print}' \
      | head -5 \
      | _q jq -Rc '{"pattern": ., "note": "recurs 5+ times"}' \
      | _q jq -sc .
    ); then
      JAVA_DUPS="$_out"
    fi
  fi
  TS_DUPS='[]'
  if _lang_detected "typescript"; then
    _out=''
    if _out=$(
      _q grep -rh 'console\.log\|as any' \
        --include='*.ts' --include='*.tsx' "$REPO_PATH" \
      | grep -v node_modules \
      | sort | uniq -c | sort -rn \
      | awk '$1 >= 5 {$1=""; print}' \
      | head -5 \
      | _q jq -Rc '{"pattern": ., "note": "recurs 5+ times"}' \
      | _q jq -sc .
    ); then
      TS_DUPS="$_out"
    fi
  fi
  DUPLICATION_JSON=$(jq -n --argjson j "$JAVA_DUPS" --argjson t "$TS_DUPS" \
    '{"candidates": ($j + $t)}')
fi

# ── Phase 5: ref_load_signals ─────────────────────────────────────────────
REF_MESSAGING=$(compute_messaging_signal "$REPO_PATH")
REF_STREAMING=$(compute_streaming_signal "$REPO_PATH")
REF_GRAPHQL=$(compute_graphql_signal "$REPO_PATH")
REF_ARCHITECTURAL=$(compute_architectural_signal "$REPO_PATH")

# ── Phase 6: Validate intermediate JSON before assembly ───────────────────
_validate_json() {
  local varname="$1" value="$2"
  if ! printf '%s' "$value" | jq '.' >/dev/null 2>&1; then
    local preview="${value:0:120}"
    printf 'discover.sh: %s is not valid JSON (first 120 chars: %s...); re-run with DISCOVER_DEBUG=1 for full stderr\n' \
      "$varname" "$preview" >&2
    printf '{"error":"invalid intermediate JSON","var":"%s"}\n' "$varname" >&2
    exit 1
  fi
}

_validate_json "LANGUAGES"         "$LANGUAGES"
_validate_json "BUILD_FILES"       "$BUILD_FILES"
_validate_json "WIDE_SCAN_JSON"    "$WIDE_SCAN_JSON"
_validate_json "DUPLICATION_JSON"  "$DUPLICATION_JSON"
_validate_json "REF_MESSAGING"     "$REF_MESSAGING"
_validate_json "REF_STREAMING"     "$REF_STREAMING"
_validate_json "REF_GRAPHQL"       "$REF_GRAPHQL"
_validate_json "REF_ARCHITECTURAL" "$REF_ARCHITECTURAL"
if ! printf '%s' "${SOURCE_FILE_COUNT:-0}" | jq -e 'type == "number"' >/dev/null 2>&1; then
  printf 'discover.sh: SOURCE_FILE_COUNT is not valid JSON (first 120 chars: %s...); re-run with DISCOVER_DEBUG=1 for full stderr\n' \
    "${SOURCE_FILE_COUNT:-0}" >&2
  printf '{"error":"invalid intermediate JSON","var":"SOURCE_FILE_COUNT"}\n' >&2
  exit 1
fi

# ── Phase 7: Assemble final JSON ──────────────────────────────────────────
jq -n \
  --arg   schema_version    "$SCHEMA_VERSION" \
  --arg   repo_path         "$REPO_PATH" \
  --argjson languages       "$LANGUAGES" \
  --argjson source_file_count "${SOURCE_FILE_COUNT:-0}" \
  --argjson build_files     "$BUILD_FILES" \
  --argjson wide_scan       "$WIDE_SCAN_JSON" \
  --argjson duplication     "$DUPLICATION_JSON" \
  --argjson ref_messaging   "$REF_MESSAGING" \
  --argjson ref_streaming   "$REF_STREAMING" \
  --argjson ref_graphql     "$REF_GRAPHQL" \
  --argjson ref_arch        "$REF_ARCHITECTURAL" \
  '{
    schema_version: $schema_version,
    repo: {
      path:              $repo_path,
      languages:         $languages,
      source_file_count: $source_file_count
    },
    build_files: $build_files,
    wide_scan:   $wide_scan,
    duplication: $duplication,
    ref_load_signals: {
      messaging:     $ref_messaging,
      streaming:     $ref_streaming,
      graphql:       $ref_graphql,
      architectural: $ref_arch
    }
  }'
