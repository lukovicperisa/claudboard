## ADDED Requirements

### Requirement: Observability stack detection
The scanner SHALL detect observability tooling by checking dependencies for: `spring-boot-starter-actuator`, `micrometer-core`, `micrometer-tracing`, `spring-cloud-sleuth`, `logstash-logback-encoder`, `io.opentelemetry`.

#### Scenario: Actuator detected
- **WHEN** `spring-boot-starter-actuator` found in dependencies
- **THEN** report records "Spring Actuator: present" and checks for `management.endpoints` config in application properties

#### Scenario: Metrics library detected
- **WHEN** `micrometer-core` or `@Timed` annotations found
- **THEN** report records "Metrics: Micrometer" with annotation count

#### Scenario: Distributed tracing detected
- **WHEN** `micrometer-tracing` or `spring-cloud-sleuth` or `io.opentelemetry` found
- **THEN** report records tracing library name

#### Scenario: No observability tooling
- **WHEN** no observability dependencies found in a service with REST endpoints
- **THEN** report flags "No observability tooling detected" as MEDIUM severity

### Requirement: Observability quality dimension
The scanner SHALL add an "Observability" dimension to quality scoring: Good (actuator + metrics + tracing), Acceptable (actuator only or metrics only), Debt (nothing).

#### Scenario: Full observability stack
- **WHEN** actuator AND metrics AND tracing all detected
- **THEN** Observability dimension scores "Good"

#### Scenario: Partial observability
- **WHEN** only actuator or only metrics detected
- **THEN** Observability dimension scores "Acceptable"

### Requirement: Structured logging detection
The scanner SHALL check for structured logging by grepping for `logstash-logback-encoder` dependency or `net.logstash.logback` imports.

#### Scenario: Structured logging found
- **WHEN** logstash encoder dependency or JSON layout config found
- **THEN** report records "Structured logging: yes"
