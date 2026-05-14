---
name: claudboard-workspace-link
model: claude-sonnet-4-6
description: >
  Link a teammate's machine to an existing workspace meta-repo. Clones the
  meta-repo as a sibling of the workspace root and runs setup.sh to create
  the symlink. One-command teammate bootstrap after the first developer has
  run /claudboard-workspace-init.
  Use when: /claudboard-workspace-link, "join workspace", "link to workspace
  meta-repo", "bootstrap workspace on this machine", "set up workspace .claude
  from remote", "clone workspace meta-repo", "connect to shared .claude".
---

# claudboard-workspace-link — Teammate Workspace Bootstrap

Links this machine to a team's shared workspace meta-repo. Run from the
workspace root (the parent directory of your service repos) after a colleague
has already run `/claudboard-workspace-init`.

Takes one argument: the git remote URL of the meta-repo.

---

## Phase 1: Prerequisite Checks

### 1a. Workspace-root check

Verify the current working directory is a valid workspace root (same check as
`/claudboard-workspace-init`):

1. No `.git/` at CWD.
2. At least one subdirectory with both a build file AND its own `.git/`.

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

If `.git/` exists at CWD, stop with:

> This directory is itself a git repository. Run from the parent of your
> service repos (the workspace root).

If no qualifying subdirectory found, stop with:

> No workspace repos detected in [CWD]. Navigate to your workspace root and
> try again.

### 1b. Idempotency check

```bash
test -L .claude && readlink .claude
```

If `.claude` is already a symlink to an existing directory:

```bash
EXISTING_REMOTE=$(git -C "$(dirname "$(readlink .claude)")" remote get-url origin 2>/dev/null || echo "none")
```

If the existing symlink target's remote matches the requested URL → skip clone,
run `setup.sh` from the existing meta-repo, and report "Already linked — ran
setup.sh to verify."

If the remote differs → stop with:

> .claude/ already links to a meta-repo with a different remote:
>   current: [existing remote]
>   requested: [url]
> To switch, remove the existing symlink and meta-repo manually, then re-run.

### 1c. Remote URL

If the user provided a URL as an argument, use it.

If no URL was provided, prompt:

```
Meta-repo remote URL:
```

Do not proceed without a URL.

---

## Phase 2: Infer Local Directory Name

Infer the local directory name from the remote URL:

```bash
basename "[url]" .git
```

Example: `git@github.com:org/meas.workspace.git` → `meas.workspace`
Example: `https://dev.azure.com/org/proj/_git/meas.workspace` → `meas.workspace`

Offer the inferred name with override:

```
Local directory name [meas.workspace]:
```

**Collision detection:**

```bash
TARGET_PATH="../[name]"
```

If `${TARGET_PATH}` already exists:

1. Check if it's already the expected meta-repo:
   ```bash
   git -C "${TARGET_PATH}" remote get-url origin 2>/dev/null
   ```
   If the remote matches the requested URL → skip clone (repo already present),
   proceed directly to Phase 4 (run setup.sh).

2. If the path exists but remote does not match (or is not a git repo):
   > Local path '[parent]/[name]' exists but is not the expected meta-repo.
   > Choose another name or resolve the conflict manually.
   Re-prompt for the name.

---

## Phase 3: Clone Meta-Repo

```bash
git clone "[url]" "${TARGET_PATH}"
```

If clone fails (auth error, network, repo not found), stop with the git error
message and hint:

> Clone failed. Check the URL, your SSH/token credentials, and network access.
> URL: [url]

---

## Phase 4: Run setup.sh

```bash
bash "${TARGET_PATH}/setup.sh"
```

Capture the output and report it to the user.

If `setup.sh` exits with a non-zero status, stop with:

> setup.sh failed. See output above. You may need to:
>   - Check that the workspace root has no .git/ directory
>   - Remove a stale .claude symlink with: rm [cwd]/.claude
>   - Re-run: bash [meta-repo-path]/setup.sh

---

## Phase 5: Completion Report

```
## claudboard-workspace-link — Done

### Meta-repo
  Cloned to: [parent]/[name]/
  Remote:    [url]

### Workspace symlink
  [cwd]/.claude → [resolved link target]

### Next steps
  Pull the latest artifacts before starting work:
    git -C [parent]/[name]/ pull

  Start a feature from the workspace root:
    /start-feature [description]
```

---

## Error Handling

| Condition | Behavior |
|-----------|----------|
| `.git/` at CWD | Stop with workspace-root message |
| No qualifying subdirs | Stop with workspace-root message |
| No remote URL provided | Prompt before proceeding |
| Already linked to same remote | Re-run setup.sh, report "already linked" |
| Already linked to different remote | Stop with conflict message |
| Path collision with non-matching repo | Re-prompt for name |
| Clone fails | Stop with git error + credential hint |
| setup.sh fails | Stop with setup.sh output + recovery steps |

## Constraints

- **Never write outside** the cloned meta-repo and `[cwd]/.claude` symlink.
- **Never delete existing service repos or their `.claude/` directories.**
- **Idempotent:** safe to re-run; detects existing correct state and no-ops.
