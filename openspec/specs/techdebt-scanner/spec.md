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

---

## Requirements (expand-comms-detection additions)

### Requirement: Architectural-pattern-gap debt category
The `claudboard-techdebt` skill SHALL introduce a new debt category — "architectural-pattern-gap" — covering missing patterns whose absence creates correctness, resilience, or evolvability risk given the project's detected transports and edges.

#### Scenario: Category present in report
- **WHEN** techdebt analysis identifies at least one architectural-pattern-gap finding
- **THEN** the report SHALL group those findings under a "Architectural Pattern Gaps" heading distinct from existing code-smell, design-debt, perf-debt, and arch-debt categories

#### Scenario: Reference file present
- **WHEN** `claudboard-techdebt` is loaded
- **THEN** the reference directory SHALL contain `arch-pattern-gaps.md` documenting detection rules, severity assignment, and fix suggestions for each gap type

### Requirement: Missing circuit breaker on outbound calls
The system SHALL flag a missing-circuit-breaker debt item when a service has at least one outbound sync-RPC, gRPC, or GraphQL edge AND no `circuit-breaker` entry appears in that service's `architectural_patterns` block.

#### Scenario: Outbound REST with no circuit breaker
- **WHEN** a service has at least one outbound edge with `family: "sync-rpc"` AND no `architectural_patterns` entry of `type: "circuit-breaker"`
- **THEN** the techdebt report SHALL contain a debt item with category "architectural-pattern-gap", subtype "missing-circuit-breaker", severity MEDIUM, location set to representative caller file:line, and fix suggestion referencing the project's stack-appropriate library (resilience4j for Java/Kotlin, opossum for Node)

#### Scenario: Circuit breaker present — no debt item
- **WHEN** a service has outbound sync-RPC edges AND its `architectural_patterns` contains a `circuit-breaker` entry
- **THEN** the techdebt report SHALL NOT emit a missing-circuit-breaker item for that service

### Requirement: Missing outbox on dual-write
The system SHALL flag a missing-outbox debt item when a service writes to both a database and a message broker within the same transactional boundary AND no `outbox` entry appears in that service's `architectural_patterns` block.

#### Scenario: Dual-write detected without outbox
- **WHEN** a `@Transactional` method (Java/Spring) contains both a repository write call (JPA `save`, Mongo `save`, JDBC `update`) AND a message-broker send call (KafkaTemplate, RabbitTemplate, JmsTemplate, kafkajs producer in equivalent Node transactional scope) AND the service's `architectural_patterns` contains no `outbox` entry
- **THEN** the techdebt report SHALL contain a debt item with category "architectural-pattern-gap", subtype "missing-outbox", severity HIGH, location set to the offending method file:line, and fix suggestion referencing the transactional-outbox pattern with a sample table schema

#### Scenario: Outbox already present — no debt item
- **WHEN** dual-write code exists AND the service's `architectural_patterns` contains an `outbox` entry
- **THEN** the techdebt report SHALL NOT emit a missing-outbox item for that method

### Requirement: Missing schema registry with Kafka
The system SHALL flag a missing-schema-registry debt item when a service contains Kafka producers or consumers AND no `schema-registry` entry appears in that service's `architectural_patterns` block.

#### Scenario: Kafka usage without schema registry
- **WHEN** a service has at least one edge with `protocol: "kafka"` (any direction) AND no `architectural_patterns` entry of `type: "schema-registry"`
- **THEN** the techdebt report SHALL contain a debt item with category "architectural-pattern-gap", subtype "missing-schema-registry", severity MEDIUM, location set to a representative Kafka producer or consumer file:line, and fix suggestion referencing Confluent Schema Registry or Apicurio Registry with sample serializer configuration

#### Scenario: Schema registry already present — no debt item
- **WHEN** a service has Kafka edges AND its `architectural_patterns` contains a `schema-registry` entry
- **THEN** the techdebt report SHALL NOT emit a missing-schema-registry item for that service

### Requirement: Backward compatibility for reports without Architectural Patterns subsection
The techdebt scanner SHALL treat a missing `architectural_patterns` block in the analysis report as "all architectural patterns absent" for the purpose of gap detection, but SHALL NOT emit gap findings without first warning the user that pattern detection data is missing.

#### Scenario: Missing subsection — warning emitted
- **WHEN** `claudboard-techdebt` reads an analysis report that lacks the "## Architectural Patterns" subsection AND the project has edges that would otherwise trigger gap detection
- **THEN** the report SHALL contain a warning "Architectural Patterns subsection absent — pattern-gap findings suppressed; re-run /analyse to populate" and SHALL NOT emit any architectural-pattern-gap items

#### Scenario: Subsection present but empty
- **WHEN** the analysis report contains "## Architectural Patterns" with an explicitly empty list
- **THEN** the techdebt scanner SHALL proceed with gap detection as normal (empty list is a confirmed absence, not missing data)
