#!/usr/bin/env bash
# detect.sh — claudboard-workflow detection script (schema_version 1)
# Usage: bash scripts/detect.sh <project-path>
# Emits a single JSON document to stdout. Errors go to stderr. Read-only.
#
# Exit codes: 0 = success (JSON on stdout)
#             1 = fatal error (message on stderr, no stdout)

set -uo pipefail

SCHEMA_VERSION="1"
PROJECT_PATH="${1:-}"

# ─── Preflight ────────────────────────────────────────────────────────────────

if [[ -z "$PROJECT_PATH" ]]; then
  printf 'Usage: detect.sh <project-path>\n' >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  cat >&2 <<'MSG'
Error: jq not found. Install it:
  macOS:   brew install jq
  Debian:  sudo apt install jq
  Fedora:  sudo dnf install jq
MSG
  exit 1
fi

if [[ ! -d "$PROJECT_PATH" ]]; then
  printf 'Error: not a directory: %s\n' "$PROJECT_PATH" >&2
  exit 1
fi

PROJECT_PATH="$(cd "$PROJECT_PATH" && pwd)"

# ─── Warning accumulation ─────────────────────────────────────────────────────
# Use a temp file so warnings written inside $() subshells persist in the parent.

WARN_TMP=$(mktemp)
trap 'rm -f "$WARN_TMP"' EXIT

warn() { printf '%s\0' "$1" >> "$WARN_TMP"; }

# ─── MCP file helpers ─────────────────────────────────────────────────────────

# read_mcp <file> — prints mcpServers JSON object or bare "null"
read_mcp() {
  local file="$1"
  local out
  [[ ! -f "$file" ]] && printf 'null' && return
  if out=$(jq -e '.mcpServers // empty' "$file" 2>/dev/null) && [[ -n "$out" ]]; then
    printf '%s' "$out"
  else
    warn "Could not parse mcpServers from $file — skipped"
    printf 'null'
  fi
}

# detect_in_mcp <mcp_json> <name_patterns_csv> <args_patterns_csv>
# Prints JSON: {"matched":bool,"matched_via":"name"|"args"|null,"server_name":"..."|null}
# Name and args patterns are comma-separated lowercase substrings.
detect_in_mcp() {
  local mcp="$1" np="$2" ap="$3"
  if [[ "$mcp" == "null" ]]; then
    printf '{"matched":false,"matched_via":null,"server_name":null}'
    return
  fi

  local np_arr ap_arr
  np_arr=$(printf '%s' "$np" | jq -Rc 'split(",")')
  ap_arr=$(printf '%s' "$ap" | jq -Rc 'split(",")')

  printf '%s' "$mcp" | jq \
    --argjson np "$np_arr" \
    --argjson ap "$ap_arr" \
    '[to_entries[] |
      .key as $n |
      ((.value.command // "") + " " +
        (if .value.args then (.value.args | join(" ")) else "" end) | ascii_downcase) as $cmd |
      ($n | ascii_downcase) as $ln |
      if   any($np[]; . as $p | $p != "" and ($ln  | contains($p)))
      then {"matched":true,"matched_via":"name","server_name":$n}
      elif any($ap[]; . as $p | $p != "" and ($cmd | contains($p)))
      then {"matched":true,"matched_via":"args","server_name":$n}
      else empty
      end
    ] | if length > 0 then .[0] else {"matched":false,"matched_via":null,"server_name":null} end'
}

# ─── Read MCP configs ─────────────────────────────────────────────────────────

PROJ_MCP=$(read_mcp "$PROJECT_PATH/.mcp.json")
USER_MCP1=$(read_mcp "$HOME/.claude/mcp_servers.json")
USER_MCP2=$(read_mcp "$HOME/.claude.json")

# Merge both user-level sources into one object (project-level kept separate)
USER_MCP=$(jq -n \
  --argjson a "$USER_MCP1" --argjson b "$USER_MCP2" \
  '(if $a == null then {} else $a end) + (if $b == null then {} else $b end)')

# ─── MCP keyword tables ───────────────────────────────────────────────────────

JIRA_N="atlassian,jira,confluence"
JIRA_A="@atlassian/"
TR_N="bosch-jira-mcp,bosch-jira"
TR_A="bosch-jira-mcp"
ADO_N="azure-devops,ado"
ADO_A="azure-devops-mcp,@microsoft/azure"
GH_N="github"
GH_A="github-mcp-server,@modelcontextprotocol/server-github"

# ─── Detect per source ────────────────────────────────────────────────────────

PROJ_JIRA=$(detect_in_mcp "$PROJ_MCP" "$JIRA_N" "$JIRA_A")
PROJ_TR=$(detect_in_mcp "$PROJ_MCP" "$TR_N" "$TR_A")
PROJ_ADO=$(detect_in_mcp "$PROJ_MCP" "$ADO_N" "$ADO_A")
PROJ_GH=$(detect_in_mcp "$PROJ_MCP" "$GH_N" "$GH_A")

USER_JIRA=$(detect_in_mcp "$USER_MCP" "$JIRA_N" "$JIRA_A")
USER_TR=$(detect_in_mcp "$USER_MCP" "$TR_N" "$TR_A")
USER_ADO=$(detect_in_mcp "$USER_MCP" "$ADO_N" "$ADO_A")
USER_GH=$(detect_in_mcp "$USER_MCP" "$GH_N" "$GH_A")

pm() { printf '%s' "$1" | jq -r '.matched'; }
pv() { printf '%s' "$1" | jq -r '.matched_via // "null"'; }

PROJ_JIRA_M=$(pm "$PROJ_JIRA"); PROJ_TR_M=$(pm "$PROJ_TR")
PROJ_ADO_M=$(pm "$PROJ_ADO");   PROJ_GH_M=$(pm "$PROJ_GH")
USER_JIRA_M=$(pm "$USER_JIRA"); USER_TR_M=$(pm "$USER_TR")
USER_ADO_M=$(pm "$USER_ADO");   USER_GH_M=$(pm "$USER_GH")

# ─── Precedence resolution ────────────────────────────────────────────────────
# Globals set by resolve_dim: DIM_A, DIM_B, DIM_A_SRC, DIM_B_SRC
# Globals updated: AMBIGUITIES, SUPPRESSED, MCP_SOURCES

AMBIGUITIES='[]'
SUPPRESSED='[]'
MCP_SOURCES='{}'
DIM_A=false; DIM_B=false; DIM_A_SRC='null'; DIM_B_SRC='null'

# resolve_dim <dim> <pam> <pbm> <uam> <ubm> <pa> <pb> <ua> <ub> <key_a> <key_b>
#   dim:   "tracker" or "repo"
#   *m:    "true"/"false" — matched flag
#   pa/pb: full detect_in_mcp JSON for project-level A and B
#   ua/ub: full detect_in_mcp JSON for user-level A and B
#   key_*: flag name string (e.g. "tracker_jira")
resolve_dim() {
  local dim="$1" pam="$2" pbm="$3" uam="$4" ubm="$5"
  local pa="$6" pb="$7" ua="$8" ub="$9" ka="${10}" kb="${11}"
  local pfile="$PROJECT_PATH/.mcp.json"

  DIM_A=false; DIM_B=false; DIM_A_SRC='null'; DIM_B_SRC='null'

  if [[ "$pam" == "true" && "$pbm" == "true" ]]; then
    # Both backends detected at project level → ambiguity
    AMBIGUITIES=$(printf '%s' "$AMBIGUITIES" | jq \
      --arg d "$dim" --arg p "$pfile" \
      '. + [{"dimension":$d,"sources":[$p,$p]}]')
    DIM_A=true; DIM_B=true
    DIM_A_SRC=$(jq -n --arg p "$pfile" --arg v "$(pv "$pa")" '{"source":"project","config_path":$p,"matched_via":$v}')
    DIM_B_SRC=$(jq -n --arg p "$pfile" --arg v "$(pv "$pb")" '{"source":"project","config_path":$p,"matched_via":$v}')

  elif [[ "$pam" == "true" ]]; then
    # A wins at project level; suppress any user-level B
    DIM_A=true
    DIM_A_SRC=$(jq -n --arg p "$pfile" --arg v "$(pv "$pa")" '{"source":"project","config_path":$p,"matched_via":$v}')
    [[ "$ubm" == "true" ]] && SUPPRESSED=$(printf '%s' "$SUPPRESSED" | jq \
      --arg d "$dim" --arg k "$kb" --arg by "$ka" \
      '. + [{"dimension":$d,"backend":$k,"suppressed_by":("project-level "+$by)}]')

  elif [[ "$pbm" == "true" ]]; then
    # B wins at project level; suppress any user-level A
    DIM_B=true
    DIM_B_SRC=$(jq -n --arg p "$pfile" --arg v "$(pv "$pb")" '{"source":"project","config_path":$p,"matched_via":$v}')
    [[ "$uam" == "true" ]] && SUPPRESSED=$(printf '%s' "$SUPPRESSED" | jq \
      --arg d "$dim" --arg k "$ka" --arg by "$kb" \
      '. + [{"dimension":$d,"backend":$k,"suppressed_by":("project-level "+$by)}]')

  elif [[ "$uam" == "true" && "$ubm" == "true" ]]; then
    # Both at user level → ambiguity
    AMBIGUITIES=$(printf '%s' "$AMBIGUITIES" | jq \
      --arg d "$dim" \
      '. + [{"dimension":$d,"sources":["user-level","user-level"]}]')
    DIM_A=true; DIM_B=true
    DIM_A_SRC='{"source":"user"}'; DIM_B_SRC='{"source":"user"}'

  elif [[ "$uam" == "true" ]]; then
    DIM_A=true
    DIM_A_SRC=$(jq -n --arg v "$(pv "$ua")" '{"source":"user","matched_via":$v}')

  elif [[ "$ubm" == "true" ]]; then
    DIM_B=true
    DIM_B_SRC=$(jq -n --arg v "$(pv "$ub")" '{"source":"user","matched_via":$v}')
  fi

  # Warn on indirect (args-only) matches
  if [[ "$DIM_A" == "true" ]]; then
    if [[ "$(pv "$pa")" == "args" ]] || [[ "$pam" == "false" && "$(pv "$ua")" == "args" ]]; then
      warn "Indirect match (args-only) for $ka — verify this is the intended MCP backend"
    fi
  fi
  if [[ "$DIM_B" == "true" ]]; then
    if [[ "$(pv "$pb")" == "args" ]] || [[ "$pbm" == "false" && "$(pv "$ub")" == "args" ]]; then
      warn "Indirect match (args-only) for $kb — verify this is the intended MCP backend"
    fi
  fi

  # Populate sources map for detected backends
  [[ "$DIM_A" == "true" ]] && MCP_SOURCES=$(printf '%s' "$MCP_SOURCES" | jq \
    --arg k "$ka" --argjson s "$DIM_A_SRC" '.[$k] = $s')
  [[ "$DIM_B" == "true" ]] && MCP_SOURCES=$(printf '%s' "$MCP_SOURCES" | jq \
    --arg k "$kb" --argjson s "$DIM_B_SRC" '.[$k] = $s')
}

# Resolve tracker dimension (Jira = A, T&R = B)
resolve_dim "tracker" \
  "$PROJ_JIRA_M" "$PROJ_TR_M" "$USER_JIRA_M" "$USER_TR_M" \
  "$PROJ_JIRA" "$PROJ_TR" "$USER_JIRA" "$USER_TR" \
  "tracker_jira" "tracker_tr"
TRACKER_JIRA=$DIM_A; TRACKER_TR=$DIM_B

# Resolve repo dimension (ADO = A, GitHub = B)
resolve_dim "repo" \
  "$PROJ_ADO_M" "$PROJ_GH_M" "$USER_ADO_M" "$USER_GH_M" \
  "$PROJ_ADO" "$PROJ_GH" "$USER_ADO" "$USER_GH" \
  "repo_ado" "repo_github"
REPO_ADO=$DIM_A; REPO_GITHUB=$DIM_B

# ─── Git remote parsing ───────────────────────────────────────────────────────

GIT_PROVIDER="null"  # JSON null literal
GIT_ADO="null"
GIT_GH="null"

if command -v git >/dev/null 2>&1 && git -C "$PROJECT_PATH" rev-parse --git-dir >/dev/null 2>&1; then
  RURL=$(git -C "$PROJECT_PATH" remote get-url origin 2>/dev/null || \
         git -C "$PROJECT_PATH" remote -v 2>/dev/null | awk '/\(fetch\)/{print $2; exit}' || true)

  if [[ -n "${RURL:-}" ]]; then
    # Azure DevOps modern: https://dev.azure.com/{org}/{project}/_git/{repo}
    if [[ "$RURL" =~ ^https://dev\.azure\.com/([^/?]+)/([^/?]+)/_git/([^/?]+) ]]; then
      GIT_PROVIDER='"azure-devops"'
      GIT_ADO=$(jq -n \
        --arg o "${BASH_REMATCH[1]}" --arg p "${BASH_REMATCH[2]}" --arg r "${BASH_REMATCH[3]%.git}" \
        '{"org":$o,"project":$p,"repo":$r}')

    # Azure DevOps legacy: https://{org}.visualstudio.com/{project}/_git/{repo}
    elif [[ "$RURL" =~ ^https://([^./?]+)\.visualstudio\.com/([^/?]+)/_git/([^/?]+) ]]; then
      GIT_PROVIDER='"azure-devops"'
      GIT_ADO=$(jq -n \
        --arg o "${BASH_REMATCH[1]}" --arg p "${BASH_REMATCH[2]}" --arg r "${BASH_REMATCH[3]%.git}" \
        '{"org":$o,"project":$p,"repo":$r}')

    # GitHub SSH: git@github.com:{owner}/{repo}[.git]
    elif [[ "$RURL" =~ ^git@github\.com:([^/]+)/(.+)$ ]]; then
      GIT_PROVIDER='"github"'
      GIT_GH=$(jq -n \
        --arg o "${BASH_REMATCH[1]}" --arg r "${BASH_REMATCH[2]%.git}" \
        '{"owner":$o,"repo":$r}')

    # GitHub HTTPS: https://github.com/{owner}/{repo}[.git]
    elif [[ "$RURL" =~ ^https://github\.com/([^/?]+)/([^/?]+) ]]; then
      GIT_PROVIDER='"github"'
      GIT_GH=$(jq -n \
        --arg o "${BASH_REMATCH[1]}" --arg r "${BASH_REMATCH[2]%.git}" \
        '{"owner":$o,"repo":$r}')
    fi
  fi
fi

# ─── Sibling scan ─────────────────────────────────────────────────────────────

SIBLINGS='[]'
PARENT="$(dirname "$PROJECT_PATH")"

# Fields that can be inherited from a sibling config
INHERITABLE=(
  jira.cloudId jira.projectKey jira.urlBase
  jira.customFields.sprint jira.customFields.acceptanceCriteria
  azureDevOps.org azureDevOps.project
  tr.baseUrl tr.projectKey
  github.owner github.repo
)

# Documented defaults — inheritance for these is a no-op because Phase 2c
# would write the same value anyway. Keep in sync with
# references/tracker-config-prompts.md and references/repo-config-prompts.md.
# Uses a case statement (not `declare -A`) to stay compatible with bash 3.2
# on stock macOS, where associative arrays are unavailable.
default_value() {
  case "$1" in
    jira.customFields.sprint)              echo "customfield_10001" ;;
    jira.customFields.acceptanceCriteria)  echo "customfield_12206" ;;
    github.linkingKeyword)                 echo "Closes" ;;
    *)                                     echo "" ;;
  esac
}

if [[ "$PARENT" != "$PROJECT_PATH" && -d "$PARENT" ]]; then
  for sib in "$PARENT"/*/; do
    [[ -d "$sib" ]] || continue
    sib_abs="$(cd "$sib" 2>/dev/null && pwd)" || continue
    [[ "$sib_abs" == "$PROJECT_PATH" ]] && continue
    cfg="${sib}.claude/skills/feature-workflow/config.json"
    [[ -f "$cfg" ]] || continue

    cfg_json=$(jq '.' "$cfg" 2>/dev/null) || {
      warn "Malformed JSON in $cfg — skipped"
      continue
    }

    summary='{}'
    for f in "${INHERITABLE[@]}"; do
      v=$(printf '%s' "$cfg_json" | jq -r ".$f // empty" 2>/dev/null) || continue
      [[ -z "$v" ]] && continue
      # Drop stub values left by a prior orchestrator run — inheriting them
      # would propagate the placeholder, not a real value.
      [[ "$v" =~ ^\[TODO:\ .*\]$ ]] && continue
      # Drop values that exactly match the documented default — Phase 2c
      # would write the same value, so the offer would be a no-op.
      dv=$(default_value "$f")
      [[ -n "$dv" && "$v" == "$dv" ]] && continue
      summary=$(printf '%s' "$summary" | jq --arg k "$f" --arg v "$v" '.[$k] = $v')
    done

    # Drop siblings that contributed nothing after filtering — the offer
    # would be vacuous (y and n produce identical resolved configs).
    [[ "$summary" == "{}" ]] && continue

    SIBLINGS=$(printf '%s' "$SIBLINGS" | jq \
      --arg p "../$(basename "$sib")" --argjson s "$summary" \
      '. + [{"path":$p,"config_summary":$s}]')
  done
fi

# ─── Unresolved fields ────────────────────────────────────────────────────────
# Fields that detection could not satisfy → will require user prompting in Phase 2c.

SIB0=$(printf '%s' "$SIBLINGS" | jq 'if length > 0 then .[0].config_summary else {} end')
sib_has() { [[ "$(printf '%s' "$SIB0" | jq --arg k "$1" 'has($k)')" == "true" ]]; }

UNRESOLVED_T='[]'
UNRESOLVED_R='[]'

if [[ "$TRACKER_JIRA" == "true" ]]; then
  for f in jira.cloudId jira.projectKey jira.urlBase; do
    sib_has "$f" || UNRESOLVED_T=$(printf '%s' "$UNRESOLVED_T" | jq --arg f "$f" '. + [$f]')
  done
fi

if [[ "$TRACKER_TR" == "true" ]]; then
  for f in tr.baseUrl tr.projectKey; do
    sib_has "$f" || UNRESOLVED_T=$(printf '%s' "$UNRESOLVED_T" | jq --arg f "$f" '. + [$f]')
  done
fi

if [[ "$REPO_ADO" == "true" ]]; then
  # repositoryId is always unresolved — UUID cannot be auto-detected
  UNRESOLVED_R=$(printf '%s' "$UNRESOLVED_R" | jq '. + ["azureDevOps.repositoryId"]')
  if [[ "$GIT_ADO" == "null" ]]; then
    for f in azureDevOps.org azureDevOps.project; do
      sib_has "$f" || UNRESOLVED_R=$(printf '%s' "$UNRESOLVED_R" | jq --arg f "$f" '. + [$f]')
    done
  fi
fi

if [[ "$REPO_GITHUB" == "true" && "$GIT_GH" == "null" ]]; then
  for f in github.owner github.repo; do
    sib_has "$f" || UNRESOLVED_R=$(printf '%s' "$UNRESOLVED_R" | jq --arg f "$f" '. + [$f]')
  done
fi

# ─── Build warnings array ─────────────────────────────────────────────────────

WARNINGS='[]'
while IFS= read -r -d '' w; do
  WARNINGS=$(printf '%s' "$WARNINGS" | jq --arg w "$w" '. + [$w]')
done < "$WARN_TMP"

# ─── Emit output ──────────────────────────────────────────────────────────────

jq -n \
  --arg     sv    "$SCHEMA_VERSION" \
  --argjson tj    "$TRACKER_JIRA" \
  --argjson ttr   "$TRACKER_TR" \
  --argjson ra    "$REPO_ADO" \
  --argjson rg    "$REPO_GITHUB" \
  --argjson src   "$MCP_SOURCES" \
  --argjson amb   "$AMBIGUITIES" \
  --argjson sup   "$SUPPRESSED" \
  --argjson gp    "$GIT_PROVIDER" \
  --argjson gado  "$GIT_ADO" \
  --argjson ggh   "$GIT_GH" \
  --argjson sibs  "$SIBLINGS" \
  --argjson ut    "$UNRESOLVED_T" \
  --argjson ur    "$UNRESOLVED_R" \
  --argjson warns "$WARNINGS" \
  '{
    schema_version: $sv,
    mcp: {
      tracker_jira: $tj,
      tracker_tr:   $ttr,
      repo_ado:     $ra,
      repo_github:  $rg,
      sources:      $src,
      ambiguities:  $amb,
      suppressed:   $sup
    },
    git_remote: { provider: $gp, azure_devops: $gado, github: $ggh },
    siblings:   $sibs,
    unresolved: { tracker: $ut, repo: $ur },
    warnings:   $warns
  }'
