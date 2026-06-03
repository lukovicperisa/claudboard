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

# Hook emits a `{"systemMessage": "..."}` JSON envelope on stdout. Tests
# parse the envelope with jq and assert on the inner message.
msg() { jq -r '.systemMessage // empty'; }

# ── trigger gate: /analyse with clean task end ────────────────────────────────
# single-task-opus has /analyse and no AskUserQuestion → should emit cost line, no (in progress)
out=$(HOME=$(mktemp -d) CLAUDE_SESSION_JSONL="$F/single-task-opus.jsonl" "$HOOK" | msg)
check "hook emits cost line for /analyse" \
  'Cost for /analyse: $0.06 (Opus 4.7 (Vertex), 2 calls, 2K out)' \
  "$out"

# ── trigger gate: /generate ───────────────────────────────────────────────────
out=$(HOME=$(mktemp -d) CLAUDE_SESSION_JSONL="$F/mixed-models.jsonl" "$HOOK" | msg)
check "hook emits cost line for /generate" \
  'Cost for /generate: $0.06 (mixed, 2 calls, 2K out)' \
  "$out"

# ── no trigger → silent exit ──────────────────────────────────────────────────
out=$(HOME=$(mktemp -d) CLAUDE_SESSION_JSONL="$F/no-trigger.jsonl" "$HOOK")
check "hook is silent when no trigger found" "" "$out"

# ── namespaced trigger (/claudboard:claudboard-analyse) ───────────────────────
# namespaced-trigger.jsonl has the plugin-namespaced wrapped form; regex must match
out=$(HOME=$(mktemp -d) CLAUDE_SESSION_JSONL="$F/namespaced-trigger.jsonl" "$HOOK" | msg)
if [[ -n "$out" ]] && echo "$out" | grep -q '/analyse'; then
  echo "PASS: hook emits cost line for namespaced /claudboard:claudboard-analyse"
  pass=$((pass + 1))
else
  echo "FAIL: hook emits cost line for namespaced /claudboard:claudboard-analyse"
  echo "  actual: $out"
  fail=$((fail + 1))
fi

# ── missing JSONL → silent exit (no crash) ────────────────────────────────────
out=$(HOME=$(mktemp -d) CLAUDE_SESSION_JSONL="/tmp/nonexistent-session.jsonl" "$HOOK" 2>/dev/null || true)
check "hook is silent for missing JSONL" "" "$out"

# ── free-text chat mentioning verbs → silent exit (no false positive) ─────────
out=$(HOME=$(mktemp -d) CLAUDE_SESSION_JSONL="$F/chat-mentions-trigger.jsonl" "$HOOK")
check "hook is silent when trigger verbs appear only in free-text chat" "" "$out"

# ── emit-once: second invocation against same trigger is silent ───────────────
SHARED_HOME=$(mktemp -d)
out1=$(HOME="$SHARED_HOME" CLAUDE_SESSION_JSONL="$F/multi-stop-single-trigger.jsonl" "$HOOK" | msg)
out2=$(HOME="$SHARED_HOME" CLAUDE_SESSION_JSONL="$F/multi-stop-single-trigger.jsonl" "$HOOK")
if [[ -n "$out1" ]] && echo "$out1" | grep -q '/analyse'; then
  echo "PASS: multi-stop first invocation emits cost line for /analyse"
  pass=$((pass + 1))
else
  echo "FAIL: multi-stop first invocation emits cost line for /analyse"
  echo "  actual: $out1"
  fail=$((fail + 1))
fi
check "multi-stop second invocation is silent (emit-once gate)" "" "$out2"

# ── marker file created after first emission ──────────────────────────────────
marker_count=$(find "$SHARED_HOME/.claude" -name "*.marker" 2>/dev/null | wc -l | tr -d ' ')
if [[ "$marker_count" -eq 1 ]]; then
  echo "PASS: exactly one marker file created after first emission"
  pass=$((pass + 1))
else
  echo "FAIL: expected 1 marker file, found $marker_count"
  fail=$((fail + 1))
fi

# ── summary ───────────────────────────────────────────────────────────────────
echo ""
echo "Results: $pass passed, $fail failed"
[[ "$fail" -eq 0 ]]
