## ADDED Requirements

### Requirement: Skill invocation and trigger phrases for `/claudboard-workspace-init`
The system SHALL expose `claudboard-workspace-init` as a peer skill alongside other claudboard skills. The skill SHALL be triggered by the slash command `/claudboard-workspace-init` and by natural-language phrases including "bootstrap workspace", "set up workspace meta-repo", "create workspace .claude repo", and equivalents.

#### Scenario: Slash command invocation
- **WHEN** the user types `/claudboard-workspace-init` at a workspace root directory (no `.git/` at CWD, sibling subdirs each have `.git/`)
- **THEN** the system SHALL begin the bootstrap flow rooted at the current working directory

#### Scenario: Natural-language invocation
- **WHEN** the user says "bootstrap the workspace meta-repo for this MEAS workspace"
- **THEN** the system SHALL invoke `claudboard-workspace-init` and confirm the target workspace root before proceeding

#### Scenario: Auto-trigger from generation flow
- **WHEN** the user invokes `/claudboard-generate` or `/claudboard-workflow` in workspace mode AND no meta-repo symlink exists at `<workspace>/.claude`
- **THEN** the system SHALL stop the generation flow and prompt the user to run `/claudboard-workspace-init` first; the system SHALL NOT auto-initialise without explicit user invocation

### Requirement: Skill invocation for `/claudboard-workspace-link`
The system SHALL expose `claudboard-workspace-link` as a peer skill, triggered by the slash command `/claudboard-workspace-link <remote-url>` and by natural-language phrases including "link to workspace", "join workspace meta-repo", and equivalents.

#### Scenario: Slash command invocation with URL
- **WHEN** the user types `/claudboard-workspace-link git@github.com:org/meas.cloud.workspace.git` at a workspace root directory
- **THEN** the system SHALL begin the link flow targeting that remote

#### Scenario: Slash command without URL
- **WHEN** the user types `/claudboard-workspace-link` with no argument
- **THEN** the system SHALL prompt for the remote URL before proceeding

### Requirement: Workspace mode prerequisite
Both bootstrap commands SHALL refuse to run unless the current working directory is detected as a workspace root.

A workspace root is defined as: a directory with no build file at CWD, where at least one subdirectory has both a build file AND an independent `.git/` directory (consistent with the `workspace-detection` capability).

#### Scenario: CWD is not a workspace root
- **WHEN** the user invokes `/claudboard-workspace-init` from a directory that has its own `.git/` (single repo) or has no service subdirs
- **THEN** the system SHALL print "Workspace bootstrap requires a workspace root (parent directory of multiple service repos). Detected: <reason>." and stop

#### Scenario: CWD is itself a git repository
- **WHEN** the user invokes `/claudboard-workspace-init` from a directory that contains its own `.git/` directory at CWD
- **THEN** the system SHALL refuse with "This directory is itself a git repository. Workspace bootstrap is for non-git parent directories holding multiple repos." and stop

### Requirement: Plan-and-confirm gate for `init`
The `/claudboard-workspace-init` command SHALL print a complete plan of actions and pause for explicit user confirmation before performing any destructive or external action (git init, file moves, symlink creation, push to remote).

The plan SHALL include: the meta-repo name, the meta-repo target path (child of CWD — i.e., a directory created inside the workspace root), the optional remote URL, the contents being migrated from existing `<workspace>/.claude/` (if any), and the path of the backup that will be created.

#### Scenario: User confirms plan
- **WHEN** the user accepts the printed plan with `y` or equivalent
- **THEN** the system SHALL execute the plan in the documented order

#### Scenario: User declines plan
- **WHEN** the user rejects the plan with `n` or equivalent
- **THEN** the system SHALL exit without making any changes

#### Scenario: User adjusts plan parameters
- **WHEN** the user requests changes to the meta-repo name or remote URL during the confirmation gate
- **THEN** the system SHALL apply the change, re-print the updated plan, and re-prompt for confirmation

### Requirement: Meta-repo name and location
The meta-repo SHALL be created as a child directory inside the workspace root. The default name SHALL be `<workspace-basename>.workspace` (e.g., `meas.workspace` for a workspace at `/Users/x/meas/`, producing `/Users/x/meas/meas.workspace/`). The user SHALL be able to override the default in the confirmation gate.

#### Scenario: Default name accepted
- **WHEN** the user accepts the default name at the confirmation gate
- **THEN** the system SHALL create `<workspace>/<workspace-basename>.workspace/`

#### Scenario: Custom name provided
- **WHEN** the user provides an alternative name (e.g., `meas.cloud.workspace`)
- **THEN** the system SHALL create `<workspace>/<custom-name>/`

#### Scenario: Name collides with existing workspace subdir
- **WHEN** the chosen meta-repo name matches the basename of any existing subdirectory of the workspace (whether a service repo or any other directory)
- **THEN** the system SHALL refuse with "Name '<name>' collides with workspace subdir '<workspace>/<name>'. Choose another name." and re-prompt

#### Scenario: Target path already exists
- **WHEN** the chosen meta-repo path `<workspace>/<name>/` already exists on disk
- **THEN** the system SHALL refuse with "Target path '<workspace>/<name>' already exists. Remove it or choose another name." and re-prompt

#### Scenario: Stale sibling-layout bootstrap detected
- **WHEN** `<workspace>/.claude` is a symlink AND its target resolves to a path outside the workspace root (i.e., a pre-v3 sibling-layout bootstrap)
- **THEN** the system SHALL refuse with "Stale sibling-layout meta-repo detected at <resolved-path>. This version uses a child layout (meta-repo nested inside the workspace root). Remove the symlink and the old meta-repo manually, then re-run." and stop. The system SHALL NOT auto-migrate.

### Requirement: Backup of existing workspace `.claude/` before migration
If `<workspace>/.claude/` already exists with any contents, the system SHALL copy it to `<workspace>/.claude.backup.<UTC-timestamp>/` before migrating contents into the meta-repo.

The backup SHALL be created with `cp -R` semantics (preserve symlinks as symlinks, preserve permissions). The backup path SHALL be reported in the completion message.

#### Scenario: Existing `.claude/` with contents
- **WHEN** `<workspace>/.claude/` exists and contains `rules/`, `reports/`, `config.json`, or any other files
- **THEN** the system SHALL create `<workspace>/.claude.backup.<timestamp>/` containing a full copy of `<workspace>/.claude/` before any further action

#### Scenario: Existing `.claude/` is already a symlink to a meta-repo
- **WHEN** `<workspace>/.claude/` is already a symlink to a meta-repo's `.claude/` and that meta-repo is healthy (the symlink target exists and is a directory)
- **THEN** the system SHALL skip backup, recognise the workspace as already bootstrapped, and exit with "Workspace is already bootstrapped — meta-repo at <path>. No action taken."

#### Scenario: No existing `.claude/`
- **WHEN** `<workspace>/.claude/` does not exist
- **THEN** the system SHALL skip backup and proceed directly to meta-repo creation

### Requirement: Meta-repo initialisation
The system SHALL initialise the meta-repo as a fresh git repository, scaffold its tracked contents, perform an initial commit, and (if a remote was provided) push to that remote.

The scaffolded contents SHALL include:
- `.claude/` directory with subdirectories `rules/`, `reports/`, `skills/`, `changes/`
- `.claude/config.json` (if migrated from existing workspace `.claude/`, otherwise an empty stub the next workflow run populates)
- `.gitignore` containing at minimum: `settings.local.json`, `.DS_Store`, `*.swp`
- `README.md` with the canonical onboarding instructions (see "README contract" requirement)
- `setup.sh` with idempotent symlink semantics (see "setup.sh contract" requirement)

#### Scenario: Remote provided and reachable
- **WHEN** the user provides a remote URL during the confirmation gate AND the remote is reachable (push succeeds)
- **THEN** the system SHALL `git init`, scaffold contents, `git add` all tracked files, `git commit -m "chore: bootstrap workspace .claude/ via claudboard"`, `git remote add origin <url>`, and `git push -u origin main`

#### Scenario: Remote provided but push fails
- **WHEN** the user provides a remote URL AND push fails (auth error, repo not found, network error)
- **THEN** the system SHALL report the push failure to the user, leave the meta-repo intact with the remote configured, and instruct the user to push manually with `git -C <meta-repo> push -u origin main`. The system SHALL NOT roll back the local meta-repo.

#### Scenario: No remote provided
- **WHEN** the user skips the remote URL prompt
- **THEN** the system SHALL initialise the meta-repo, commit, but not configure any remote. The completion message SHALL include "No remote configured — add one later with `git -C <meta-repo> remote add origin <url> && git push -u origin main`."

### Requirement: Migration of existing workspace `.claude/` contents into the meta-repo
The system SHALL move existing workspace-level claudboard artifacts (rules, reports, config.json) from the backed-up `.claude/` into the new meta-repo's `.claude/` after backup is complete.

`settings.local.json` SHALL NOT be moved (it stays per-developer, gitignored). Any other untracked files (per-feature working files, draft notes) SHALL NOT be moved automatically; the system SHALL list any unmigrated files in the completion report so the user can move them manually.

#### Scenario: Standard claudboard files exist
- **WHEN** the backup contains `rules/`, `reports/`, and `config.json`
- **THEN** all three SHALL be moved into the meta-repo's `.claude/` and added to the initial commit

#### Scenario: settings.local.json is present
- **WHEN** the backup contains `settings.local.json`
- **THEN** the system SHALL leave the file in place at `<workspace>/.claude.backup.<timestamp>/settings.local.json`, not move it into the meta-repo, and note in the completion report that the user may copy it manually after symlink creation

#### Scenario: Unrecognised files in `.claude/`
- **WHEN** the backup contains files or directories the system does not recognise (e.g., user-authored notes, third-party tool state)
- **THEN** the system SHALL NOT move them and SHALL list them in the completion report under "Files left in backup — move manually if needed"

### Requirement: Symlink from workspace to meta-repo `.claude/`
After the meta-repo is initialised and contents migrated, the system SHALL create a symlink from `<workspace>/.claude` to `<meta-repo>/.claude` using `ln -sfn` semantics (replace existing symlink, fail if a non-symlink directory exists at the target).

The symlink target SHALL be expressed as a relative path (e.g., `meas.workspace/.claude` or `./meas.workspace/.claude`) so the workspace remains portable across cloned locations. Because the meta-repo lives inside the workspace root, the symlink target is a single-segment relative path — no `..` traversal.

#### Scenario: Symlink created successfully
- **WHEN** `<workspace>/.claude` does not exist (after migration)
- **THEN** the system SHALL create `<workspace>/.claude` as a symlink targeting `<meta-repo-basename>/.claude` (relative path, no `..` prefix)

#### Scenario: Symlink would replace a directory
- **WHEN** `<workspace>/.claude` exists as a non-symlink directory after migration (this should not happen if backup ran correctly)
- **THEN** the system SHALL refuse to overwrite, report the path conflict, and instruct the user to remove the directory manually before re-running

### Requirement: Windows / no-symlink fallback
On platforms or filesystems where symlink creation is unavailable or restricted, the system SHALL detect the failure and fall back to a copy-mode bootstrap: copy `<meta-repo>/.claude/` contents into `<workspace>/.claude/` and document the re-sync workflow.

The fallback SHALL be triggered automatically by symlink-creation failure, not by OS detection. The completion message SHALL clearly mark the bootstrap as copy-mode and include the re-sync command.

#### Scenario: Symlink creation fails
- **WHEN** the `ln -sfn` operation fails (Windows without developer mode, restricted filesystem, etc.)
- **THEN** the system SHALL `cp -R <meta-repo>/.claude/. <workspace>/.claude/`, write a `<workspace>/.claude/.copy-mode` marker file noting the bootstrap mode, and print "Symlinks unavailable — bootstrapped in copy mode. After `git pull` in <meta-repo>, re-sync with `<meta-repo>/setup.sh`."

#### Scenario: setup.sh in copy mode
- **WHEN** the user re-runs `<meta-repo>/setup.sh` after a `git pull` in copy-mode bootstrap
- **THEN** the script SHALL re-copy `.claude/` contents from the meta-repo into the workspace, replacing changed files

### Requirement: README contract
The generated `<meta-repo>/README.md` SHALL document: the workspace this meta-repo serves, how teammates bootstrap (one-line command using `/claudboard-workspace-link <remote-url>` or running `setup.sh` directly), what the meta-repo contains, and what should NOT be committed (settings.local.json, etc.).

#### Scenario: README explains teammate bootstrap
- **WHEN** a teammate clones the meta-repo and reads the README
- **THEN** the README SHALL contain a "First-time setup" section with the canonical command sequence: clone the meta-repo as a child of the workspace root (`git clone <url> <workspace>/<meta-repo-basename>`), then run `./setup.sh` from inside the cloned directory or `/claudboard-workspace-link <remote-url>` from the workspace root

### Requirement: setup.sh contract
The generated `<meta-repo>/setup.sh` SHALL be idempotent and SHALL produce a working symlink (or copy-mode equivalent) every time it runs. It SHALL detect existing correct setup and exit successfully without changes.

The script SHALL accept no arguments. Because the meta-repo lives inside the workspace root, the script SHALL infer the meta-repo path as `$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)` and the workspace root as `$(dirname "<meta-repo-path>")`. The script SHALL refuse to run if the inferred workspace root is itself a git repository.

#### Scenario: First-time run on POSIX
- **WHEN** a teammate runs `<meta-repo>/setup.sh` on macOS/Linux
- **THEN** the script SHALL create the symlink `<workspace>/.claude → <meta-repo>/.claude` and exit 0

#### Scenario: Re-run when symlink already correct
- **WHEN** the symlink already points at the meta-repo's `.claude/`
- **THEN** the script SHALL print "Already linked — no action needed" and exit 0

#### Scenario: Re-run after meta-repo path changed
- **WHEN** the symlink exists but points at a stale path (meta-repo was moved or re-cloned elsewhere)
- **THEN** the script SHALL replace the symlink with `ln -sfn` semantics and report the change

### Requirement: `/claudboard-workspace-link` flow
The teammate-side command SHALL clone the provided remote URL as a child directory inside the workspace root and then run the cloned `setup.sh`.

The chosen local directory name SHALL default to the basename inferred from the remote URL (e.g., `meas.workspace.git` → `meas.workspace`). The user SHALL be able to override the local name. The local name SHALL NOT collide with any existing subdirectory of the workspace.

#### Scenario: First teammate bootstrap
- **WHEN** a teammate runs `/claudboard-workspace-link git@host:org/meas.workspace.git` from a workspace root with no existing meta-repo
- **THEN** the system SHALL clone the repo as `<workspace>/<inferred-name>/`, run `<workspace>/<inferred-name>/setup.sh`, and report the resulting symlink path

#### Scenario: Stale sibling-layout symlink at workspace root
- **WHEN** the teammate's workspace already has a `.claude` symlink whose target resolves to a path outside the workspace root (pre-v3 sibling layout)
- **THEN** the system SHALL refuse with "Stale sibling-layout meta-repo detected at <resolved-path>. Remove the symlink and the old meta-repo manually, then re-run." and stop

#### Scenario: Meta-repo already cloned
- **WHEN** the inferred local path already exists AND its `git remote get-url origin` matches the requested URL
- **THEN** the system SHALL skip the clone, run `setup.sh` directly, and treat as success

#### Scenario: Local path collision
- **WHEN** the inferred local path exists but is not the expected meta-repo (different remote, or not a git repo at all)
- **THEN** the system SHALL refuse to clone, report the collision, and prompt the user for an alternative local name

### Requirement: Idempotency of `init` and `link`
Both bootstrap commands SHALL be safe to re-run without producing duplicate state, and SHALL surface clear "already done" messages instead of erroring.

#### Scenario: Re-running init on a bootstrapped workspace
- **WHEN** `/claudboard-workspace-init` is invoked on a workspace whose `.claude/` is already a healthy symlink to a meta-repo
- **THEN** the system SHALL exit with "Workspace already bootstrapped — meta-repo at <path>. Remote: <url>." and take no action

#### Scenario: Re-running link with same URL
- **WHEN** `/claudboard-workspace-link <url>` is invoked and the workspace is already linked to that meta-repo
- **THEN** the system SHALL re-run `setup.sh` (which is itself idempotent) and exit successfully

### Requirement: Completion report
After successful bootstrap, the system SHALL print a completion report listing: the meta-repo path, the symlink path, the remote URL (if any), the migrated files, the backup path (if any), files left in backup for manual handling, and the next-step suggestion to run `/claudboard-generate` (or `/claudboard-workflow`).

#### Scenario: Successful bootstrap with remote
- **WHEN** init completes with all steps successful and a remote configured
- **THEN** the report SHALL include the remote URL and the suggested teammate command: "Share this with your team: `/claudboard-workspace-link <remote-url>`"

#### Scenario: Successful bootstrap without remote
- **WHEN** init completes locally without a remote
- **THEN** the report SHALL include the command to add a remote later

### Requirement: Dispatcher routing
The dispatcher skill `claudboard` SHALL list both `claudboard-workspace-init` and `claudboard-workspace-link` in its routing table and SHALL describe their trigger phrases.

#### Scenario: Dispatcher invocation matches workspace bootstrap trigger
- **WHEN** a user phrase matches a `claudboard-workspace-init` or `claudboard-workspace-link` trigger and the dispatcher receives it
- **THEN** the dispatcher SHALL route to the matching skill and not to any other claudboard sibling

### Requirement: Plugin manifest entry
The plugin manifest at `.claude-plugin/plugin.json` SHALL list `claudboard-workspace-init` and `claudboard-workspace-link` so they ship with the plugin distribution.

#### Scenario: Plugin distribution
- **WHEN** the claudboard plugin is installed via the standard plugin mechanism
- **THEN** both bootstrap skills SHALL be available alongside the other claudboard sibling skills with no additional installation steps
