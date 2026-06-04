#!/usr/bin/env bash
#
# stop-hook.sh — Claude Code Stop hook for claudboard per-task cost reporting
#
# Fires on every Stop event. Scans the session JSONL for the most recent
# /analyse, /generate, /refresh, /techdebt, or /workflow user trigger; if found,
# calls compute-cost.sh and emits one cost line to stdout. Exits silently (no
# output) when no claudboard trigger is in the session.
#
# No model API calls are made — this script runs at $0 API token cost.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPUTE="$SCRIPT_DIR/compute-cost.sh"

# ── JSONL path resolution ──────────────────────────────────────────────────────
# Claude Code Stop hooks receive input as JSON on stdin. The canonical field is
# .transcript_path (per code.claude.com/docs/en/hooks.md#common-input-fields).
# Env vars are fallbacks for SDK / manual invocation only.
HOOK_INPUT=$(cat 2>/dev/null || true)
JSONL_PATH=$(printf '%s' "$HOOK_INPUT" | jq -r '.transcript_path // empty' 2>/dev/null || true)

if [[ -z "$JSONL_PATH" ]]; then
  JSONL_PATH="${CLAUDE_SESSION_JSONL:-}"
fi

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
# Requires the <command-name>...</command-name> wrapper — free-text chat that
# merely mentions the verbs will never match.
TRIGGER_JSON=$(jq -sc '
  [.[] | select(.type == "user")]
  | map(
      .timestamp as $ts |
      (.message.content |
        if   type == "string" then .
        elif type == "array"  then (.[0].text? // "")
        else ""
        end) as $text |
      select($text | test("<command-name>/(?:claudboard:claudboard-)?(?:analyse|generate|refresh|techdebt|workflow)</command-name>")) |
      { timestamp: $ts,
        cmd: ($text
          | capture("<command-name>/(?:claudboard:claudboard-)?(?<c>analyse|generate|refresh|techdebt|workflow)</command-name>")
          | .c) }
    )
  | last? // null
' "$JSONL_PATH" 2>/dev/null) || exit 0

[[ -z "$TRIGGER_JSON" || "$TRIGGER_JSON" == "null" ]] && exit 0

TRIGGER_TS=$(printf '%s' "$TRIGGER_JSON" | jq -r '.timestamp')
TRIGGER_CMD=$(printf '%s' "$TRIGGER_JSON" | jq -r '.cmd')

# ── emit-once gate ────────────────────────────────────────────────────────────
# Extract sessionId from the JSONL (first entry that has it); fall back to env.
SESSION_ID=$(jq -r 'select(.sessionId != null) | .sessionId' "$JSONL_PATH" 2>/dev/null | head -1)
SESSION_ID="${SESSION_ID:-${CLAUDE_CODE_SESSION_ID:-}}"

CWD_SLUG=$(pwd | sed 's|/|-|g')
MARKER_DIR="${HOME}/.claude/projects/${CWD_SLUG}/.claudboard-cost-emitted"
MARKER_FILE="${MARKER_DIR}/${SESSION_ID}__${TRIGGER_TS}.marker"

[[ -f "$MARKER_FILE" ]] && exit 0

# ── emit cost line ────────────────────────────────────────────────────────────
COST_LINE=$("$COMPUTE" --since "$TRIGGER_TS" --task "$TRIGGER_CMD" "$JSONL_PATH" 2>/dev/null) || exit 0
[[ -z "$COST_LINE" ]] && exit 0

jq -nc --arg msg "$COST_LINE" '{systemMessage: $msg}'

mkdir -p "$MARKER_DIR" || true
printf '%s\n' "$COST_LINE" > "$MARKER_FILE" || true
