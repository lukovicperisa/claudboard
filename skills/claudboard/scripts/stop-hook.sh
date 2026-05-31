#!/usr/bin/env bash
#
# stop-hook.sh — Claude Code Stop hook for claudboard per-task cost reporting
#
# Fires on every Stop event. Scans the session JSONL for the most recent
# /analyse, /generate, /refresh, or /techdebt user trigger; if found, calls
# compute-cost.sh and emits one cost line to stdout. Exits silently (no output)
# when no claudboard trigger is in the session.
#
# No model API calls are made — this script runs at $0 API token cost.
#
# Installation (in .claude/settings.json or settings.local.json):
#   "hooks": {
#     "Stop": [{
#       "matcher": "",
#       "hooks": [{"type":"command","command":"/abs/path/to/stop-hook.sh"}]
#     }]
#   }

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPUTE="$SCRIPT_DIR/compute-cost.sh"

# ── JSONL path resolution ──────────────────────────────────────────────────────
# Prefer CLAUDE_SESSION_JSONL (set by harness); fall back to computed path.
JSONL_PATH="${CLAUDE_SESSION_JSONL:-}"
if [[ -z "$JSONL_PATH" ]]; then
  SESSION_ID="${CLAUDE_CODE_SESSION_ID:-}"
  if [[ -z "$SESSION_ID" ]]; then
    exit 0
  fi
  CWD_SLUG=$(pwd | sed 's|/|-|g')
  JSONL_PATH="$HOME/.claude/projects/${CWD_SLUG}/${SESSION_ID}.jsonl"
fi

[[ ! -f "$JSONL_PATH" ]] && exit 0

# ── find the most recent claudboard trigger ────────────────────────────────────
# Walk user turns and match /analyse /generate /refresh /techdebt.
TRIGGER_JSON=$(jq -sc '
  [.[] | select(.type == "user")]
  | map(
      .timestamp as $ts |
      (.message.content |
        if   type == "string" then .
        elif type == "array"  then (.[0].text? // "")
        else ""
        end) as $text |
      select($text | test("^[[:space:]]*/(?:analyse|generate|refresh|techdebt)\\b")) |
      { timestamp: $ts,
        cmd: ($text | capture("^[[:space:]]*/(?<c>analyse|generate|refresh|techdebt)\\b") | .c) }
    )
  | last? // null
' "$JSONL_PATH" 2>/dev/null) || exit 0

[[ -z "$TRIGGER_JSON" || "$TRIGGER_JSON" == "null" ]] && exit 0

TRIGGER_TS=$(printf '%s' "$TRIGGER_JSON" | jq -r '.timestamp')
TRIGGER_CMD=$(printf '%s' "$TRIGGER_JSON" | jq -r '.cmd')

# ── in-progress detection ─────────────────────────────────────────────────────
# Most recent assistant entry with AskUserQuestion tool_use after the trigger
# timestamp => task is paused, not complete.
IN_PROGRESS=false
LAST_AQ_TS=$(jq -sc '
  [.[] |
    select(.type == "assistant") |
    select(.message.content != null) |
    select(.message.content | type == "array") |
    select(.message.content |
      map(select(.type == "tool_use" and .name == "AskUserQuestion")) | length > 0)
  ] | if length > 0 then .[-1].timestamp else null end
' "$JSONL_PATH" 2>/dev/null) || true

LAST_AQ_TS=$(printf '%s' "$LAST_AQ_TS" | jq -r '.')
if [[ -n "$LAST_AQ_TS" && "$LAST_AQ_TS" != "null" && "$LAST_AQ_TS" > "$TRIGGER_TS" ]]; then
  IN_PROGRESS=true
fi

# ── emit cost line ────────────────────────────────────────────────────────────
COST_LINE=$("$COMPUTE" --since "$TRIGGER_TS" --task "$TRIGGER_CMD" "$JSONL_PATH" 2>/dev/null) || exit 0
[[ -z "$COST_LINE" ]] && exit 0

if $IN_PROGRESS; then
  echo "$COST_LINE (in progress)"
else
  echo "$COST_LINE"
fi
