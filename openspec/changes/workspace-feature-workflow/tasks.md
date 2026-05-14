## 1. Workspace meta-repo bootstrap — `claudboard-workspace-init`

- [x] 1.1 Create skill scaffold at `skills/claudboard-workspace-init/SKILL.md` with name, model, and trigger-phrase frontmatter
- [x] 1.2 Implement workspace-root prerequisite check (no `.git/` at CWD; ≥1 sibling subdir with build file + `.git/`)
- [x] 1.3 Implement plan-and-confirm gate that prints meta-repo name, target path, optional remote, contents to migrate, backup path
- [x] 1.4 Implement meta-repo name resolution with `<workspace-basename>.workspace` default and collision/conflict guards
- [x] 1.5 Implement backup of existing `<workspace>/.claude/` to `<workspace>/.claude.backup.<timestamp>/` (preserve symlinks, permissions)
- [x] 1.6 Implement meta-repo `git init` + scaffold (`.claude/{rules,reports,skills,changes}/`, `.gitignore`, `README.md`, `setup.sh`)
- [x] 1.7 Implement migration of standard files (`rules/`, `reports/`, `config.json`) from backup into meta-repo; leave `settings.local.json` and unrecognised files behind with report entry
- [x] 1.8 Implement symlink creation `<workspace>/.claude → ../<meta-repo>/.claude` using relative-path `ln -sfn`
- [x] 1.9 Implement Windows / no-symlink fallback (copy-mode bootstrap with `.copy-mode` marker and re-sync instructions)
- [x] 1.10 Implement initial commit + optional remote push with graceful failure handling (no rollback on push failure)
- [x] 1.11 Implement idempotency: detect existing healthy symlink and exit with "already bootstrapped" message
- [x] 1.12 Implement completion report (meta-repo path, symlink path, remote URL, migrated files, backup path, next-step guidance)
- [x] 1.13 Author `setup.sh` template — idempotent, infers paths, supports re-runs, refuses if workspace root has its own `.git/`
- [x] 1.14 Author `README.md` template — workspace identification, teammate bootstrap one-liner, do-not-commit notes
- [x] 1.15 Author `.gitignore` template — `settings.local.json`, `.DS_Store`, `*.swp`, claudboard ephemeral state

## 2. Workspace meta-repo bootstrap — `claudboard-workspace-link`

- [x] 2.1 Create skill scaffold at `skills/claudboard-workspace-link/SKILL.md` with trigger phrases and `<remote-url>` argument handling
- [x] 2.2 Implement workspace-root prerequisite check (same as `init`)
- [x] 2.3 Implement local directory name inference from remote URL with override prompt
- [x] 2.4 Implement clone + `setup.sh` invocation with collision detection (existing path / different remote)
- [x] 2.5 Implement idempotency: detect already-cloned matching remote and re-run `setup.sh`
- [x] 2.6 Implement completion message with resulting symlink path

## 3. Dispatcher and plugin manifest updates

- [x] 3.1 Update `skills/claudboard/SKILL.md` routing table to include `claudboard-workspace-init` and `claudboard-workspace-link` with trigger phrases
- [x] 3.2 Update `.claude-plugin/plugin.json` to register `claudboard-workspace-init` and `claudboard-workspace-link`

## 4. Multi-repo `feature-workflow` template — SKILL.md

- [x] 4.1 Add `<!-- IF WORKSPACE_MODE -->` blocks to existing `skills/claudboard-workflow/references/feature-workflow.template/SKILL.md` covering: Phase 1 affected_repos inference + user gate, per-repo phase loop language, Phase 6 parallel PR + merge order, Phase 7 single-ticket aggregation
- [x] 4.2 Add workspace-mode "agent architecture" section describing per-repo agent spawning model
- [x] 4.3 Add per-repo context-loading contract description (link to `scripts/load-repo-context.sh`)
- [x] 4.4 Add affected_repos inference instructions referencing per-repo analysis reports under `<workspace>/.claude/reports/`
- [x] 4.5 Add per-feature artifact placement section pointing at `<workspace>/.claude/changes/<TICKET>/` with master plan + slices structure

## 5. Multi-repo `feature-workflow` template — agents

- [x] 5.1 Update `architect-agent.md` template with workspace-mode block: affected_repos inference logic, per-repo plan slice authoring, master plan with Affected repos + Recommended PR merge order sections
- [x] 5.2 Update `implementation-agent.md` template with workspace-mode block: per-repo `repo` argument handling, mandatory per-repo context load on entry, all file operations scoped to `<workspace>/<repo>/`
- [x] 5.3 Update `git-agent.md` template with workspace-mode block: `repo` argument, all git operations via `(cd <workspace>/<repo> && ...)`, per-repo branch creation/commit/squash with same branch name across repos
- [x] 5.4 Update `pr-agent.md` template with workspace-mode block: `repo` argument, per-repo PR creation, all PRs opened in parallel (no merge polling)
- [x] 5.5 Update `design-reviewer.md` template with workspace-mode block: `repo` argument, mandatory per-repo context load on entry, per-repo review
- [x] 5.6 Update `spec-reviewer.md` template with workspace-mode block: `repo` argument, mandatory per-repo context load on entry, per-repo verification
- [x] 5.7 Update `jira-agent.md` template with workspace-mode block: aggregated worklog body (per-repo breakdown + merge order), single-ticket semantics

## 6. Multi-repo `feature-workflow` template — scripts and config

- [x] 6.1 Author `scripts/load-repo-context.sh` template — single Bash invocation that reads `<workspace>/<repo>/.claude/{CLAUDE.md,rules/*.md,memory/MEMORY.md}` and lists `<workspace>/<repo>/.claude/skills/*/SKILL.md`, prints concatenated content with file-path delimiters, no-ops missing files
- [x] 6.2 Update `scripts/lib.sh` template with `--repo` flag / `REPO_PATH` env var support; existing helpers (`prepare-commit.sh`, `prepare-pr.sh`, `prepare-squash.sh`) accept and forward
- [x] 6.3 Author workspace `config.json` template — top-level shared `jira/azureDevOps/git`, `repos: { ... }` map; multi-repo variant rendered when `WORKSPACE_MODE` true
- [x] 6.4 Add `{{REPOS_MAP_JSON}}` token rendering to substitution catalog with per-repo `azureDevOps.repositoryId` extracted from each repo's git remote; `[TODO: repositoryId]` stub when missing

## 7. Update generation pipeline — `claudboard-workflow` SKILL

- [x] 7.1 Add workspace-mode prerequisite check: refuse generation when `workspace: true` AND `<workspace>/.claude` is not a symlink to a meta-repo (instruct user to run `/claudboard-workspace-init` first)
- [x] 7.2 Implement workspace-mode target path resolution (write all files under `<workspace>/.claude/skills/feature-workflow/` resolving via the symlink)
- [x] 7.3 Add path-violation guard for workspace mode: refuse writes into any per-repo `.claude/` (no per-repo skill generation in workspace mode)
- [x] 7.4 Update existing-skill-detection to check the resolved (meta-repo) path in workspace mode
- [x] 7.5 Detect existing per-repo `feature-workflow/` skills in service repos; list them in the completion report with the explicit removal command (do NOT auto-delete)
- [x] 7.6 Update confirmation gate to surface workspace-specific summary (per-repo map, multi-repo skill, meta-repo path) when `WORKSPACE_MODE` true
- [x] 7.7 Update completion report to include workspace-specific guidance (path of generated skill in meta-repo, suggestion to commit + push in meta-repo, validation step)

## 8. Update reference catalogs

- [x] 8.1 Update `skills/claudboard-workflow/references/block-catalog.md` to document the multi-repo blocks now gated by `WORKSPACE_MODE` (SKILL.md phases, agent variants, scripts/load-repo-context.sh inclusion)
- [x] 8.2 Update `skills/claudboard-workflow/references/substitution-catalog.md` to add `{{REPOS_MAP_JSON}}` (source: per-repo `git remote -v` parsing; fallback: `[TODO: repositoryId]`; example for MEAS shape)
- [x] 8.3 Update `skills/claudboard-workflow/references/jira-config-prompts.md` if any new prompts are needed for workspace mode (none expected — existing prompts apply)

## 9. CLAUDE.md updates

- [x] 9.1 Document the workspace-mode bootstrap commands in `CLAUDE.md` skill anatomy section
- [x] 9.2 Document the workspace meta-repo concept and the symlink convention
- [x] 9.3 Note the v1-no-upgrade-path constraint applies to the multi-repo skill same as the single-repo one
- [x] 9.4 Note that pre-existing per-repo `feature-workflow/` skills in service repos coexist with the workspace skill until manually removed

## 10. End-to-end validation against MEAS workspace

- [ ] 10.1 Run `/claudboard-workspace-init` from `/Users/LUP1BG/Documents/BoschProjects/meas/` (test workspace); confirm meta-repo created, symlink in place, `rules/` + `reports/` migrated, backup recorded
- [ ] 10.2 Verify `/claudboard-workspace-link <remote>` from a fresh sibling clone (simulating teammate) produces a working symlink
- [ ] 10.3 Run `/claudboard-workflow` from MEAS workspace root; confirm multi-repo skill generated into meta-repo, all expected files present, `config.json` has `repos: { ... }` map populated for all 8 MEAS repos with detectable Azure DevOps remotes
- [ ] 10.4 Trigger `/start-feature` for a synthetic single-repo feature scoped to datahandler; confirm Phase 1-7 execute end-to-end with N=1 loop, single PR, single ticket
- [ ] 10.5 Trigger `/start-feature` for a synthetic cross-service feature touching common-dto + datahandler + controller; confirm: affected_repos inference + user confirmation, per-repo branches with same name, per-repo context loading observable in agent traces, parallel PRs created, recommended merge order printed, single Jira ticket with aggregated worklog
- [ ] 10.6 Verify `load-repo-context.sh` is invoked at least once per affected repo in implementation-agent traces
- [ ] 10.7 Verify pre-existing per-repo `feature-workflow/` skills in MEAS service repos are NOT modified or deleted by `init` or `workflow` runs; verify completion report lists them with the removal command
- [ ] 10.8 Verify idempotency: re-run `/claudboard-workspace-init` exits cleanly with "already bootstrapped"; re-run `/claudboard-workflow` refuses with the existing-skill message

## 11. Out-of-scope confirmations (no work, just sanity checks)

- [x] 11.1 Confirm `/claudboard-refresh` continues to skip `feature-workflow/` directories (existing refresh-exclusion requirement applies to multi-repo variant unchanged)
- [x] 11.2 Confirm no Phase 6 polling or merge-waiting code is introduced (parallel PR creation is intentional)
- [x] 11.3 Confirm no upgrade-path code is introduced for the multi-repo skill (consistent with v1 of single-repo variant)
