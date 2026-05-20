## ADDED Requirements

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
