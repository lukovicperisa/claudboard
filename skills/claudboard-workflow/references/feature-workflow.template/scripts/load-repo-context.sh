#!/usr/bin/env bash
# load-repo-context.sh — print per-repo .claude/ context for workspace mode.
# Usage: bash load-repo-context.sh <repo-name>
#
# Reads .claude/CLAUDE.md, .claude/rules/*.md, .claude/memory/MEMORY.md,
# and lists .claude/skills/*/SKILL.md for the named repo under the workspace
# root. Prints each file with a delimiter so the calling agent can parse them.
# Silently skips missing files.
set -euo pipefail

REPO_NAME="${1:?Usage: load-repo-context.sh <repo-name>}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
WORKSPACE_ROOT="$(dirname "$(dirname "$(dirname "$SKILL_DIR")")")"
REPO_ROOT="${WORKSPACE_ROOT}/${REPO_NAME}"

if [ ! -d "$REPO_ROOT" ]; then
  echo "ERROR: Repo directory not found: ${REPO_ROOT}" >&2
  exit 1
fi

CLAUDE_DIR="${REPO_ROOT}/.claude"

print_file() {
  local path="$1"
  if [ -f "$path" ]; then
    echo ""
    echo "=== ${path} ==="
    cat "$path"
  fi
}

# CLAUDE.md
print_file "${REPO_ROOT}/CLAUDE.md"

# Rules
if [ -d "${CLAUDE_DIR}/rules" ]; then
  for rule in "${CLAUDE_DIR}/rules"/*.md; do
    [ -f "$rule" ] && print_file "$rule"
  done
fi

# Memory index
print_file "${CLAUDE_DIR}/memory/MEMORY.md"

# Skill list (SKILL.md files only — not full content, just the index)
if [ -d "${CLAUDE_DIR}/skills" ]; then
  echo ""
  echo "=== ${CLAUDE_DIR}/skills/ (available skills) ==="
  for skill_dir in "${CLAUDE_DIR}/skills"/*/; do
    skill_md="${skill_dir}SKILL.md"
    if [ -f "$skill_md" ]; then
      skill_name="$(basename "$skill_dir")"
      # Skip feature-workflow — it lives at workspace root in workspace mode
      if [ "$skill_name" = "feature-workflow" ]; then
        continue
      fi
      echo ""
      echo "--- ${skill_name} ---"
      # Print only frontmatter + first 20 lines to keep output bounded
      head -40 "$skill_md"
    fi
  done
fi
