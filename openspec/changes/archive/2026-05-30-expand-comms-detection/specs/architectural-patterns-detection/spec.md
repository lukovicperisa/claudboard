## ADDED Requirements

### Requirement: Architectural Patterns subsection in analysis report
The `claudboard-analyse` skill SHALL produce an "Architectural Patterns" subsection in the analysis report. The subsection SHALL list each detected architectural pattern with its type, supporting evidence (file:line references), and pattern-specific attributes. The subsection SHALL always be present even when no patterns are detected (in which case the list is empty).

#### Scenario: Subsection presence in any report
- **WHEN** `claudboard-analyse` runs on any project (workspace or single-repo)
- **THEN** the generated report SHALL contain a "## Architectural Patterns" section

#### Scenario: Subsection in monorepo per-service report
- **WHEN** `claudboard-analyse` runs in monorepo mode and produces per-service reports
- **THEN** each per-service report SHALL contain its own "## Architectural Patterns" section scoped to that service

#### Scenario: No patterns detected
- **WHEN** the project contains no detectable architectural patterns
- **THEN** the section SHALL still be present with an empty list (`architectural_patterns: []`)

### Requirement: Saga pattern detection
The system SHALL detect the Saga pattern and classify its style as `orchestration` or `choreography`. Detection requires at least two confirming signals to reduce false positives.

#### Scenario: Orchestration saga detected
- **WHEN** the codebase contains a workflow-engine dependency (Camunda, Zeebe, Spring State Machine, AWS Step Functions SDK, Temporal SDK) AND a class that coordinates calls to three or more other services or topics within a single method
- **THEN** the architectural_patterns list SHALL include `{ "type": "saga", "style": "orchestration", "evidence": [<file:line references>] }`

#### Scenario: Choreography saga detected
- **WHEN** the codebase contains paired event names following a state-transition convention (e.g., `OrderPlaced`/`OrderCompleted`/`OrderFailed` or `*.Started`/`*.Completed`/`*.Failed`) across two or more services with no central orchestrator
- **THEN** the architectural_patterns list SHALL include `{ "type": "saga", "style": "choreography", "evidence": [<file:line references>] }`

#### Scenario: Insufficient signal — saga not recorded
- **WHEN** only one signal is present (e.g., a Camunda dependency with no orchestrator class)
- **THEN** the system SHALL NOT record a saga entry

### Requirement: CQRS pattern detection
The system SHALL detect CQRS when the codebase exhibits separate command and query models or directory structures.

#### Scenario: CQRS via package convention
- **WHEN** the codebase contains parallel `command/` and `query/` packages (or `commands/`/`queries/`, `write/`/`read/`) with at least two classes in each
- **THEN** the architectural_patterns list SHALL include `{ "type": "cqrs", "evidence": [<package paths>] }`

#### Scenario: CQRS via Axon Framework
- **WHEN** the codebase declares a dependency on `axon-spring-boot-starter` or `axon-framework` AND contains `@CommandHandler` and `@QueryHandler` annotations
- **THEN** the architectural_patterns list SHALL include `{ "type": "cqrs", "evidence": [<annotation file:line refs>] }`

### Requirement: Outbox pattern detection
The system SHALL detect the transactional outbox pattern via schema migrations, library use, or change-data-capture configuration.

#### Scenario: Outbox table in migrations
- **WHEN** a SQL migration file (Flyway, Liquibase, Alembic, Knex, or similar) contains `CREATE TABLE outbox` or a table named `outbox_events`, `event_outbox`, or `message_outbox`
- **THEN** the architectural_patterns list SHALL include `{ "type": "outbox", "evidence": [<migration file path>] }`

#### Scenario: Outbox library dependency
- **WHEN** the codebase declares a dependency on `transactional-outbox`, `debezium-connector-postgres`, `debezium-connector-mysql`, or `eventuate-tram`
- **THEN** the architectural_patterns list SHALL include `{ "type": "outbox", "evidence": [<dependency declaration>] }`

### Requirement: BFF (Backend for Frontend) detection
The system SHALL detect a Backend-for-Frontend service in workspace mode by classifying any service that exposes HTTP endpoints AND makes outbound calls to two or more other workspace services without persisting domain data.

#### Scenario: Spring BFF service
- **WHEN** a workspace service contains `@RestController` endpoints AND outbound calls (Feign / RestTemplate / WebClient) to two or more sibling repos AND contains no JPA `@Entity` or Mongo `@Document` annotations
- **THEN** the architectural_patterns list SHALL include `{ "type": "bff", "evidence": [<controller path>, <client paths>] }`

#### Scenario: Next.js route handlers as BFF
- **WHEN** a workspace service is a Next.js application with route handlers under `app/api/` or `pages/api/` that call two or more sibling services
- **THEN** the architectural_patterns list SHALL include `{ "type": "bff", "evidence": [<route handler paths>] }`

#### Scenario: Single-repo mode skips BFF detection
- **WHEN** analysis is running in single-repo mode (no sibling services)
- **THEN** the system SHALL NOT attempt BFF detection

### Requirement: API composition detection
The system SHALL detect the API composition pattern when a single endpoint aggregates responses from two or more downstream services.

#### Scenario: Aggregator endpoint
- **WHEN** a single controller method contains two or more outbound HTTP calls (Feign/RestTemplate/WebClient/axios/fetch) and combines their results into a single response
- **THEN** the architectural_patterns list SHALL include `{ "type": "api-composition", "evidence": [<controller method file:line>] }`

### Requirement: Circuit breaker detection
The system SHALL detect circuit breaker usage and identify the underlying library.

#### Scenario: Resilience4j detected
- **WHEN** the codebase contains a `@CircuitBreaker`, `@Retry`, or `@Bulkhead` annotation from Resilience4j OR declares a `resilience4j-spring-boot` dependency
- **THEN** the architectural_patterns list SHALL include `{ "type": "circuit-breaker", "library": "resilience4j", "evidence": [<annotation or dependency refs>] }`

#### Scenario: Hystrix detected (legacy)
- **WHEN** the codebase contains a `@HystrixCommand` annotation or declares a `spring-cloud-starter-netflix-hystrix` dependency
- **THEN** the architectural_patterns list SHALL include `{ "type": "circuit-breaker", "library": "hystrix", "evidence": [<refs>] }`

#### Scenario: Opossum detected (Node)
- **WHEN** a Node service declares a dependency on `opossum`
- **THEN** the architectural_patterns list SHALL include `{ "type": "circuit-breaker", "library": "opossum", "evidence": [<package.json>] }`

### Requirement: Schema registry detection
The system SHALL detect schema registry use and identify the vendor.

#### Scenario: Confluent Schema Registry
- **WHEN** the codebase contains a `schema.registry.url` configuration entry OR declares a dependency on `kafka-avro-serializer`, `kafka-protobuf-serializer`, or `kafka-json-schema-serializer`
- **THEN** the architectural_patterns list SHALL include `{ "type": "schema-registry", "vendor": "confluent", "evidence": [<config or dependency refs>] }`

#### Scenario: Apicurio Registry
- **WHEN** the codebase declares a dependency on `apicurio-registry-serdes-*` OR contains an `apicurio.registry.url` configuration entry
- **THEN** the architectural_patterns list SHALL include `{ "type": "schema-registry", "vendor": "apicurio", "evidence": [<refs>] }`

#### Scenario: TypeScript Confluent Schema Registry
- **WHEN** a Node service declares a dependency on `@kafkajs/confluent-schema-registry`
- **THEN** the architectural_patterns list SHALL include `{ "type": "schema-registry", "vendor": "confluent", "evidence": [<package.json>] }`

### Requirement: AsyncAPI spec detection
The system SHALL detect the presence of AsyncAPI specifications and record their paths.

#### Scenario: AsyncAPI spec file present
- **WHEN** the codebase contains any of `asyncapi.yml`, `asyncapi.yaml`, `asyncapi.json`, or files matching `**/*.asyncapi.{yml,yaml,json}` at any depth (excluding `node_modules`, `target`, `dist`, `build`)
- **THEN** the architectural_patterns list SHALL include `{ "type": "asyncapi", "spec_path": "<relative path to spec file>" }` for each spec file found

### Requirement: Evidence field format
Each architectural pattern entry SHALL include an `evidence` field (or pattern-specific equivalent such as `spec_path`) referencing concrete file locations, file:line pairs, or configuration keys that justify the detection. Evidence SHALL be a non-empty list (or non-empty string for `spec_path`).

#### Scenario: Empty evidence rejected
- **WHEN** detection logic produces a candidate pattern entry with empty evidence
- **THEN** the system SHALL NOT emit the entry; absence of evidence means absence of detection

### Requirement: Detection runs in both workspace and single-repo modes
Architectural pattern detection SHALL run regardless of workspace/single-repo classification, with the exception of the BFF pattern which requires workspace context.

#### Scenario: Single-repo pattern detection
- **WHEN** `claudboard-analyse` runs on a single-repo project
- **THEN** the system SHALL detect saga, CQRS, outbox, API composition, circuit breaker, schema registry, and AsyncAPI patterns and emit the Architectural Patterns subsection

#### Scenario: Workspace mode includes BFF
- **WHEN** `claudboard-analyse` runs in workspace mode
- **THEN** the system SHALL additionally detect BFF services across the workspace
