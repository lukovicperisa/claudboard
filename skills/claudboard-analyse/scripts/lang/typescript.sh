#!/usr/bin/env bash
# typescript.sh — TypeScript/JavaScript wide-scan greps for discover.sh.
# Sourced by discover.sh. Defines run_typescript_scan(repo, outfile).

run_typescript_scan() {
  local repo="$1"
  local outfile="$2"

  local src="$repo/src"
  # Also check repo root for MCP-style projects with flat layout
  if [ ! -d "$src" ]; then src="$repo"; fi

  _ts_count() {
    grep -rcE "$1" --include='*.ts' --include='*.tsx' \
      "$src" 2>/dev/null \
    | grep -v node_modules | awk -F: 'BEGIN{s=0}{s+=$2}END{print s}'
  }

  # ── Skill triggers ───────────────────────────────────────────────────────
  local t_usequery t_usestate t_hookform t_zustand t_redux t_modfed
  local t_nestctrl t_resolver t_tool t_celery_or_worker
  local t_mcp_tool

  t_usequery=$(_ts_count 'useQuery|useMutation')
  t_usestate=$(_ts_count '\buseState\b|\buseEffect\b|\buseMemo\b|\buseCallback\b')
  t_hookform=$(_ts_count 'useForm\b|react-hook-form')
  t_zustand=$(_ts_count '\bzustand\b|createStore|useStore\b')
  t_redux=$(_ts_count 'createSlice|createAsyncThunk|configureStore')
  t_modfed=$(_ts_count 'ModuleFederationPlugin')
  t_nestctrl=$(_ts_count '@Controller\b|@Get\b|@Post\b|@Put\b|@Delete\b|@Patch\b')
  t_resolver=$(_ts_count '@Resolver\b|@Query\b|@Mutation\b')
  t_mcp_tool=$(_ts_count '@tool\b|tool_use\b|\.tool\(')

  # Best example: smallest file with the trigger
  _ts_best_example() {
    local pattern="$1"
    grep -rlE "$pattern" --include='*.ts' --include='*.tsx' "$src" 2>/dev/null \
    | grep -v node_modules | head -20 \
    | while read -r f; do
        wc -l < "$f" | tr -d ' '
        echo " $f"
      done \
    | sort -n | head -1 | awk '{print $2}' | sed "s|$repo/||"
  }

  local be_usequery be_nestctrl be_resolver be_mcp
  be_usequery=$(_ts_best_example 'useQuery|useMutation')
  be_nestctrl=$(_ts_best_example '@Controller\b|@Get\b')
  be_resolver=$(_ts_best_example '@Resolver\b')
  be_mcp=$(_ts_best_example '@tool\b|tool_use\b')

  # ── Anti-patterns ────────────────────────────────────────────────────────
  local ap_any ap_console ap_todo

  ap_any=$(grep -rcE '\bany\b| as any\b|// @ts-ignore|// @ts-nocheck' \
    --include='*.ts' --include='*.tsx' "$src" 2>/dev/null \
    | grep -v node_modules | awk -F: 'BEGIN{s=0}{s+=$2}END{print s}')

  ap_console=$(grep -rcE '\bconsole\.log\b' \
    --include='*.ts' --include='*.tsx' "$src" 2>/dev/null \
    | grep -v node_modules \
    | grep -v 'test\|spec\|__tests__' \
    | awk -F: 'BEGIN{s=0}{s+=$2}END{print s}')

  ap_todo=$(grep -rcE 'TODO|FIXME|HACK' \
    --include='*.ts' --include='*.tsx' --include='*.js' "$src" 2>/dev/null \
    | grep -v node_modules | awk -F: 'BEGIN{s=0}{s+=$2}END{print s}')

  # ── God class candidates ─────────────────────────────────────────────────
  local god_classes_json
  god_classes_json=$(
    find "$repo" \( -name '*.ts' -o -name '*.tsx' \) \
      ! -path '*/node_modules/*' ! -path '*/dist/*' ! -path '*/build/*' 2>/dev/null \
    | xargs wc -l 2>/dev/null \
    | grep -v ' total$' \
    | awk '{print $1, $2}' \
    | sort -rn \
    | awk -v repo="$repo" '$1 > 300 {print "{\"file\":\"" $2 "\",\"loc\":" $1 "}"}' \
    | sed "s|\"$repo/|\"| " \
    | head -10 \
    | jq -sc . 2>/dev/null || echo '[]'
  )

  # ── Conventions ──────────────────────────────────────────────────────────
  local alias_imports rel_imports ts_import_style
  alias_imports=$(grep -rcE "from '@/" --include='*.ts' --include='*.tsx' "$src" 2>/dev/null \
    | grep -v node_modules | awk -F: 'BEGIN{s=0}{s+=$2}END{print s}')
  rel_imports=$(grep -rcE "from '\.\./" --include='*.ts' --include='*.tsx' "$src" 2>/dev/null \
    | grep -v node_modules | awk -F: 'BEGIN{s=0}{s+=$2}END{print s}')
  if [ "${alias_imports:-0}" -gt "${rel_imports:-0}" ] 2>/dev/null; then
    ts_import_style="alias"
  elif [ "${rel_imports:-0}" -gt 0 ] 2>/dev/null; then
    ts_import_style="relative"
  else
    ts_import_style="unknown"
  fi

  # ── Output JSON ──────────────────────────────────────────────────────────
  jq -n \
    --argjson t_uq "${t_usequery:-0}" \
    --argjson t_us "${t_usestate:-0}" \
    --argjson t_hf "${t_hookform:-0}" \
    --argjson t_zu "${t_zustand:-0}" \
    --argjson t_rx "${t_redux:-0}" \
    --argjson t_mf "${t_modfed:-0}" \
    --argjson t_nc "${t_nestctrl:-0}" \
    --argjson t_rs "${t_resolver:-0}" \
    --argjson t_mt "${t_mcp_tool:-0}" \
    --arg be_uq "${be_usequery:-}" \
    --arg be_nc "${be_nestctrl:-}" \
    --arg be_rs "${be_resolver:-}" \
    --arg be_mt "${be_mcp:-}" \
    --argjson ap_any "${ap_any:-0}" \
    --argjson ap_con "${ap_console:-0}" \
    --argjson ap_td "${ap_todo:-0}" \
    --arg ts_import "${ts_import_style:-unknown}" \
    --argjson god_classes "${god_classes_json:-[]}" \
    '{
      skill_triggers: {
        "useQuery/useMutation":  {count: $t_uq, best_example: $be_uq},
        "useState/useEffect":    {count: $t_us, best_example: ""},
        "react-hook-form":       {count: $t_hf, best_example: ""},
        "zustand":               {count: $t_zu, best_example: ""},
        "Redux Toolkit":         {count: $t_rx, best_example: ""},
        "ModuleFederation":      {count: $t_mf, best_example: ""},
        "@Controller/@Get":      {count: $t_nc, best_example: $be_nc},
        "@Resolver/@Query":      {count: $t_rs, best_example: $be_rs},
        "MCP tool":              {count: $t_mt, best_example: $be_mt}
      },
      anti_patterns: {
        ts_any:      $ap_any,
        console_log: $ap_con,
        todo_fixme:  $ap_td
      },
      conventions: {
        ts_import_style: $ts_import
      },
      god_class_candidates: $god_classes,
      inheritance_map: []
    }' > "$outfile"
}
