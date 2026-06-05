## MODIFIED Requirements

### Requirement: Post-detection workspace handling SHALL set umbrella_root and route into the unified pipeline

After workspace detection identifies the workspace mode (per-repo `.git/` in subdirs of a non-git parent), the detection step SHALL:

1. Compute `umbrella_root = <workspace dir>` (the directory `/analyse` was invoked from, the one containing the service repos)
2. Classify each repo as service or library using the existing classification logic
3. Resolve `.claude/` and `.claudboard/` placement: if `<workspace>/.claude` is a symlink to a bootstrapped meta-repo, writes go through that symlink; otherwise writes are inline at `<workspace>/`
4. Route into the unified Phase 1 pipeline (same as monorepo) with `umbrella_root` and the classified repo list available to all subsequent phases

The workspace topology presentation step SHALL list the detected repos and stacks AND state the `umbrella_root` AND state whether the workspace has been bootstrapped (`.claude/` symlink present) OR whether outputs will be written inline with an instruction to bootstrap. The user confirms before the unified pipeline proceeds.

The prior "present workspace topology before analysis" requirement is amended to include the bootstrap status in the presentation.

#### Scenario: Bootstrapped workspace
- **WHEN** workspace mode is detected AND `<workspace>/.claude` is a symlink to `meas.workspace/.claude/`
- **THEN** the topology presentation states "Workspace bootstrapped — writing to meta-repo via symlink" AND outputs are written through the symlink to the meta-repo

#### Scenario: Non-bootstrapped workspace
- **WHEN** workspace mode is detected AND `<workspace>/.claude` is not a symlink (no meta-repo bootstrap has run)
- **THEN** the topology presentation states "Workspace NOT bootstrapped — outputs will be written inline at `<workspace>/.claudboard/` and `<workspace>/.claude/reports/`" AND the system creates those directories inline AND at completion prints one line: "To share `.claude/` across your team under git, run `/claudboard-workspace-init` next."

#### Scenario: Umbrella root passes through to all phases
- **WHEN** workspace detection completes
- **THEN** all subsequent phases (Phase 1b discovery, Phase 1c graph, Phase 3 writes) receive `umbrella_root` and use it for file location decisions; no phase branches on `mode == "workspace"` for write-path logic

---

### Requirement: Workspace detection SHALL continue to distinguish service repos from library repos

The existing classification logic (service vs library based on Dockerfile, main entry point, publish tasks) is preserved unchanged. Per-service CLAUDE.md and per-service catalog stack assignments apply only to service repos; library repos are excluded from per-service writes and from the umbrella ecosystem.md's per-service sections (they may still appear in services' Shared Contracts or Depends On entries).

#### Scenario: Library repo excluded from per-service CLAUDE.md and ecosystem.md sections
- **WHEN** workspace classifies `meas.cloud.common-dto` as a library (has publish task, no main entry, no Dockerfile)
- **THEN** no `meas.cloud.common-dto/CLAUDE.md` is written by `/generate` AND the umbrella ecosystem.md does NOT have a per-service section for it
- **AND** services that depend on it list it in their "Shared Contracts" or "Depends On" entries
