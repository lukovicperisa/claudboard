## MODIFIED Requirements

### Requirement: `/generate` SHALL apply the unified umbrella-root rule across all modes

`/generate` SHALL produce CLAUDE.md, rules, skills, and memories at the umbrella root in single-project, monorepo, and workspace modes. The unified write rule from the `umbrella-root-output` capability applies: no writes under any per-service `.claude/` directory.

Workspace mode `/generate` SHALL read the catalog at `<workspace>/.claudboard/catalog.json` (via meta-repo symlink when bootstrapped) and write all artifacts to `<workspace>/.claude/` and per-service `<workspace>/<repo>/CLAUDE.md`. It SHALL NOT write per-repo `.claude/` content.

Monorepo mode `/generate` SHALL read the catalog at `<repo-root>/.claudboard/catalog.json` and write all artifacts to `<repo-root>/.claude/` and per-service `<repo-root>/<service>/CLAUDE.md`. It SHALL NOT write per-service `.claude/` content (a change from prior monorepo behaviour, which may have written per-service rules or skills in some cases).

The prior `monorepo-generation` behaviour that produced per-service `.claude/` content is REPLACED.

#### Scenario: Monorepo generation writes only at umbrella root
- **WHEN** `/generate` runs against craftsphere.cloud (19-service monorepo)
- **THEN** all skills, rules, and memories are written under `<repo-root>/.claude/`; per-service CLAUDE.md files are written for each detected service; no other per-service files are written

#### Scenario: Workspace generation writes only at umbrella root
- **WHEN** `/generate` runs against MEAS workspace
- **THEN** all skills, rules, and memories are written under `<workspace>/.claude/`; per-service CLAUDE.md files are written for each detected service repo; no `<repo>/.claude/skills/`, `<repo>/.claude/rules/`, or `<repo>/.claude/memories/` writes occur

#### Scenario: Per-service CLAUDE.md count matches service count
- **WHEN** `/generate` runs against a multi-service project (monorepo or workspace) with N detected services
- **THEN** N per-service CLAUDE.md files are written (one per service, none for libraries)

---

### Requirement: `/generate` skill output SHALL use Pattern A (dispatcher + references) for service-specific procedural content

When the catalog's `proposed_artifacts` includes a skill entry marked as having per-service variations (e.g. via a `per_service: true` flag or by the entry naming multiple service-specific exemplars), `/generate` SHALL produce that skill as a Pattern A dispatcher:

- One SKILL.md at `<umbrella_root>/.claude/skills/<concern>/SKILL.md` that enumerates the exact valid service names (closed-set) and instructs deterministic exact-match dispatch
- One reference file at `<umbrella_root>/.claude/skills/<concern>/references/<service>.md` per service (filename exactly matches the service directory name)

The SKILL.md SHALL NOT use fuzzy or model-interpretive matching for service-name dispatch; the valid set is fixed at generation time.

Pattern B (one skill per service at the umbrella root) SHALL NOT be produced by `/generate` in v1. Pattern B is documented as a future promotion path for services with substantial procedural content; it is not part of v1 generation logic.

#### Scenario: Per-service skill produced as Pattern A dispatcher
- **WHEN** the catalog indicates that service-deploy is per-service for 5 services
- **THEN** `/generate` writes one `<umbrella_root>/.claude/skills/service-deploy/SKILL.md` enumerating the 5 service names AND 5 reference files at `<umbrella_root>/.claude/skills/service-deploy/references/<svc>.md`

#### Scenario: SKILL.md enumerates exact service names
- **WHEN** the dispatcher skill is written for services [meas.cloud.controller, meas.cloud.subscription, meas.cloud.profile-mapper]
- **THEN** the SKILL.md body contains an explicit listing of those exact names AND instructs the agent to load `references/<name>.md` only for an exact match

#### Scenario: Pattern B not produced in v1
- **WHEN** `/generate` processes a per-service skill entry
- **THEN** the output is a single dispatcher skill with references (Pattern A); no `<umbrella_root>/.claude/skills/<svc>-info/` per-service directories are produced

---

### Requirement: `/generate` SHALL write per-service CLAUDE.md as the only per-service artifact

`/generate` SHALL write one CLAUDE.md per detected service at `<umbrella_root>/<service>/CLAUDE.md` in monorepo and workspace modes. Per-service CLAUDE.md is the only per-service file `/generate` writes outside the umbrella `.claude/`.

Per-service CLAUDE.md SHALL be short (≤ 30 lines target, ≤ 50 lines hard limit) and SHALL reference the umbrella `.claude/memories/ecosystem.md` and umbrella `.claude/rules/` rather than duplicating their content. Per-service CLAUDE.md is loaded by Claude Code's dynamic down-walk when a sub-agent reads files in that subdirectory.

Per-service CLAUDE.md is NOT written for libraries or for the umbrella root itself.

#### Scenario: Per-service CLAUDE.md generated for each service
- **WHEN** workspace mode detects 14 service repos and 0 libraries
- **THEN** 14 per-service CLAUDE.md files are written

#### Scenario: Per-service CLAUDE.md is short
- **WHEN** a per-service CLAUDE.md is written
- **THEN** the file is ≤ 50 lines AND references umbrella `.claude/memories/ecosystem.md`

---

### Requirement: `/generate` summary SHALL explicitly confirm no per-service `.claude/` writes occurred

On completion, `/generate` SHALL print a summary listing every written file, grouped by location (umbrella `.claude/`, per-service CLAUDE.md count, umbrella `.claudboard/`). The summary SHALL explicitly state when no per-service `.claude/` writes occurred (the expected v1 outcome).

#### Scenario: Summary confirms umbrella-only writes
- **WHEN** `/generate` completes
- **THEN** the summary contains a line like "Per-service .claude/ writes: 0 (umbrella-only rule)"
