## MODIFIED Requirements

### Requirement: Cross-service edge inventory
The system SHALL detect outgoing cross-service edges using a structured schema that captures protocol family, specific protocol, direction, target, and an optional schema reference. Detected protocols include the synchronous-RPC family (Feign, RestTemplate, WebClient, RestClient, OkHttp, Apache HttpClient, axios, fetch, ky, undici, React Query, SWR, RTK Query, Apollo, tRPC, grpc-java, grpc-web, Connect-RPC, ts-proto, Python requests), the messaging family (Kafka, kafkajs, Spring AMQP/RabbitMQ, amqplib, Spring JMS, AWS SDK SNS/SQS, Azure Service Bus, Google Pub/Sub, MQTT, Redis pub/sub, Solace SCS, Solace JCSMP, `@nestjs/microservices` transports), the streaming family (Spring WebSocket/STOMP, native WebSocket, socket.io, `SseEmitter`, WebFlux SSE, EventSource, RSocket), and the GraphQL family (spring-graphql, Netflix DGS, Apollo Client/Server, urql, graphql-request, Relay).

Each edge entry SHALL conform to the schema:

```yaml
- family: sync-rpc | messaging | streaming | graphql
  protocol: <specific protocol identifier>
  direction: outbound | inbound
  target: <service-name | topic-name | endpoint-pattern | unknown>
  schema_ref: <path to OpenAPI/proto/AsyncAPI/Avro spec | null>
```

For backward compatibility, each emitted edge SHALL also include a `type` field carrying the same value as `protocol`. Consumers reading only the old `type` field SHALL continue to function without modification.

#### Scenario: Feign client detected
- **WHEN** the codebase contains a class annotated with `@FeignClient(name = "user-service")`
- **THEN** the cross-service edges list SHALL include `{ "family": "sync-rpc", "protocol": "feign", "type": "feign", "direction": "outbound", "target": "user-service", "schema_ref": null }`

#### Scenario: Spring RestClient call detected
- **WHEN** the codebase contains a `RestClient.builder()` or `RestTemplate` invocation with a base URL referencing another service
- **THEN** the cross-service edges list SHALL include an entry with `family: "sync-rpc"`, `protocol: "rest-client"` (or `"rest-template"` / `"web-client"` as appropriate), `direction: "outbound"`, and `target` set to the extracted URL or `"unknown"`

#### Scenario: Kafka producer detected
- **WHEN** the codebase contains a `KafkaTemplate.send("order.created", payload)` call or `@SendTo("order.created")` producer
- **THEN** the cross-service edges list SHALL include `{ "family": "messaging", "protocol": "kafka", "type": "kafka", "direction": "outbound", "target": "order.created", "schema_ref": null }`

#### Scenario: Kafka consumer detected
- **WHEN** the codebase contains `@KafkaListener(topics = "order.created")`
- **THEN** the cross-service edges list SHALL include `{ "family": "messaging", "protocol": "kafka", "type": "kafka", "direction": "inbound", "target": "order.created", "schema_ref": null }`

#### Scenario: RabbitMQ listener detected
- **WHEN** the codebase contains `@RabbitListener(queues = "order.queue")`
- **THEN** the cross-service edges list SHALL include `{ "family": "messaging", "protocol": "rabbitmq", "type": "rabbitmq", "direction": "inbound", "target": "order.queue", "schema_ref": null }`

#### Scenario: JMS listener detected
- **WHEN** the codebase contains `@JmsListener(destination = "order.queue")`
- **THEN** the cross-service edges list SHALL include `{ "family": "messaging", "protocol": "jms", "type": "jms", "direction": "inbound", "target": "order.queue", "schema_ref": null }`

#### Scenario: WebSocket endpoint detected
- **WHEN** the codebase contains `@MessageMapping("/topic/orders")` (Spring) or `io.on("connection", ...)` (socket.io)
- **THEN** the cross-service edges list SHALL include an entry with `family: "streaming"`, `protocol: "websocket"` (or `"stomp"` / `"socket-io"` as appropriate), `direction: "inbound"`, and `target` set to the channel/path

#### Scenario: GraphQL resolver detected
- **WHEN** the codebase contains `@QueryMapping` (spring-graphql), `@DgsQuery` (DGS), or a `Query` type definition in `*.graphql` files
- **THEN** the cross-service edges list SHALL include an entry with `family: "graphql"`, `protocol` set to the framework identifier, `direction: "inbound"`, and `target` set to the query/mutation name

#### Scenario: tRPC client detected
- **WHEN** a TypeScript file contains `createTRPCClient` or `createTRPCProxyClient` referencing a router URL
- **THEN** the cross-service edges list SHALL include `{ "family": "sync-rpc", "protocol": "trpc", "type": "trpc", "direction": "outbound", "target": "<router url or unknown>", "schema_ref": null }`

#### Scenario: Schema reference attached
- **WHEN** an edge target has an associated OpenAPI, proto, AsyncAPI, or Avro spec file co-located in the source tree (e.g., `api/openapi.yaml`, `*.proto`, `asyncapi.yaml`, `*.avsc`)
- **THEN** the edge entry's `schema_ref` field SHALL be set to the relative path of that spec file

#### Scenario: No edges detected
- **WHEN** the project contains no detectable cross-service edges
- **THEN** the cross-service edges list SHALL be empty (`[]`) and the subsection SHALL still be present

## ADDED Requirements

### Requirement: Restructured detection catalog
The detection patterns for cross-service edges SHALL be organised into family-grouped reference files under `skills/claudboard/references/`:

- `workflow-signals.md` — schema definition and dispatcher (which sub-catalogs to load when)
- `edges/sync-rpc.md` — synchronous RPC transports (REST clients, gRPC, tRPC, Connect-RPC)
- `edges/messaging.md` — asynchronous messaging transports (Kafka, RabbitMQ, JMS, Solace, MQTT, Redis pub/sub, SNS/SQS, Service Bus, Pub/Sub)
- `edges/streaming.md` — streaming transports (WebSocket, SSE, RSocket)
- `edges/graphql.md` — GraphQL transports

Each sub-catalog entry SHALL document grep commands, extraction rules, target shape, and an edge example, matching the existing per-entry template.

#### Scenario: Sub-catalog file present
- **WHEN** `claudboard-analyse` loads detection patterns for any of the four edge families
- **THEN** the corresponding `edges/<family>.md` reference file SHALL exist and contain entries for every protocol listed under "Cross-service edge inventory"

#### Scenario: Dispatcher integrity
- **WHEN** `workflow-signals.md` is loaded
- **THEN** it SHALL contain explicit pointers to each `edges/*.md` sub-catalog and to `patterns/architectural.md`, with no transport-specific grep commands inlined

### Requirement: Inbound surface emitted as edges with direction=inbound
The system SHALL emit inbound surfaces (HTTP route handlers, queue listeners, GraphQL resolvers, WebSocket endpoints) as edge entries with `direction: "inbound"`, alongside outbound edges, in the same `cross_service_edges` list.

#### Scenario: Inbound REST endpoint emitted
- **WHEN** a Spring service exposes `@RestController` with `@RequestMapping("/api/users")`
- **THEN** the cross-service edges list SHALL include `{ "family": "sync-rpc", "protocol": "rest", "type": "rest", "direction": "inbound", "target": "/api/users", "schema_ref": "<openapi path or null>" }`

#### Scenario: Express route emitted
- **WHEN** a Node service contains `app.get("/api/orders", ...)` or `router.post("/orders", ...)`
- **THEN** the cross-service edges list SHALL include an entry with `family: "sync-rpc"`, `protocol: "rest"`, `direction: "inbound"`, and `target` set to the route path

#### Scenario: Single-repo mode skips edge extraction
- **WHEN** `claudboard-analyse` runs in single-repo mode
- **THEN** the system SHALL NOT emit cross-service edges (workspace-only extraction); architectural patterns SHALL still be emitted per the architectural-patterns-detection capability

### Requirement: Backward-compatible edge schema migration
The expanded edge schema SHALL be additive. Old reports written with the flat `{type, target}` schema SHALL remain readable by all consumers without errors.

#### Scenario: Old report consumed by new consumer
- **WHEN** `claudboard-workflow` reads a report whose edges contain only `type` and `target` fields (no `family`, `protocol`, `direction`, `schema_ref`)
- **THEN** the consumer SHALL treat each edge as `family: "unknown"`, `protocol: <value of type>`, `direction: "outbound"`, `schema_ref: null` and proceed normally

#### Scenario: New report consumed by old consumer
- **WHEN** an unmodified consumer reads a report containing the new schema fields
- **THEN** the consumer SHALL ignore unknown fields and operate on `type` and `target` as before
