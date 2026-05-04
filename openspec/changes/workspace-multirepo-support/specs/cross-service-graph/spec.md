## ADDED Requirements

### Requirement: Extract outbound and inbound surfaces per repo
During per-repo analysis (Phase 1b), the system SHALL extract each repo's communication surface in addition to the standard analysis.

**Outbound surface** (what this repo calls):
- REST: `@FeignClient(name=...)`, `RestTemplate` URL patterns, `WebClient` base URLs, Axios/fetch with service name in URL
- Kafka: `KafkaTemplate.send("topic-name", ...)`, `@SendTo("topic-name")`
- Solace Spring Cloud Stream: `spring.cloud.stream.bindings.{channel}.destination` values from config
- Solace JCSMP: `Topic.of("topic-name")` and `Queue.get("queue-name")` literals in producer code

**Inbound surface** (what this repo exposes):
- REST: `@RestController` endpoint paths, `spring.application.name` (service identity)
- Kafka: `@KafkaListener(topics = "topic-name")` values
- Solace Spring Cloud Stream: `@StreamListener` binding destinations
- Solace JCSMP: `XMLMessageConsumer.addSubscription(Topic.of("topic-name"))` values

#### Scenario: FeignClient extraction
- **WHEN** a repo contains `@FeignClient(name = "user-service")`
- **THEN** the system SHALL record an outbound REST reference with target identity "user-service"

#### Scenario: Kafka topic extraction
- **WHEN** a repo contains `KafkaTemplate.send("order.created", payload)` in one service AND `@KafkaListener(topics = "order.created")` in another
- **THEN** the system SHALL record both: producer topic "order.created" in service A, consumer topic "order.created" in service B

#### Scenario: Solace JCSMP topic as constant
- **WHEN** a Solace topic is defined as a constant (`static final String TOPIC = "order/created"`) and used in `Topic.of(TOPIC)`
- **THEN** the system SHALL grep for the constant definition and resolve the literal value

#### Scenario: Solace Spring Cloud Stream config extraction
- **WHEN** `application.yml` contains `spring.cloud.stream.bindings.orderOut.destination: order/created`
- **THEN** the system SHALL record "order/created" as a producer topic for the channel bound to an `@Output` or `StreamBridge`

### Requirement: Resolve service identity for dependency matching
The system SHALL resolve each repo's identity using `spring.application.name` from `application.yml` or `application.properties` if present, falling back to the directory name.

#### Scenario: Identity from spring.application.name
- **WHEN** `application.yml` contains `spring.application.name: user-service`
- **THEN** the service identity SHALL be "user-service"

#### Scenario: Identity from directory name
- **WHEN** no `spring.application.name` is found in config
- **THEN** the service identity SHALL be the directory name of the repo

### Requirement: Build directed dependency graph
After all per-repo surfaces are extracted, the system SHALL build a directed dependency graph by matching outbound references against repo identities and inbound surfaces.

**Matching rules:**
- REST: outbound FeignClient name or URL segment matches target repo's identity → edge
- Kafka: outbound producer topic matches inbound consumer topic (exact string) → edge
- Solace: same as Kafka — producer destination matches consumer subscription (exact string) → edge
- Unresolved: outbound reference matches no known repo identity → record as "external (unresolved)"

#### Scenario: REST dependency resolved
- **WHEN** order-service has `@FeignClient(name = "user-service")` AND user-service identity is "user-service"
- **THEN** the graph SHALL contain edge: order-service ──REST──▶ user-service

#### Scenario: Kafka dependency resolved
- **WHEN** order-service publishes to "order.created" AND notification-service consumes "order.created"
- **THEN** the graph SHALL contain edge: order-service ──Kafka──▶ notification-service

#### Scenario: Unresolved external dependency
- **WHEN** order-service has a FeignClient targeting "payment-gateway" AND no sibling repo has that identity
- **THEN** the graph SHALL record: order-service → "payment-gateway" (external, unresolved)

#### Scenario: Circular dependency detected
- **WHEN** order-service depends on user-service AND user-service depends on order-service
- **THEN** the graph SHALL flag: "Circular dependency: order-service ↔ user-service — architectural risk"

### Requirement: Classify coupling strength per edge
Each dependency edge SHALL be classified by coupling strength.

| Type | Strength | Condition |
|------|----------|-----------|
| REST | TIGHT | No retry or circuit breaker config detected |
| REST | MODERATE | Retry or circuit breaker detected (Resilience4j, Spring Retry) |
| Kafka/Solace async | LOOSE | Always |
| Shared DB | TIGHT | Same DB connection string in multiple repos |

#### Scenario: Tight REST coupling flagged
- **WHEN** an edge is REST and no `@CircuitBreaker`, `@Retry`, or Resilience4j config is detected in the calling service
- **THEN** the edge SHALL be classified TIGHT and flagged: "Synchronous call with no resilience pattern — if [target] is unavailable, [source] fails"

#### Scenario: Synchronous chain detected
- **WHEN** A →(REST/TIGHT)→ B →(REST/TIGHT)→ C
- **THEN** the graph SHALL flag: "Synchronous chain A→B→C — latency amplifies and failure cascades"

### Requirement: Present graph before injection
The system SHALL present the full dependency graph to the user before writing any ecosystem files, to allow correction of mismatches.

#### Scenario: Graph presented for review
- **WHEN** graph construction is complete
- **THEN** the system SHALL display the dependency graph with edges, coupling classifications, and any warnings, then ask: "Proceed with ecosystem injection? [y/n/edit]"
