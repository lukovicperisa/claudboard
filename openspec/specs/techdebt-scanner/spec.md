## Requirements

### Requirement: Hybrid discovery
If `.claude/reports/claudboard-analysis.md` exists, parse and reuse anti-pattern findings. If per-service reports (`claudboard-analysis-{name}.md`) also exist, parse each and reuse per-service findings. Otherwise, run full Wide Scan. For monorepos, Wide Scan SHALL be scoped per service directory.

#### Scenario: Monorepo with per-service analysis reports
- **WHEN** `.claude/reports/` contains `claudboard-analysis.md` plus `claudboard-analysis-order-service.md` and `claudboard-analysis-frontend.md`
- **THEN** techdebt SHALL reuse findings from each per-service report and run per-service scans scoped to each service directory

#### Scenario: Monorepo without per-service reports
- **WHEN** `.claude/reports/claudboard-analysis.md` exists but no per-service reports
- **THEN** techdebt SHALL auto-detect services (same logic as analyse Phase 1a) and run per-service scans

#### Scenario: Single-project with analysis report
- **WHEN** only `claudboard-analysis.md` exists with no per-service reports
- **THEN** techdebt SHALL proceed with existing single-project flow unchanged

### Requirement: Debt item format
Each item has ID (prefixed per service for monorepos, e.g., `OS-01`, `FE-01`, `GL-01`; plain `TD-NNN` for single projects), category, severity, location (file:line), effort (S/M/L), dependencies (other TD items using prefixed IDs for cross-report references), description, impact, fix suggestion.

#### Scenario: Monorepo ID assignment
- **WHEN** analysing a monorepo with order-service and frontend
- **THEN** order-service findings SHALL use prefix derived from directory name (e.g., `OS-01`), frontend findings SHALL use their prefix (e.g., `FE-01`), and global findings SHALL use `GL-01`

#### Scenario: Cross-report dependency
- **WHEN** `OS-03` depends on `GL-01`
- **THEN** the `Depends on` field SHALL contain `GL-01`

#### Scenario: Single-project ID format unchanged
- **WHEN** analysing a single-project repository
- **THEN** findings SHALL use `TD-NNN` format as before

### Requirement: Module grouping
Items grouped by detected module (service dir for monorepos, domain package or feature dir within a service). Cross-module items in separate section. For monorepos, each service's report groups by its internal modules. The global report contains cross-service and infrastructure items.

#### Scenario: Monorepo module grouping
- **WHEN** techdebt completes on a monorepo
- **THEN** each per-service report SHALL group findings by the service's internal modules, and the global report SHALL contain cross-cutting findings

### Requirement: Output
For single projects: `.claude/reports/tech-debt/summary.md`, `modules/<name>.md`, `cross-cutting.md` (unchanged).

For monorepos: `.claude/reports/tech-debt/summary.md` (global overview with per-service summary table), `services/<service-name>/modules/<name>.md`, `services/<service-name>/cross-cutting.md`, and top-level `cross-cutting.md` for repo-wide debt.

#### Scenario: Monorepo output structure
- **WHEN** techdebt completes on a monorepo with order-service and frontend
- **THEN** output SHALL include `summary.md` (global), `services/order-service/modules/*.md`, `services/frontend/modules/*.md`, and top-level `cross-cutting.md`

#### Scenario: Single-project output unchanged
- **WHEN** techdebt completes on a single-project repo
- **THEN** output SHALL use existing structure unchanged

### Requirement: Workspace-level refresh updates all ecosystem files
When `/refresh` is run from the workspace root directory (workspace mode detected), the system SHALL re-run the cross-service graph construction and update all service repos' `ecosystem.md` files.

#### Scenario: Workspace refresh updates all ecosystem files
- **WHEN** `/refresh` is run from the workspace root AND workspace mode is detected
- **THEN** the system SHALL re-run Phase 1c (graph construction) and overwrite `ecosystem.md` in all service repos

#### Scenario: New service added since last workspace analysis
- **WHEN** a new repo directory appears at workspace level that was not in the prior analysis
- **THEN** workspace refresh SHALL flag: "New repo detected: {dir-name}. Run `/analyse` from workspace root to include it in the ecosystem graph."

### Requirement: Service-level refresh warns about stale sibling ecosystem files
When `/refresh` is run from within a single service repo (not workspace root), the system SHALL update only that service's `ecosystem.md` from its own perspective and warn that sibling files may be stale.

#### Scenario: Service-level refresh with stale warning
- **WHEN** `/refresh` is run from `order-service/` AND an `ecosystem.md` exists in the repo
- **THEN** the system SHALL update `order-service/.claude/memories/ecosystem.md` for that service's outbound changes AND display: "Ecosystem files in sibling services (user-service, notification-service) may be stale — run `/refresh` from workspace root to sync all."

#### Scenario: Service-level refresh with no workspace context
- **WHEN** `/refresh` is run from a service repo AND no sibling repos are detectable at parent level
- **THEN** the system SHALL proceed with normal service-level refresh without any ecosystem file updates or warnings
