## ADDED Requirements

### Requirement: Split analysis phases into global and per-service
The system SHALL restructure the analyse workflow for monorepos into global-once and per-service passes.

**Global (runs once):**
- Phase 1a: monorepo structure detection and classification
- Phase 1b: CI/CD pipeline structure, GitOps/IaC, cross-service communication (event topics, API contracts), shared library inventory, branch/commit conventions

**Per-service (runs for each detected service):**
- Phase 1c: Wide Scan grep patterns scoped to service directory
- Phase 1d: File budget applied per service independently
- Phase 1e: File selection and reading per service
- Phase 1f: Call-path tracing per service

#### Scenario: Monorepo with 3 services
- **WHEN** 3 services are detected (order-service, user-service, frontend)
- **THEN** global scan runs once, then Phase 1c-f runs 3 times (once per service), each scoped to the service's directory

#### Scenario: Wide Scan scoping
- **WHEN** running Wide Scan for a specific service
- **THEN** all grep/find commands SHALL be rooted at the service's directory (e.g., `find order-service/src/main -name '*.java'`), not the repository root

### Requirement: Per-service quality scoring
Phase 2 SHALL score each service independently across all quality dimensions. Each service gets its own 6-dimension quality score.

#### Scenario: Services with different quality levels
- **WHEN** order-service has tests + CI gate + coverage, and frontend has tests only
- **THEN** order-service SHALL score "Good" for Testing and frontend SHALL score "Basic" for Testing, independently

#### Scenario: Per-service convention profiling
- **WHEN** order-service uses constructor DI and user-service uses field injection
- **THEN** each service report SHALL reflect its own DI convention, not an averaged or majority-wins global convention

### Requirement: N+1 report output
The system SHALL produce one global report plus one report per detected service.

**Global report** (`claudboard-analysis.md`) SHALL contain:
- Repo topology (services + libraries with directory paths)
- CI/CD pipeline structure
- GitOps/IaC configuration
- Cross-service communication patterns
- Shared library inventory
- Branch/commit conventions
- Per-service summary table with quality scores and links to service reports
- Overall quality variance note

**Per-service report** (`claudboard-analysis-{directory-name}.md`) SHALL contain:
- Stack & versions
- DI style, logging, error handling conventions
- Test framework & coverage
- Architecture pattern
- 6-dimension quality score
- Watch/Preserve findings
- Proposed scoped artifacts with `paths:` frontmatter targeting the service directory

#### Scenario: Report naming
- **WHEN** a service lives in directory `order-service/`
- **THEN** its report SHALL be named `claudboard-analysis-order-service.md`

#### Scenario: Single-project fallback
- **WHEN** the repository is not a monorepo
- **THEN** the system SHALL produce a single `claudboard-analysis.md` as before (no behavioral change)

### Requirement: Per-service techdebt with namespaced IDs
The techdebt skill SHALL produce per-service scoped scans with prefixed TD-IDs when operating on a monorepo.

**ID prefix derivation:**
- Use directory name initials if unique across services (e.g., `order-service` -> `OS`, `frontend` -> `FE`)
- If initials collide, use first 3 characters of each hyphen-separated segment
- Global findings use `GL` prefix

#### Scenario: Techdebt ID namespacing
- **WHEN** techdebt runs on a monorepo with order-service and frontend
- **THEN** order-service findings SHALL use `OS-01`, `OS-02` etc. and frontend findings SHALL use `FE-01`, `FE-02` etc.

#### Scenario: Cross-report dependencies
- **WHEN** a per-service finding (e.g., `OS-03: Migrate date handling`) depends on a global finding (e.g., `GL-01: Upgrade shared library`)
- **THEN** the `Depends on` field SHALL reference the prefixed ID: `Depends on: GL-01`

#### Scenario: Techdebt report structure
- **WHEN** techdebt completes on a monorepo
- **THEN** it SHALL produce `claudboard-techdebt.md` (global/cross-cutting) plus `claudboard-techdebt-{directory-name}.md` per service
