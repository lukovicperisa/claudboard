#!/usr/bin/env bash
# dotnet.sh — .NET/C# wide-scan greps for discover.sh.
# Sourced by discover.sh. Defines run_dotnet_scan(repo, outfile).

run_dotnet_scan() {
  local repo="$1"
  local outfile="$2"

  _cs_count() {
    grep -rcE "$1" --include='*.cs' "$repo" 2>/dev/null \
    | awk -F: 'BEGIN{s=0}{s+=$2}END{print s}'
  }

  # ── Skill triggers ───────────────────────────────────────────────────────
  local t_controller t_api_controller t_mediatr t_entity t_dapper
  local t_minimal_api t_grpc t_signalr

  t_controller=$(_cs_count '\[ApiController\]|\[Controller\]')
  t_api_controller=$(_cs_count ': ControllerBase\b|: Controller\b')
  t_mediatr=$(_cs_count 'IRequest\b|IRequestHandler\b|IMediator\b|MediatR\b')
  t_entity=$(_cs_count 'DbContext\b|DbSet<\b|modelBuilder\.')
  t_dapper=$(_cs_count 'Dapper\b|QueryAsync\b|ExecuteAsync\b')
  t_minimal_api=$(_cs_count '\.MapGet\(|\.MapPost\(|\.MapPut\(|\.MapDelete\(|WebApplication\.Create')
  t_grpc=$(_cs_count 'Grpc\b|\.proto\b|ServerStreamingServerMethod\b')
  t_signalr=$(_cs_count 'Hub\b|IHubContext\b|SignalR\b')

  # ── Anti-patterns ────────────────────────────────────────────────────────
  local ap_catch_all ap_todo ap_null

  ap_catch_all=$(_cs_count 'catch \(Exception\b|catch \(System\.Exception\b')
  ap_todo=$(_cs_count 'TODO|FIXME|HACK')
  ap_null=$(_cs_count 'return null;')

  # ── God class candidates ─────────────────────────────────────────────────
  local god_classes_json
  god_classes_json=$(
    find "$repo" -name '*.cs' 2>/dev/null \
    | xargs wc -l 2>/dev/null \
    | grep -v ' total$' \
    | awk '{print $1, $2}' \
    | sort -rn \
    | awk -v repo="$repo" '$1 > 300 {print "{\"file\":\"" $2 "\",\"loc\":" $1 "}"}' \
    | sed "s|\"$repo/|\"| " \
    | head -10 \
    | jq -sc . 2>/dev/null || echo '[]'
  )

  # ── Output JSON ──────────────────────────────────────────────────────────
  jq -n \
    --argjson t_ctrl "${t_controller:-0}" \
    --argjson t_api "${t_api_controller:-0}" \
    --argjson t_med "${t_mediatr:-0}" \
    --argjson t_ef "${t_entity:-0}" \
    --argjson t_dp "${t_dapper:-0}" \
    --argjson t_min "${t_minimal_api:-0}" \
    --argjson t_grpc "${t_grpc:-0}" \
    --argjson t_sr "${t_signalr:-0}" \
    --argjson ap_ca "${ap_catch_all:-0}" \
    --argjson ap_td "${ap_todo:-0}" \
    --argjson ap_nl "${ap_null:-0}" \
    --argjson god_classes "${god_classes_json:-[]}" \
    '{
      skill_triggers: {
        "[ApiController]":  {count: $t_ctrl, best_example: ""},
        "ControllerBase":   {count: $t_api,  best_example: ""},
        "MediatR IRequest": {count: $t_med,  best_example: ""},
        "EF Core DbContext":{count: $t_ef,   best_example: ""},
        "Dapper":           {count: $t_dp,   best_example: ""},
        "Minimal API":      {count: $t_min,  best_example: ""},
        "gRPC service":     {count: $t_grpc, best_example: ""},
        "SignalR Hub":      {count: $t_sr,   best_example: ""}
      },
      anti_patterns: {
        broad_exception_catch: $ap_ca,
        todo_fixme:            $ap_td,
        null_returns:          $ap_nl
      },
      conventions: {},
      god_class_candidates: $god_classes,
      inheritance_map: []
    }' > "$outfile"
}
