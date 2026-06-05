## ADDED Requirements

### Requirement: `/generate` SHALL write all architectural artifacts only at the umbrella root

`/generate` (and `/refresh`) SHALL write the following artifact categories only at the umbrella root, where "umbrella root" is:

- the repository root for `mode: "single-project"` and `mode: "monorepo"`
- the workspace directory for `mode: "workspace"` (resolved via the `.claude/` symlink to the meta-repo when bootstrapped, or inline at the workspace directory when not bootstrapped)

The categories are:

1. Skills (`<umbrella_root>/.claude/skills/<name>/SKILL.md` and their `references/`, `scripts/` subtrees)
2. Rules (`<umbrella_root>/.claude/rules/*.md`, with `paths:` globs targeting service subdirectories where needed)
3. Memories (`<umbrella_root>/.claude/memories/*.md`, including the umbrella-wide `ecosystem.md`)
4. Umbrella CLAUDE.md (`<umbrella_root>/CLAUDE.md`)

The system SHALL NOT write into any of the following paths under any mode:

- `<umbrella_root>/<service>/.claude/skills/...`
- `<umbrella_root>/<service>/.claude/rules/...`
- `<umbrella_root>/<service>/.claude/memories/...`

The rationale is that Claude Code discovers skills, rules, and memories by walking UP from the session's current working directory. When feature-workflow runs from the umbrella root, per-service `.claude/` subdirectories are DOWN from CWD and are never loaded. Subagents spawned via the Agent tool inherit the parent session's CWD by default and re-discover from there, so per-service `.claude/` content remains invisible.

#### Scenario: Workspace mode generation writes only at umbrella root
- **WHEN** `/generate` runs against a workspace project with 14 service repos
- **THEN** every file `/generate` writes is under `<workspace>/.claude/...`, `<workspace>/.claudboard/...`, `<workspace>/CLAUDE.md`, or per-service `<workspace>/<repo>/CLAUDE.md`
- **AND** no file is written under any `<workspace>/<repo>/.claude/skills/`, `<workspace>/<repo>/.claude/rules/`, or `<workspace>/<repo>/.claude/memories/` path

#### Scenario: Monorepo mode generation writes only at umbrella root
- **WHEN** `/generate` runs against a monorepo with 19 services
- **THEN** every file `/generate` writes is under `<repo-root>/.claude/...`, `<repo-root>/.claudboard/...`, `<repo-root>/CLAUDE.md`, or per-service `<repo-root>/<service>/CLAUDE.md`
- **AND** no file is written under any per-service `<service>/.claude/skills/`, `<service>/.claude/rules/`, or `<service>/.claude/memories/` path

#### Scenario: Single-project mode trivially conforms
- **WHEN** `/generate` runs against a single-project repo
- **THEN** writes are under `<repo-root>/.claude/...`, `<repo-root>/.claudboard/...`, and `<repo-root>/CLAUDE.md` only

---

### Requirement: Per-service CLAUDE.md SHALL be the only per-service runtime artifact

`/generate` SHALL write one short CLAUDE.md per detected service at `<umbrella_root>/<service>/CLAUDE.md` in monorepo and workspace modes. Per-service CLAUDE.md is the only per-service file written by claudboard skills.

The rationale is that Claude Code performs a dynamic down-walk for CLAUDE.md specifically: when an agent reads a file in a subdirectory, Claude Code loads that subdirectory's CLAUDE.md at that moment. This makes per-service CLAUDE.md the right place for short, service-specific orientation that becomes relevant exactly when a sub-agent works in that service.

Per-service CLAUDE.md SHALL be short (≤ 30 lines target, ≤ 50 lines hard limit) and SHALL reference the umbrella context (`<umbrella_root>/.claude/memories/ecosystem.md` and umbrella `.claude/rules/`) rather than duplicating it.

#### Scenario: Per-service CLAUDE.md is short and references umbrella
- **WHEN** `/generate` writes `<workspace>/meas.cloud.controller/CLAUDE.md`
- **THEN** the file is ≤ 50 lines AND contains a line pointing at the umbrella ecosystem.md (e.g. "For workspace topology, see umbrella `.claude/memories/ecosystem.md`")

#### Scenario: Per-service CLAUDE.md exists for every detected service
- **WHEN** workspace mode detects 14 service repos
- **THEN** 14 per-service CLAUDE.md files are written (one per service); library repos do not receive a CLAUDE.md

#### Scenario: Single-project mode does not write per-service CLAUDE.md
- **WHEN** `/generate` runs against a single-project repo (no per-service split)
- **THEN** only the umbrella CLAUDE.md is written; no per-service CLAUDE.md is produced

---

### Requirement: Service-specific content SHALL reach the umbrella root via documented channels

Service-specific content that needs to participate in runtime context SHALL be packaged through one of three channels at the umbrella root:

1. **Rules with `paths:` globs** — for service-specific conventions and coding rules. Single rule file at `<umbrella_root>/.claude/rules/*.md` with `paths:` glob matching service subdirectories. The rule is loaded when the agent reads a file matching the glob.
2. **Umbrella ecosystem.md** — for service-specific topology, dependencies, and cross-service edges. Single file at `<umbrella_root>/.claude/memories/ecosystem.md` containing one section per service.
3. **Dispatcher skill (Pattern A)** — for service-specific procedural content (deploy procedures, custom workflows). One skill at `<umbrella_root>/.claude/skills/<concern>/SKILL.md` that enumerates valid service names in its body and dispatches by exact-match to `references/<service>.md` on demand.

Per-service skill directories (`<umbrella_root>/.claude/skills/<service>-info/SKILL.md` per service, "Pattern B") are NOT generated in v1. Pattern B is documented as a future promotion path for services with substantial procedural content that doesn't fit a shared dispatcher; promotion is out of scope for v1.

#### Scenario: Conventions become rules with paths
- **WHEN** the catalog has a `proposed_artifacts` entry `{type: "rule", name: "java-conventions", paths: ["meas.cloud.*/**/*.java"]}`
- **THEN** `/generate` writes one file at `<umbrella_root>/.claude/rules/java-conventions.md` with the `paths:` glob in frontmatter; no per-service rules files are written

#### Scenario: Topology becomes umbrella ecosystem.md
- **WHEN** the catalog and dependency graph describe cross-service edges across 14 services
- **THEN** `/generate` (and `/analyse`) writes a single `<umbrella_root>/.claude/memories/ecosystem.md` containing one section per service with role / depends-on / used-by / shared-contracts / coupling-warnings

#### Scenario: Procedural content becomes Pattern A dispatcher
- **WHEN** the catalog has a `proposed_artifacts` entry indicating per-service procedural content (e.g. `{type: "skill", name: "service-info", per_service: true}`)
- **THEN** `/generate` writes one skill at `<umbrella_root>/.claude/skills/service-info/SKILL.md` that enumerates the valid service names AND writes one `references/<service>.md` per service inside that skill
- **AND** `/generate` does NOT write per-service skill directories like `service-info-controller/`, `service-info-subscription/`

---

### Requirement: Pre-existing per-service `.claude/` directories SHALL be left untouched

`/generate` and `/refresh` SHALL NOT delete, move, or rewrite any pre-existing per-service `.claude/` directories or their contents. Such directories may exist from runs of prior claudboard versions that wrote per-service artifacts.

These directories do no runtime harm (they were never auto-loaded by Claude Code in workflows starting at the umbrella root). Users may delete them manually; a future `--prune-stale` flag is out of scope here.

#### Scenario: Pre-existing per-service skills directory is preserved
- **WHEN** `/generate` runs against a project that has `<workspace>/<repo>/.claude/skills/legacy-skill/SKILL.md` from a prior claudboard version
- **THEN** that file is not modified, deleted, or moved by `/generate`

#### Scenario: User-authored per-service `.claude/` content is preserved
- **WHEN** a developer has hand-written `<repo>/.claude/settings.local.json` in a service subdirectory
- **THEN** `/generate` does not touch it; the umbrella-only rule applies to claudboard-generated artifacts, not to user-owned files

---

### Requirement: `/generate` SHALL document the umbrella-only rule in its summary output

On completion, `/generate` SHALL print a summary listing every written file. The summary SHALL group files by location (umbrella `.claude/`, per-service CLAUDE.md count, `.claudboard/`) and SHALL explicitly state when no per-service `.claude/` writes occurred. This visibility helps users (and reviewers) confirm the umbrella-only rule was honoured.

#### Scenario: Summary lists umbrella writes and per-service CLAUDE.md count
- **WHEN** `/generate` completes against a workspace with 14 services
- **THEN** the summary contains a "Per-service CLAUDE.md: 14 files (one per service)" line AND a "No writes under per-service `.claude/` directories" confirmation

#### Scenario: Summary in single-project mode
- **WHEN** `/generate` completes against a single-project repo
- **THEN** the summary lists umbrella writes only; per-service CLAUDE.md and per-service `.claude/` lines are absent or marked "N/A (single-project)"
