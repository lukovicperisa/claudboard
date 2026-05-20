## Requirements

### Requirement: Detect monorepo report structure
The generate skill SHALL detect monorepo analysis by checking for `claudboard-analysis-*.md` files alongside the global `claudboard-analysis.md` report.

#### Scenario: Monorepo reports present
- **WHEN** `.claude/reports/` contains `claudboard-analysis.md` plus one or more `claudboard-analysis-*.md` files
- **THEN** generate SHALL read all reports and enter monorepo generation mode

#### Scenario: Single-project report only
- **WHEN** `.claude/reports/` contains only `claudboard-analysis.md` with no per-service reports
- **THEN** generate SHALL proceed with existing single-project generation unchanged

### Requirement: Generate monorepo CLAUDE.md
The generate skill SHALL produce a CLAUDE.md with monorepo-specific structure when operating in monorepo mode.

The CLAUDE.md SHALL include:
- Project overview mentioning monorepo topology
- Services table listing each service with its stack and directory
- Per-service build and test commands
- Shared libraries section listing libraries and which services consume them
- Global conventions (branch strategy, commit format, CI/CD)

#### Scenario: CLAUDE.md services table
- **WHEN** generating for a monorepo with order-service (Java/Spring), user-service (Java/Spring), and frontend (React/TS)
- **THEN** CLAUDE.md SHALL include a services table with name, stack, directory, and build/test commands for each

#### Scenario: Shared library documentation
- **WHEN** a library `craftsphere.core` is detected as a dependency of order-service and user-service
- **THEN** CLAUDE.md SHALL list it under Shared Libraries with its consumers

### Requirement: Generate per-service scoped rules
The generate skill SHALL produce rule files scoped to each service's directory using `paths:` frontmatter.

#### Scenario: Per-service rule generation
- **WHEN** order-service uses constructor DI and Spock tests
- **THEN** generate SHALL produce `rules/order-service-conventions.md` with `paths: ["order-service/**"]` containing those conventions

#### Scenario: Global rules without paths
- **WHEN** generating rules for repo-level concerns (CI/CD, GitOps, commit conventions)
- **THEN** generate SHALL produce rule files without `paths:` frontmatter (applies everywhere)

#### Scenario: Different conventions across services
- **WHEN** order-service uses JUnit 5 and user-service uses Spock for testing
- **THEN** generate SHALL produce separate rule files for each service, not merge them into one

### Requirement: Generate per-service skills when warranted
The generate skill SHALL evaluate skill generation per service. If a service's analysis report proposes skills, those skills SHALL be scoped to the service.

#### Scenario: Service-specific skill
- **WHEN** the frontend service report proposes a "component-generator" skill
- **THEN** the skill's SKILL.md SHALL reference the frontend directory and its conventions, not the whole repo

### Requirement: Refresh handles service topology changes
The refresh skill SHALL detect service additions and removals by comparing current build roots against existing per-service reports.

#### Scenario: New service added
- **WHEN** a new build root is detected that has no matching `claudboard-analysis-*.md` report
- **THEN** refresh SHALL flag: "New service detected: {name}. Run /analyse to include it."

#### Scenario: Service removed
- **WHEN** a `claudboard-analysis-{name}.md` report exists but its directory is gone
- **THEN** refresh SHALL flag: "Service removed: {name}. Stale report and rules can be deleted."

#### Scenario: Service renamed
- **WHEN** a directory is renamed but contents match an existing report's stack/structure
- **THEN** refresh SHALL flag: "Service appears renamed: {old} -> {new}. Re-run /analyse to update."
