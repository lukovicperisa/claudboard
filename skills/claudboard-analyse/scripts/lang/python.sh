#!/usr/bin/env bash
# python.sh — Python wide-scan greps for discover.sh.
# Sourced by discover.sh. Defines run_python_scan(repo, outfile).

run_python_scan() {
  local repo="$1"
  local outfile="$2"

  _py_count() {
    grep -rcE "$1" --include='*.py' "$repo" 2>/dev/null \
    | grep -v '\.venv\|__pycache__' | awk -F: 'BEGIN{s=0}{s+=$2}END{print s}'
  }

  # ── Skill triggers ───────────────────────────────────────────────────────
  local t_fastapi_route t_flask_route t_celery t_pydantic t_mcp_tool
  local t_langchain t_anthropic t_openai

  t_fastapi_route=$(_py_count '@router\.(get|post|put|delete|patch)|@app\.(get|post|put|delete|patch)')
  t_flask_route=$(_py_count '@app\.route\b')
  t_celery=$(_py_count '@celery\.task\b|@shared_task\b|class.*Task\b')
  t_pydantic=$(_py_count 'class.*\(BaseModel\)\b|class.*\(BaseSettings\)\b')
  t_mcp_tool=$(_py_count '@tool\b|tool_use\b|@server\.tool\b|mcp\.tool\b')
  t_langchain=$(_py_count 'langchain\b|LLMChain\b|ChatOpenAI\b')
  t_anthropic=$(_py_count 'anthropic\b|Anthropic\b|claude\b')
  t_openai=$(_py_count 'openai\b|OpenAI\b|ChatCompletion\b')

  # ── Anti-patterns ────────────────────────────────────────────────────────
  local ap_broad_ex ap_type_ignore ap_todo

  ap_broad_ex=$(_py_count 'except Exception\b|except:\b|bare except')
  ap_type_ignore=$(_py_count '# type: ignore|# noqa\b')
  ap_todo=$(_py_count 'TODO|FIXME|HACK')

  # ── God class candidates ─────────────────────────────────────────────────
  local god_classes_json
  god_classes_json=$(
    find "$repo" -name '*.py' \
      ! -path '*/.venv/*' ! -path '*/test*' ! -path '*/__pycache__/*' 2>/dev/null \
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
    --argjson t_fa "${t_fastapi_route:-0}" \
    --argjson t_fl "${t_flask_route:-0}" \
    --argjson t_ce "${t_celery:-0}" \
    --argjson t_py "${t_pydantic:-0}" \
    --argjson t_mt "${t_mcp_tool:-0}" \
    --argjson t_lc "${t_langchain:-0}" \
    --argjson t_an "${t_anthropic:-0}" \
    --argjson t_oa "${t_openai:-0}" \
    --argjson ap_be "${ap_broad_ex:-0}" \
    --argjson ap_ti "${ap_type_ignore:-0}" \
    --argjson ap_td "${ap_todo:-0}" \
    --argjson god_classes "${god_classes_json:-[]}" \
    '{
      skill_triggers: {
        "FastAPI route":    {count: $t_fa, best_example: ""},
        "Flask route":      {count: $t_fl, best_example: ""},
        "Celery task":      {count: $t_ce, best_example: ""},
        "Pydantic model":   {count: $t_py, best_example: ""},
        "MCP tool":         {count: $t_mt, best_example: ""},
        "LangChain":        {count: $t_lc, best_example: ""},
        "Anthropic SDK":    {count: $t_an, best_example: ""},
        "OpenAI SDK":       {count: $t_oa, best_example: ""}
      },
      anti_patterns: {
        broad_exception_catch: $ap_be,
        type_ignore:           $ap_ti,
        todo_fixme:            $ap_td
      },
      conventions: {},
      god_class_candidates: $god_classes,
      inheritance_map: []
    }' > "$outfile"
}
