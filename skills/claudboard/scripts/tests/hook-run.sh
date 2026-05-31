#!/usr/bin/env bash
# Integration tests for stop-hook.sh
# Run: bash tests/hook-run.sh from skills/claudboard/scripts/
# Platform: darwin (BSD sed/grep)

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="$SCRIPT_DIR/../stop-hook.sh"
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

# ── trigger gate: /analyse with clean task end ────────────────────────────────
# single-task-opus has /analyse and no AskUserQuestion → should emit cost line, no (in progress)
out=$(CLAUDE_SESSION_JSONL="$F/single-task-opus.jsonl" "$HOOK")
check "hook emits cost line for /analyse" \
  'Cost for /analyse: $0.18 (Opus 4.7, 2 calls, 2K out)' \
  "$out"

# ── trigger gate: /generate ───────────────────────────────────────────────────
out=$(CLAUDE_SESSION_JSONL="$F/mixed-models.jsonl" "$HOOK")
check "hook emits cost line for /generate" \
  'Cost for /generate: $0.12 (mixed, 2 calls, 2K out)' \
  "$out"

# ── no trigger → silent exit ──────────────────────────────────────────────────
out=$(CLAUDE_SESSION_JSONL="$F/no-trigger.jsonl" "$HOOK")
check "hook is silent when no trigger found" "" "$out"

# ── in-progress detection ─────────────────────────────────────────────────────
# topology-paused has /analyse + AskUserQuestion tool_use after trigger → (in progress)
out=$(CLAUDE_SESSION_JSONL="$F/topology-paused.jsonl" "$HOOK")
check "hook appends (in progress) when AskUserQuestion after trigger" \
  'Cost for /analyse: $0.36 (Opus 4.7, 2 calls, 4K out) (in progress)' \
  "$out"

# ── missing JSONL → silent exit (no crash) ────────────────────────────────────
out=$(CLAUDE_SESSION_JSONL="/tmp/nonexistent-session.jsonl" "$HOOK" 2>/dev/null || true)
check "hook is silent for missing JSONL" "" "$out"

# ── summary ───────────────────────────────────────────────────────────────────
echo ""
echo "Results: $pass passed, $fail failed"
[[ "$fail" -eq 0 ]]
