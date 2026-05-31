#!/usr/bin/env bash
# rust.sh — Rust wide-scan greps for discover.sh.
# Sourced by discover.sh. Defines run_rust_scan(repo, outfile).

run_rust_scan() {
  local repo="$1"
  local outfile="$2"

  _rs_count() {
    grep -rcE "$1" --include='*.rs' "$repo" 2>/dev/null \
    | grep -v '/target/' | awk -F: 'BEGIN{s=0}{s+=$2}END{print s}'
  }

  # ── Skill triggers ───────────────────────────────────────────────────────
  local t_actix t_axum t_rocket t_tokio t_async_fn t_trait

  t_actix=$(_rs_count 'actix_web\b|web::get\(\)|web::post\(\)|HttpServer::new')
  t_axum=$(_rs_count 'axum\b|Router::new\(\)|axum::routing')
  t_rocket=$(_rs_count 'rocket\b|#\[get\(|#\[post\(|#\[launch\]')
  t_tokio=$(_rs_count '#\[tokio::main\]|tokio::spawn\b|tokio::select\b')
  t_async_fn=$(_rs_count '\basync fn \b')
  t_trait=$(_rs_count '^pub trait \b|^trait \b')

  # ── Anti-patterns ────────────────────────────────────────────────────────
  local ap_unwrap ap_todo ap_unsafe

  ap_unwrap=$(grep -rcE '\.unwrap\(\)' --include='*.rs' "$repo" 2>/dev/null \
    | grep -v '/target/' | grep -v '_test\|tests/' | awk -F: 'BEGIN{s=0}{s+=$2}END{print s}')
  ap_todo=$(_rs_count 'todo!\(\)|TODO|FIXME|HACK')
  ap_unsafe=$(grep -rcE '\bunsafe\s+\{|\bunsafe\s+fn \b' --include='*.rs' "$repo" 2>/dev/null \
    | grep -v '/target/' | awk -F: 'BEGIN{s=0}{s+=$2}END{print s}')

  # ── Output JSON ──────────────────────────────────────────────────────────
  jq -n \
    --argjson t_actix "${t_actix:-0}" \
    --argjson t_axum "${t_axum:-0}" \
    --argjson t_rocket "${t_rocket:-0}" \
    --argjson t_tokio "${t_tokio:-0}" \
    --argjson t_async "${t_async_fn:-0}" \
    --argjson t_trait "${t_trait:-0}" \
    --argjson ap_uw "${ap_unwrap:-0}" \
    --argjson ap_td "${ap_todo:-0}" \
    --argjson ap_us "${ap_unsafe:-0}" \
    '{
      skill_triggers: {
        "Actix-web handler":  {count: $t_actix,  best_example: ""},
        "Axum router":        {count: $t_axum,   best_example: ""},
        "Rocket handler":     {count: $t_rocket, best_example: ""},
        "Tokio async":        {count: $t_tokio,  best_example: ""},
        "async fn":           {count: $t_async,  best_example: ""},
        "trait declaration":  {count: $t_trait,  best_example: ""}
      },
      anti_patterns: {
        unwrap_calls: $ap_uw,
        todo_fixme:   $ap_td,
        unsafe_blocks: $ap_us
      },
      conventions: {},
      god_class_candidates: [],
      inheritance_map: []
    }' > "$outfile"
}
