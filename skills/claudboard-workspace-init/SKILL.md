---
name: claudboard-workspace-init
model: claude-sonnet-4-6
description: >
  Bootstrap a workspace meta-repo that holds the shared `.claude/` directory for
  a multi-repo workspace (a parent directory containing N independent git repos).
  Creates a sibling git repository, migrates any existing workspace `.claude/`
  contents into it, and symlinks the workspace root's `.claude/` to the meta-repo.
  Run once per workspace — teammates use `/claudboard-workspace-link` afterwards.
  Use when: /claudboard-workspace-init, "bootstrap workspace", "set up workspace
  meta-repo", "create workspace .claude repo", "initialise workspace .claude",
  "share my .claude across the team", "make .claude versioned for this workspace".
---

# claudboard-workspace-init — Workspace Meta-Repo Bootstrap

Creates a shared, version-controlled `.claude/` for a multi-repo workspace.
Run this once from the workspace root (the parent directory of your service repos).
Teammates then run `/claudboard-workspace-link <remote-url>` to link in.

---

## Phase 1: Prerequisite Checks

Run all checks before prompting for anything. Fail fast.

### 1a. Workspace-root check

Verify the current working directory is a valid workspace root.

A workspace root satisfies ALL of the following:
1. Has **no** `.git/` directory at CWD.
2. Has **at least one** subdirectory containing both a build file (`build.gradle`,
   `pom.xml`, `package.json`, `Cargo.toml`, `go.mod`, `setup.py`, `pyproject.toml`)
   AND an independent `.git/` directory.

Run:

```bash
test -d .git && echo "has_git" || echo "no_git"
```

```bash
for d in */; do
  if [ -d "${d}.git" ] && ls "$d"{build.gradle,pom.xml,package.json,Cargo.toml,go.mod,setup.py,pyproject.toml} 2>/dev/null | head -1 | grep -q .; then
    echo "found: $d"; break
  fi
done
```

**If `.git/` exists at CWD**, stop with:

> This directory is itself a git repository. Workspace bootstrap is for non-git
> parent directories holding multiple repos. Navigate to the parent of your
> service repos and try again.

**If no qualifying subdirectory found**, stop with:

> No workspace repos detected in [CWD]. A workspace root must contain at least
> one subdirectory with its own `.git/` and a build file. Check your path and
> try again.

### 1b. Idempotency check

Check whether the workspace is already bootstrapped:

```bash
test -L .claude && readlink .claude
```

If `.claude` is a symlink AND its target is an existing directory, stop with:

> Workspace already bootstrapped — meta-repo at [resolved target parent].
> Remote: [git remote get-url origin from that path, or "none configured"].
> No action taken.

---

## Phase 2: Plan and Confirm

Before any destructive action, print a complete plan and wait for explicit user approval.

### 2a. Determine meta-repo name

Default name: `<workspace-basename>.workspace`

```bash
basename "$(pwd)"
```

Example: if CWD is `/Users/x/meas`, default is `meas.workspace`.

Offer the default and allow override:

```
Meta-repo name [meas.workspace]:
```

**Collision guards:**
- If a directory with that name already exists as a sibling of CWD → refuse:
  > Target path '[parent]/[name]' already exists. Choose another name.
- If the chosen name matches the basename of any existing service subdirectory
  of the workspace → refuse:
  > Name '[name]' collides with workspace subdir '[cwd]/[name]'. Choose another name.

### 2b. Remote URL (optional)

```
Git remote URL (press Enter to skip — add later):
```

Accept any non-empty string as a remote URL. Empty → no remote configured.

### 2c. Inventory existing `.claude/` contents

```bash
ls -la .claude/ 2>/dev/null || echo "empty"
```

If `.claude/` exists and has contents, list what will be migrated:
- `rules/` → will move to meta-repo
- `reports/` → will move to meta-repo
- `config.json` → will move to meta-repo
- `settings.local.json` → will NOT move (stays per-developer)
- Any other files/dirs → listed as "left in backup for manual handling"

### 2d. Print plan and wait for confirmation

```
## claudboard-workspace-init — Ready to Bootstrap

Meta-repo name:   meas.workspace
Meta-repo path:   [parent]/../meas.workspace/
Workspace .claude: [cwd]/.claude → ../meas.workspace/.claude
Remote:           [url or "none — add later"]

Files to migrate from existing .claude/:
  ✓ rules/          → meta-repo
  ✓ reports/        → meta-repo
  ✓ config.json     → meta-repo
  ✗ settings.local.json  (stays per-developer)
  ✗ changes/        (not standard claudboard output — left in backup)

Backup will be written to: [cwd]/.claude.backup.[timestamp]/

Proceed? [y/n]
```

If `n` → exit without changes.

Allow the user to adjust the name or remote URL and re-print the plan:

```
Edit [name/remote/cancel]:
```

---

## Phase 3: Backup Existing `.claude/`

Before touching anything, back up any existing `.claude/` to preserve it.

```bash
TIMESTAMP=$(date -u +%Y%m%dT%H%M%SZ)
BACKUP_DIR=".claude.backup.${TIMESTAMP}"
```

If `.claude/` exists and is a regular directory (not a symlink):

```bash
cp -R .claude/ "${BACKUP_DIR}/"
```

If `.claude/` is a symlink → note it but do not back up (the target is the
meta-repo; idempotency check should have caught this).

If `.claude/` does not exist → skip backup (nothing to preserve).

Report: "Backup created at [cwd]/.claude.backup.[timestamp]/"

---

## Phase 4: Create Meta-Repo

Create the meta-repo as a sibling of the workspace root.

```bash
META_REPO_NAME="[chosen name]"
META_REPO_PATH="../${META_REPO_NAME}"
```

### 4a. Git init

```bash
mkdir -p "${META_REPO_PATH}"
git -C "${META_REPO_PATH}" init
```

### 4b. Scaffold directory structure

```bash
mkdir -p "${META_REPO_PATH}/.claude/rules"
mkdir -p "${META_REPO_PATH}/.claude/reports"
mkdir -p "${META_REPO_PATH}/.claude/skills"
mkdir -p "${META_REPO_PATH}/.claude/changes"
```

### 4c. Write `.gitignore`

Write `${META_REPO_PATH}/.gitignore`:

```
# Per-developer Claude state — never commit
.claude/settings.local.json
.claude/.copy-mode

# macOS
.DS_Store

# Editor artifacts
*.swp
*.swo
*~

# claudboard ephemeral state
.claude/reports/.claudboard-lock
```

### 4d. Write `README.md`

Write `${META_REPO_PATH}/README.md`:

```markdown
# [workspace-basename] — Workspace `.claude/`

Shared Claude Code context for the **[workspace-basename]** multi-repo workspace.

This repo holds:
- `.claude/rules/` — cross-cutting coding rules shared across all services
- `.claude/reports/` — claudboard analysis reports (per-service)
- `.claude/skills/feature-workflow/` — workspace-level feature workflow skill
- `.claude/changes/` — per-feature specs and plans

## First-time setup (teammates)

Clone this repo as a **sibling** of your service repos, then run the bootstrap:

```bash
# From the workspace root (parent of your service repos):
/claudboard-workspace-link [remote-url]
# or manually:
git clone [remote-url] ../[meta-repo-name]
cd ../[meta-repo-name] && ./setup.sh
```

## What NOT to commit

- `.claude/settings.local.json` — per-developer Claude settings (gitignored)
- Any personal notes or scratch files

## Updating shared rules or reports

```bash
# Pull latest from team:
git -C ../[meta-repo-name] pull

# After claudboard refresh generates new reports/rules:
cd ../[meta-repo-name]
git add .claude/rules/ .claude/reports/
git commit -m "chore: refresh claudboard artifacts"
git push
```
```

### 4e. Write `setup.sh`

Write `${META_REPO_PATH}/setup.sh`:

```bash
#!/usr/bin/env bash
# setup.sh — idempotent workspace symlink bootstrap
# Run from the meta-repo root after cloning.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(dirname "$SCRIPT_DIR")"
CLAUDE_TARGET="${SCRIPT_DIR}/.claude"
CLAUDE_LINK="${WORKSPACE_ROOT}/.claude"

# Refuse if workspace root is itself a git repo
if [ -d "${WORKSPACE_ROOT}/.git" ]; then
  echo "ERROR: ${WORKSPACE_ROOT} is a git repository. Workspace symlink must"
  echo "       point at a parent directory of your service repos, not a repo itself."
  exit 1
fi

# Compute relative path for symlink (portable across clone locations)
REL_TARGET="$(python3 -c "import os; print(os.path.relpath('${CLAUDE_TARGET}', '${WORKSPACE_ROOT}'))" 2>/dev/null \
  || python -c "import os; print(os.path.relpath('${CLAUDE_TARGET}', '${WORKSPACE_ROOT}'))")"

# Check if already correctly linked
if [ -L "${CLAUDE_LINK}" ]; then
  CURRENT_TARGET="$(readlink "${CLAUDE_LINK}")"
  # Resolve both relative to workspace root for comparison
  RESOLVED_CURRENT="$(cd "${WORKSPACE_ROOT}" && cd "$(dirname "${CURRENT_TARGET}")" && pwd)/$(basename "${CURRENT_TARGET}")"
  if [ "${RESOLVED_CURRENT}" = "${CLAUDE_TARGET}" ]; then
    echo "Already linked — ${CLAUDE_LINK} → ${CURRENT_TARGET}"
    exit 0
  fi
fi

# Attempt symlink
if ln -sfn "${REL_TARGET}" "${CLAUDE_LINK}" 2>/dev/null; then
  echo "Linked: ${CLAUDE_LINK} → ${REL_TARGET}"
else
  # Symlink failed — fall back to copy mode
  echo "Symlinks unavailable — bootstrapping in copy mode."
  mkdir -p "${CLAUDE_LINK}"
  cp -R "${CLAUDE_TARGET}/." "${CLAUDE_LINK}/"
  touch "${CLAUDE_LINK}/.copy-mode"
  cat > "${CLAUDE_LINK}/.copy-mode" << 'MARKER'
This workspace .claude/ is a copy of the meta-repo (symlinks unavailable).
After `git pull` in the meta-repo, re-sync with:
  cd [meta-repo-path] && ./setup.sh
MARKER
  echo "Copy-mode bootstrap complete. Re-run setup.sh after git pull to sync."
fi
```

Make it executable:

```bash
chmod +x "${META_REPO_PATH}/setup.sh"
```

---

## Phase 5: Migrate Existing `.claude/` Contents

Move standard claudboard artifacts from the backup into the meta-repo.

For each of the following (if they exist in the backup):

| Source (backup) | Destination (meta-repo) |
|----------------|------------------------|
| `rules/` | `.claude/rules/` |
| `reports/` | `.claude/reports/` |
| `config.json` | `.claude/config.json` |

```bash
for ITEM in rules reports config.json; do
  SRC="${BACKUP_DIR}/${ITEM}"
  DST="${META_REPO_PATH}/.claude/${ITEM}"
  if [ -e "$SRC" ]; then
    cp -R "$SRC" "$DST"
    echo "  Migrated: ${ITEM}"
  fi
done
```

Do **NOT** move: `settings.local.json`, `skills/feature-workflow/` (per-repo,
user removes manually), or any unrecognised files.

Record the list of unmigrated files for the completion report.

---

## Phase 6: Create Symlink

Remove the existing `.claude/` from the workspace root (if present, now backed up)
and create the symlink.

```bash
WORKSPACE_CLAUDE="[cwd]/.claude"

# Remove the original (now backed up) .claude/ directory
[ -d "$WORKSPACE_CLAUDE" ] && rm -rf "$WORKSPACE_CLAUDE"

# Create relative symlink
META_ABS="$(cd "${META_REPO_PATH}/.claude" && pwd)"
REL="$(python3 -c "import os; print(os.path.relpath('${META_ABS}', '[cwd]'))" 2>/dev/null \
  || python -c "import os; print(os.path.relpath('${META_ABS}', '[cwd]'))")"

if ln -sfn "$REL" "$WORKSPACE_CLAUDE"; then
  echo "Symlink created: [cwd]/.claude → ${REL}"
else
  # Windows fallback: copy mode
  echo "Symlinks unavailable — using copy mode."
  cp -R "${META_REPO_PATH}/.claude/." "$WORKSPACE_CLAUDE/"
  touch "${WORKSPACE_CLAUDE}/.copy-mode"
  printf "Copy-mode bootstrap.\nRe-run [meta-repo]/setup.sh after git pull.\n" \
    > "${WORKSPACE_CLAUDE}/.copy-mode"
fi
```

**Guard:** If `[cwd]/.claude` still exists as a non-symlink directory after
backup + removal, refuse with:

> Path conflict: [cwd]/.claude exists and could not be removed. Remove it
> manually and re-run.

---

## Phase 7: Initial Commit and Optional Push

Stage all tracked files and commit.

```bash
git -C "${META_REPO_PATH}" add .claude/ README.md setup.sh .gitignore
git -C "${META_REPO_PATH}" commit -m "chore: bootstrap workspace .claude/ via claudboard"
```

If a remote URL was provided:

```bash
git -C "${META_REPO_PATH}" remote add origin "[remote-url]"
git -C "${META_REPO_PATH}" push -u origin main 2>&1 || {
  echo "Push failed — meta-repo is initialised locally but push did not succeed."
  echo "To push later: git -C ${META_REPO_PATH} push -u origin main"
}
```

Push failure does **not** roll back the local meta-repo. Report the failure and
continue to the completion report.

---

## Phase 8: Completion Report

Print a full summary after all steps complete.

```
## claudboard-workspace-init — Done

### Meta-repo
  Path:    [parent]/[meta-repo-name]/
  Remote:  [url or "none — add later with: git -C [path] remote add origin <url>"]
  Commit:  [git log --oneline -1 output]

### Workspace symlink
  [cwd]/.claude → [relative path to meta-repo .claude]

### Migrated files
  ✓ rules/
  ✓ reports/
  ✓ config.json

### Backup
  [cwd]/.claude.backup.[timestamp]/

### Files left in backup (move manually if needed)
  • settings.local.json  — keep per-developer, do not commit
  [list any unrecognised files]

### Next steps
  1. Run `/claudboard-generate` or `/claudboard-workflow` — output will be
     written into the meta-repo through the symlink.
  2. Review the generated files in [meta-repo-name]/ and commit them:
       cd [meta-repo-path]
       git add .claude/
       git commit -m "chore: claudboard-generated artifacts"
       git push
  3. Share with your team:
       /claudboard-workspace-link [remote-url or "— add remote first"]
```

---

## Error Handling

| Condition | Behavior |
|-----------|----------|
| `.git/` at CWD | Stop with message from 1a |
| No qualifying subdirs | Stop with message from 1a |
| Already bootstrapped | Stop with idempotency message from 1b |
| Name collides with service subdir | Re-prompt during 2a |
| Target path already exists | Re-prompt during 2a |
| Symlink creation fails | Fall back to copy mode, mark `.copy-mode` |
| Push fails | Report, leave meta-repo intact, continue |
| Non-symlink `.claude` can't be removed | Refuse with path-conflict message |

## Constraints

- **Always confirm before any write.** The plan-and-confirm gate in Phase 2 is
  non-negotiable.
- **Never delete the backup.** Leave it in place; the user decides when to clean it.
- **Never auto-delete per-repo feature-workflow skills.** Those are in the service
  repos — not touched by this skill.
- **Relative symlinks only.** Use relative paths so the workspace remains portable
  across clone locations.
