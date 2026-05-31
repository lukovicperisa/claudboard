#!/usr/bin/env bash
# go.sh — Go wide-scan greps for discover.sh.
# Sourced by discover.sh. Defines run_go_scan(repo, outfile).

run_go_scan() {
  local repo="$1"
  local outfile="$2"

  _go_count() {
    grep -rcE "$1" --include='*.go' "$repo" 2>/dev/null \
    | grep -v '/vendor/' | awk -F: 'BEGIN{s=0}{s+=$2}END{print s}'
  }

  # ── Skill triggers ───────────────────────────────────────────────────────
  local t_gin t_echo t_grpc t_chi t_fiber t_http_handler

  t_gin=$(_go_count 'gin\.(Default|New|Engine)|gin\.Context')
  t_echo=$(_go_count 'echo\.New\(\)|e\.GET\(|e\.POST\(')
  t_grpc=$(_go_count 'grpc\.NewServer|grpc\.Dial\b|pb\.|\.pb\.go')
  t_chi=$(_go_count 'chi\.NewRouter\|chi\.Router\b')
  t_fiber=$(_go_count 'fiber\.New\(\)|fiber\.App\b')
  t_http_handler=$(_go_count 'http\.HandleFunc\|http\.ListenAndServe\|mux\.HandleFunc')

  # ── Anti-patterns ────────────────────────────────────────────────────────
  local ap_panic ap_todo ap_bare_err

  ap_panic=$(grep -rcE '\bpanic\(' --include='*.go' "$repo" 2>/dev/null \
    | grep -v '/vendor/' | grep -v '_test\.go' | awk -F: 'BEGIN{s=0}{s+=$2}END{print s}')
  ap_todo=$(_go_count 'TODO|FIXME|HACK')
  ap_bare_err=$(grep -rcE 'if err != nil \{$' --include='*.go' "$repo" 2>/dev/null \
    | grep -v '/vendor/' | awk -F: 'BEGIN{s=0}{s+=$2}END{print s}')

  # ── God candidates ───────────────────────────────────────────────────────
  local god_classes_json
  god_classes_json=$(
    find "$repo" -name '*.go' ! -path '*/vendor/*' ! -name '*_test.go' 2>/dev/null \
    | xargs wc -l 2>/dev/null \
    | grep -v ' total$' \
    | awk '{print $1, $2}' \
    | sort -rn \
    | awk -v repo="$repo" '$1 > 400 {print "{\"file\":\"" $2 "\",\"loc\":" $1 "}"}' \
    | sed "s|\"$repo/|\"| " \
    | head -10 \
    | jq -sc . 2>/dev/null || echo '[]'
  )

  # ── Output JSON ──────────────────────────────────────────────────────────
  jq -n \
    --argjson t_gin "${t_gin:-0}" \
    --argjson t_echo "${t_echo:-0}" \
    --argjson t_grpc "${t_grpc:-0}" \
    --argjson t_chi "${t_chi:-0}" \
    --argjson t_fiber "${t_fiber:-0}" \
    --argjson t_http "${t_http_handler:-0}" \
    --argjson ap_panic "${ap_panic:-0}" \
    --argjson ap_td "${ap_todo:-0}" \
    --argjson ap_err "${ap_bare_err:-0}" \
    --argjson god_classes "${god_classes_json:-[]}" \
    '{
      skill_triggers: {
        "Gin handler":     {count: $t_gin,   best_example: ""},
        "Echo handler":    {count: $t_echo,  best_example: ""},
        "gRPC server":     {count: $t_grpc,  best_example: ""},
        "Chi router":      {count: $t_chi,   best_example: ""},
        "Fiber app":       {count: $t_fiber, best_example: ""},
        "net/http handler":{count: $t_http,  best_example: ""}
      },
      anti_patterns: {
        panic:      $ap_panic,
        todo_fixme: $ap_td,
        bare_error_check: $ap_err
      },
      conventions: {},
      god_class_candidates: $god_classes,
      inheritance_map: []
    }' > "$outfile"
}
