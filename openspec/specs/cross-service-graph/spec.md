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

---

## Requirements (expand-comms-detection additions)

### Requirement: Extended outbound and inbound surface coverage
The per-repo surface extraction SHALL cover the full set of protocols listed in the workflow-signals-detection "Cross-service edge inventory" requirement, organised by family.

**Outbound surface (Java/Spring additions):** OkHttp client URLs, Apache HttpClient URLs, `@RabbitListener` peer publishers (`RabbitTemplate.convertAndSend`), `JmsTemplate.send`, AWS SDK `SnsClient.publish`/`SqsClient.sendMessage`, Azure `ServiceBusSenderClient.sendMessage`, Google `Publisher.publish`, Spring WebSocket outbound channels, RSocket request channels, GraphQL clients (`HttpGraphQlClient`).

**Outbound surface (TypeScript/Node additions):** ky/undici/got URL patterns, React Query `queryFn` URL extraction, SWR `fetcher` URL extraction, RTK Query `endpoints` URL extraction, Apollo Client `uri` config, urql `url` config, `graphql-request` endpoint URL, tRPC `httpBatchLink({url})`, grpc-web `Client(<host>)`, Connect-RPC `createPromiseClient`, kafkajs `producer.send({topic})`, amqplib `channel.publish/sendToQueue`, `mqtt.connect(url).publish(topic)`, ioredis/redis `publisher.publish(channel)`, AWS SDK v3 SNS/SQS clients, `@nestjs/microservices` `ClientProxy.emit/send`.

**Inbound surface (Java/Spring additions):** `@RabbitListener`, `@JmsListener`, `@MessageMapping` / `@SubscribeMapping` (WebSocket/STOMP), `SseEmitter` endpoint methods, `@QueryMapping` / `@MutationMapping` / `@DgsQuery` / `@DgsMutation` (GraphQL), RSocket `@MessageMapping`.

**Inbound surface (TypeScript/Node additions):** Express `app.<method>(path, ...)`, Fastify `fastify.<method>(path, ...)`, NestJS `@Controller` + `@Get/@Post/...`, native `WebSocketServer` `on("connection", ...)`, socket.io `io.on("connection", ...)`, Apollo Server `typeDefs` query/mutation names, `@MessagePattern` / `@EventPattern` (`@nestjs/microservices`).

#### Scenario: RabbitMQ producer/consumer pair matched
- **WHEN** order-service contains `rabbitTemplate.convertAndSend("orders.exchange", "order.created", payload)` AND notification-service contains `@RabbitListener(queues = "order.notifications")` bound to the same exchange/routing-key
- **THEN** the graph SHALL contain edge: order-service ──RabbitMQ──▶ notification-service

#### Scenario: kafkajs producer/consumer pair matched
- **WHEN** one Node service contains `producer.send({ topic: "order.created", messages: [...] })` AND another contains `consumer.subscribe({ topic: "order.created" })`
- **THEN** the graph SHALL contain edge: producer ──Kafka──▶ consumer

#### Scenario: tRPC client/server pair matched
- **WHEN** a Node service exposes a tRPC router with a procedure `getOrders` AND a frontend or sibling service calls `trpc.getOrders.useQuery()` against that router's base URL
- **THEN** the graph SHALL contain edge: client ──tRPC──▶ server

#### Scenario: GraphQL client/server pair matched
- **WHEN** one service exposes a GraphQL schema via `spring-graphql` or Apollo Server AND another service issues a query against that server's URL via Apollo Client, urql, or `graphql-request`
- **THEN** the graph SHALL contain edge: client ──GraphQL──▶ server

#### Scenario: WebSocket producer/consumer pair matched
- **WHEN** one service exposes a `@MessageMapping("/topic/orders")` endpoint AND another connects to that endpoint via STOMP or native WebSocket
- **THEN** the graph SHALL contain edge: client ──WebSocket──▶ server

### Requirement: Schema reference linking
When an outbound edge has a known schema artifact (OpenAPI spec at the target, `.proto` file referenced by the gRPC client, AsyncAPI spec for the topic, or Avro `.avsc` for Kafka), the system SHALL link the spec to the edge via the `schema_ref` field.

#### Scenario: OpenAPI spec linked to REST edge
- **WHEN** a target service has `openapi.yaml` or `api/openapi.yaml` in its source tree AND the caller has an outbound REST edge to that service
- **THEN** the edge's `schema_ref` field SHALL be set to the relative path of the OpenAPI spec

#### Scenario: Proto file linked to gRPC edge
- **WHEN** an outbound gRPC edge's caller imports types from a `*.proto` file
- **THEN** the edge's `schema_ref` field SHALL be set to the relative path of the proto file

#### Scenario: AsyncAPI spec linked to messaging edge
- **WHEN** the workspace contains an `asyncapi.yaml` spec that documents a topic AND that topic appears as a target in a messaging edge
- **THEN** the edge's `schema_ref` field SHALL be set to the relative path of the AsyncAPI spec

### Requirement: Family-aware coupling classification
Coupling strength classification SHALL be extended to cover the new protocol families:

| Family | Protocol | Strength | Condition |
|--------|----------|----------|-----------|
| sync-rpc | any | TIGHT | No retry or circuit breaker config detected on the caller |
| sync-rpc | any | MODERATE | Retry or circuit breaker detected (resilience4j, Spring Retry, opossum) |
| messaging | Kafka, RabbitMQ, JMS, MQTT, SNS/SQS, Service Bus, Pub/Sub, Solace, kafkajs, amqplib, mqtt.js, ioredis pub/sub | LOOSE | Always |
| streaming | WebSocket, SSE, RSocket | TIGHT | Persistent connection — failure propagates immediately |
| graphql | any | TIGHT | No retry / circuit breaker (same as sync-rpc) |
| graphql | any | MODERATE | Retry or circuit breaker detected |
| Shared DB | n/a | TIGHT | Same DB connection string in multiple repos |

#### Scenario: Streaming edge flagged as TIGHT
- **WHEN** an edge has `family: "streaming"`
- **THEN** the edge SHALL be classified TIGHT and flagged: "Persistent connection — disconnects cascade immediately to dependent services"

#### Scenario: GraphQL edge with circuit breaker flagged MODERATE
- **WHEN** an edge has `family: "graphql"` AND the caller has a detected circuit-breaker pattern
- **THEN** the edge SHALL be classified MODERATE
