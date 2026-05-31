#!/usr/bin/env bash
#
# compute-cost.sh — compute per-slice cost from a Claude Code session JSONL
#
# IMPORTANT — dedup by requestId (do not bypass):
#   Claude Code writes one JSONL line per assistant content block (thinking, text,
#   each tool_use). All blocks from one API call share the same requestId and usage
#   object. Summing usage per JSONL line over-counts by 3-4x. This script groups by
#   requestId before summing. Remove or bypass at your peril.
#
# Assumed JSONL schema (every field this script reads):
#   .type                                               "assistant" to include
#   .requestId                                          string — dedup key
#   .timestamp                                          ISO-8601 string — time filter
#   .message.model                                      string — model ID for pricing
#   .message.usage.input_tokens                         number
#   .message.usage.cache_creation.ephemeral_5m_input_tokens   number (optional -> 0)
#   .message.usage.cache_creation.ephemeral_1h_input_tokens   number (optional -> 0)
#   .message.usage.cache_read_input_tokens              number (optional -> 0)
#   .message.usage.output_tokens                        number
#
# Schema mismatch on first assistant turn -> non-zero exit + error to stderr.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PRICING_FILE="$SCRIPT_DIR/../references/pricing.md"

# ── help ──────────────────────────────────────────────────────────────────────
show_help() {
  cat <<'EOF'
Usage: compute-cost.sh [OPTIONS] [JSONL_PATH]

Compute per-slice cost from a Claude Code session JSONL transcript.
Deduplicates assistant turns by requestId before summing to avoid 3-4x over-count.

Arguments:
  JSONL_PATH          Session JSONL file (falls back to $CLAUDE_SESSION_JSONL)

Options:
  --since <ISO-8601>  Include turns at or after this timestamp
                        example: --since 2026-05-31T13:06:00.000Z
  --until <ISO-8601>  Include turns strictly before this timestamp
  --format <fmt>      Output format: one-line (default) or json
  --task <cmd>        Command name for the one-line prefix, e.g. --task analyse
                        Without this: "Cost: ..." instead of "Cost for /analyse: ..."
  --help              This message

Environment:
  CLAUDE_SESSION_JSONL  Fallback JSONL path when no positional argument is given

Output:
  one-line  Cost for /analyse: $8.17 (Opus 4.7, 25 calls, 28K out)
  json      {"total_usd":8.17,"model":"claude-opus-4-7","api_calls":25,...}
EOF
}

# ── arg parsing ───────────────────────────────────────────────────────────────
JSONL_PATH=""; SINCE=""; UNTIL=""; FORMAT="one-line"; TASK=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --since)  SINCE="$2";  shift 2 ;;
    --until)  UNTIL="$2";  shift 2 ;;
    --format) FORMAT="$2"; shift 2 ;;
    --task)   TASK="$2";   shift 2 ;;
    --help)   show_help;   exit 0  ;;
    -*)       echo "compute-cost.sh: unknown option: $1" >&2; exit 1 ;;
    *)        JSONL_PATH="$1"; shift ;;
  esac
done

# ── JSONL path resolution ──────────────────────────────────────────────────────
[[ -z "$JSONL_PATH" ]] && JSONL_PATH="${CLAUDE_SESSION_JSONL:-}"
if [[ -z "$JSONL_PATH" ]]; then
  echo "compute-cost.sh: JSONL path required." >&2
  echo "  Pass as argument: compute-cost.sh /path/to/session.jsonl" >&2
  echo "  Or set: export CLAUDE_SESSION_JSONL=/path/to/session.jsonl" >&2
  exit 1
fi
if [[ ! -f "$JSONL_PATH" ]]; then
  echo "compute-cost.sh: file not found: $JSONL_PATH" >&2
  exit 1
fi

# ── schema assertion (first assistant turn) ───────────────────────────────────
_line=0; _checked=false
while IFS= read -r _l; do
  _line=$((_line + 1))
  _type=$(printf '%s' "$_l" | jq -r '.type // ""' 2>/dev/null) || continue
  [[ "$_type" != "assistant" ]] && continue
  _rid=$(printf '%s' "$_l" | jq -r 'if .requestId     != null then "ok" else "x" end' 2>/dev/null)
  _usg=$(printf '%s' "$_l" | jq -r 'if .message.usage != null then "ok" else "x" end' 2>/dev/null)
  if [[ "$_rid" != "ok" || "$_usg" != "ok" ]]; then
    echo "compute-cost.sh: schema mismatch at $JSONL_PATH:$_line" >&2
    echo "  Required: .requestId (string), .message.usage (object)" >&2
    echo "  See assumed-schema comment at the top of $(basename "$0")" >&2
    exit 1
  fi
  _checked=true
  break
done < "$JSONL_PATH"

# ── price table ───────────────────────────────────────────────────────────────
[[ ! -f "$PRICING_FILE" ]] && {
  echo "compute-cost.sh: pricing file not found: $PRICING_FILE" >&2; exit 1
}

# Parse pricing.md -> JSON: {"model-id":{"d":"Display","i":15,"c5":18.75,"c1h":30,"cr":1.5,"o":75},...}
# Keeps the latest effective_from row per model (lexicographic YYYY-MM-DD compare).
PRICE_JSON=$(awk -F'|' '
  /^[[:space:]]*\|[-: ]+\|/ { next }
  /model_id/ { next }
  /^[[:space:]]*\|/ {
    for (i = 1; i <= NF; i++) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", $i) }
    if ($2 == "" || $5 == "") next
    if (!($2 in eff) || $4 > eff[$2]) {
      eff[$2]=$4; d[$2]=$3; ii[$2]=$5; c5[$2]=$6; c1h[$2]=$7; cr[$2]=$8; o[$2]=$9
    }
  }
  END {
    printf "{"
    sep = ""
    for (k in eff) {
      printf "%s\"%s\":{\"d\":\"%s\",\"i\":%s,\"c5\":%s,\"c1h\":%s,\"cr\":%s,\"o\":%s}",
             sep, k, d[k], ii[k], c5[k], c1h[k], cr[k], o[k]
      sep = ","
    }
    printf "}"
  }
' "$PRICING_FILE")

# ── jq pipeline: filter -> dedup -> aggregate -> price ────────────────────────
JQ_PROG='
  def r($m): (($prices | .[$m]) // ($prices | .["claude-sonnet-4-6"]));
  def cost($row):
    ($row.tok.inp * (r($row.model).i   // 0) +
     $row.tok.c5  * (r($row.model).c5  // 0) +
     $row.tok.c1h * (r($row.model).c1h // 0) +
     $row.tok.cr  * (r($row.model).cr  // 0) +
     $row.tok.out * (r($row.model).o   // 0)) / 1000000;

  [.[] | select(.type == "assistant")]
  | map(select(($since == "" or .timestamp >= $since) and
               ($until == "" or .timestamp < $until)))
  | group_by(.requestId) | map(.[0])
  | group_by(.message.model)
  | map({
      model: .[0].message.model,
      calls: length,
      tok: {
        inp: ([.[].message.usage.input_tokens // 0] | add // 0),
        c5:  ([.[].message.usage.cache_creation.ephemeral_5m_input_tokens // 0] | add // 0),
        c1h: ([.[].message.usage.cache_creation.ephemeral_1h_input_tokens // 0] | add // 0),
        cr:  ([.[].message.usage.cache_read_input_tokens // 0] | add // 0),
        out: ([.[].message.usage.output_tokens // 0] | add // 0)
      }
    })
  | . as $rows |
  {
    total_calls:   ([$rows[].calls]     | add // 0),
    total_out:     ([$rows[].tok.out]   | add // 0),
    total_usd:     ([$rows[] | cost(.)] | add // 0),
    models:        [$rows[].model],
    display_names: [$rows[] | .model as $m | ((($prices | .[$m]).d?) // $m)],
    unknown:       ([$rows[] | .model as $m | select(($prices | .[$m]) == null) | $m] | unique),
    tokens: {
      input_uncached: ([$rows[].tok.inp] | add // 0),
      cache_write_5m: ([$rows[].tok.c5]  | add // 0),
      cache_write_1h: ([$rows[].tok.c1h] | add // 0),
      cache_read:     ([$rows[].tok.cr]  | add // 0),
      output:         ([$rows[].tok.out] | add // 0)
    },
    breakdown: {
      input_uncached: ([$rows[] | .tok.inp * (r(.model).i   // 0) / 1000000] | add // 0),
      cache_write_5m: ([$rows[] | .tok.c5  * (r(.model).c5  // 0) / 1000000] | add // 0),
      cache_write_1h: ([$rows[] | .tok.c1h * (r(.model).c1h // 0) / 1000000] | add // 0),
      cache_read:     ([$rows[] | .tok.cr  * (r(.model).cr  // 0) / 1000000] | add // 0),
      output:         ([$rows[] | .tok.out * (r(.model).o   // 0) / 1000000] | add // 0)
    }
  }
'

RESULT=$(jq -sc "$JQ_PROG" \
  --argjson prices "$PRICE_JSON" \
  --arg since "$SINCE" \
  --arg until "$UNTIL" \
  "$JSONL_PATH")

# ── warnings for unknown models ───────────────────────────────────────────────
printf '%s' "$RESULT" | jq -r '.unknown[]' 2>/dev/null | while IFS= read -r _m; do
  echo "WARN: unknown model \"$_m\" -- pricing as Sonnet 4.6 fallback. Add to references/pricing.md." >&2
done

# ── output ────────────────────────────────────────────────────────────────────
TOTAL_USD=$(printf '%s' "$RESULT" | jq -r '.total_usd')
TOTAL_CALLS=$(printf '%s' "$RESULT" | jq -r '.total_calls')
TOTAL_OUT=$(printf '%s' "$RESULT" | jq -r '.total_out')
MODEL_COUNT=$(printf '%s' "$RESULT" | jq '.models | length')

TOTAL_FMT=$(awk -v n="$TOTAL_USD" 'BEGIN { printf "%.2f", n }')

if [[ "$MODEL_COUNT" -le 1 ]]; then
  MODEL_DISP=$(printf '%s' "$RESULT" | jq -r '.display_names[0] // "none"')
else
  MODEL_DISP="mixed"
fi

OUT_FMT=$(awk -v n="$TOTAL_OUT" 'BEGIN { printf "%s", (n >= 1000) ? int(n/1000) "K" : n }')

if [[ "$FORMAT" == "json" ]]; then
  MODEL_COUNT_VAL=$(printf '%s' "$RESULT" | jq '.models | length')
  if [[ "$MODEL_COUNT_VAL" -le 1 ]]; then
    MODEL_JSON_VAL=$(printf '%s' "$RESULT" | jq '.models[0] // "none"')
  else
    MODEL_JSON_VAL=$(printf '%s' "$RESULT" | jq '.models')
  fi
  printf '%s' "$RESULT" | jq \
    --argjson model_val "$MODEL_JSON_VAL" \
    --arg since "$SINCE" \
    --arg until "$UNTIL" \
    '{
      total_usd:          (.total_usd * 10000 | round | . / 10000),
      model:              $model_val,
      api_calls:          .total_calls,
      tokens:             .tokens,
      cost_breakdown_usd: .breakdown,
      slice: {
        since: (if $since == "" then null else $since end),
        until: (if $until == "" then null else $until end)
      }
    }'
elif [[ "$FORMAT" == "one-line" ]]; then
  if [[ -n "$TASK" ]]; then
    echo "Cost for /$TASK: \$$TOTAL_FMT ($MODEL_DISP, $TOTAL_CALLS calls, $OUT_FMT out)"
  else
    echo "Cost: \$$TOTAL_FMT ($MODEL_DISP, $TOTAL_CALLS calls, $OUT_FMT out)"
  fi
else
  echo "compute-cost.sh: unknown format: $FORMAT (use one-line or json)" >&2
  exit 1
fi
