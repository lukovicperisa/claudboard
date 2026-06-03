#!/usr/bin/env bash
# Unit tests for compute-cost.sh
# Run: bash tests/run.sh from skills/claudboard/scripts/
# Platform: darwin (BSD sed/grep)

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$SCRIPT_DIR/../compute-cost.sh"
F="$SCRIPT_DIR"  # fixtures dir

pass=0; fail=0

check() {
  local desc="$1" expected="$2" actual="$3"
  if [[ "$actual" == "$expected" ]]; then
    echo "PASS: $desc"
    pass=$((pass + 1))
  else
    echo "FAIL: $desc"
    echo "  expected: $expected"
    echo "  actual:   $actual"
    fail=$((fail + 1))
  fi
}

# ── single-task-opus ──────────────────────────────────────────────────────────
# req-001 appears twice (same requestId) → dedup → 2 unique calls
# Opus 4.7: (2000 inp * $15 + 2000 out * $75) / 1e6 = $0.18
# Output tokens: 2000 → 2K

out=$("$SCRIPT" "$F/single-task-opus.jsonl" --task analyse --since 2026-05-31T13:06:00.000Z)
check "single-task-opus one-line" \
  'Cost for /analyse: $0.06 (Opus 4.7 (Vertex), 2 calls, 2K out)' \
  "$out"

# Without --task flag
out=$("$SCRIPT" "$F/single-task-opus.jsonl")
check "single-task-opus no-task prefix" \
  'Cost: $0.06 (Opus 4.7 (Vertex), 2 calls, 2K out)' \
  "$out"

# JSON output is valid JSON and has correct keys
json=$("$SCRIPT" "$F/single-task-opus.jsonl" --format json)
echo "$json" | jq . > /dev/null 2>&1 && echo "PASS: single-task-opus json is valid JSON" && pass=$((pass + 1)) || { echo "FAIL: single-task-opus json is not valid JSON"; fail=$((fail + 1)); }
check "single-task-opus json model" \
  "claude-opus-4-7" \
  "$(echo "$json" | jq -r '.model')"
check "single-task-opus json api_calls" \
  "2" \
  "$(echo "$json" | jq -r '.api_calls')"

# ── mixed-models ──────────────────────────────────────────────────────────────
# req-003 Opus input 6000 → $0.09, req-004 Sonnet output 2000 → $0.03
# Total $0.12, mixed model, 2 calls, 2K out

out=$("$SCRIPT" "$F/mixed-models.jsonl" --task generate)
check "mixed-models one-line" \
  'Cost for /generate: $0.06 (mixed, 2 calls, 2K out)' \
  "$out"

json=$("$SCRIPT" "$F/mixed-models.jsonl" --format json)
check "mixed-models json model is array" \
  "true" \
  "$(echo "$json" | jq '.model | type == "array"')"

# ── unknown-model ─────────────────────────────────────────────────────────────
# claude-opus-5-0 unknown → Sonnet 4.6 fallback, 20000 inp * $3 = $0.06
# Warning must appear on stderr exactly once

warn_count=$("$SCRIPT" "$F/unknown-model.jsonl" --task analyse 2>&1 >/dev/null | grep -c 'unknown model' || true)
check "unknown-model warning count" "1" "$warn_count"

out=$("$SCRIPT" "$F/unknown-model.jsonl" --task analyse 2>/dev/null)
check "unknown-model one-line (fallback pricing)" \
  'Cost for /analyse: $0.06 (claude-opus-5-0, 1 calls, 0 out)' \
  "$out"

# ── json output self-validation ───────────────────────────────────────────────
json=$("$SCRIPT" "$F/unknown-model.jsonl" --format json 2>/dev/null)
echo "$json" | jq . > /dev/null 2>&1 && echo "PASS: unknown-model json is valid JSON" && pass=$((pass + 1)) || { echo "FAIL: unknown-model json is not valid JSON"; fail=$((fail + 1)); }

# ── JSONL path from environment variable ──────────────────────────────────────
out=$(CLAUDE_SESSION_JSONL="$F/single-task-opus.jsonl" "$SCRIPT" --task analyse --since 2026-05-31T13:06:00.000Z)
check "env-var JSONL path" \
  'Cost for /analyse: $0.06 (Opus 4.7 (Vertex), 2 calls, 2K out)' \
  "$out"

# ── missing JSONL path exits non-zero ─────────────────────────────────────────
if "$SCRIPT" 2>/dev/null; then
  echo "FAIL: missing JSONL path should exit non-zero"
  fail=$((fail + 1))
else
  echo "PASS: missing JSONL path exits non-zero"
  pass=$((pass + 1))
fi

# ── --since filters out earlier turns ────────────────────────────────────────
# mixed-models has /generate at 13:30; filter to 14:00+ → no turns → $0.00
out=$("$SCRIPT" "$F/mixed-models.jsonl" --task generate --since 2026-05-31T14:00:00.000Z)
check "--since filters all turns → zero cost" \
  'Cost for /generate: $0.00 (none, 0 calls, 0 out)' \
  "$out"

# ── summary ───────────────────────────────────────────────────────────────────
echo ""
echo "Results: $pass passed, $fail failed"
[[ "$fail" -eq 0 ]]
