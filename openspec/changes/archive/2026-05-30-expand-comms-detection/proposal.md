## Why

claudboard's microservice communication detection is Bosch-shaped: Feign, Kafka, and Solace get full edge extraction because the dogfood repos (craftsphere, MEAS) use exactly those. Everything else is either label-only (RabbitMQ, SNS/SQS in `pattern-catalog.md`) or absent entirely (WebSocket, GraphQL, tRPC, JMS, Service Bus, RSocket, SSE, MQTT, Redis pub/sub, kafkajs, amqplib, Apollo, React Query, ...). The result: workspace dependency graphs silently drop edges that exist in real codebases, and generated `feature-workflow` skills miss capability blocks for transports the team actually uses. Architectural patterns (saga, CQRS, outbox, BFF, circuit breaker, schema registry) are not detected at all.

## What Changes

- **Restructure** `skills/claudboard/references/workflow-signals.md` from a flat catalog into a dispatcher + focused sub-catalogs: `edges/sync-rpc.md`, `edges/messaging.md`, `edges/streaming.md`, `edges/graphql.md`, `patterns/architectural.md`.
- **BREAKING (schema, additive-compatible):** Cross-service edge schema gains structured fields. Old: `{type, target}`. New: `{family, protocol, direction, target, schema_ref}`. Consumers reading the old `type` field continue to work — `type` is treated as a coarse synonym for `protocol`.
- **Java/Spring transport additions** (edge extraction, workspace mode):
  - sync-rpc: OkHttp, Apache HttpClient
  - messaging: Spring AMQP (`@RabbitListener`, `RabbitTemplate`), Spring JMS (`@JmsListener`, `JmsTemplate`), AWS SDK SNS/SQS, Azure Service Bus, Google Pub/Sub
  - streaming: Spring WebSocket/STOMP, `SseEmitter`, WebFlux SSE, RSocket
  - graphql: spring-graphql, Netflix DGS
- **TypeScript/React/Node transport additions** (edge extraction, workspace mode):
  - sync-rpc: ky, undici, React Query, SWR, RTK Query, tRPC, grpc-web, Connect-RPC, ts-proto
  - messaging: kafkajs, amqplib, mqtt.js, ioredis/redis pub/sub, AWS SDK v3 SNS/SQS, `@nestjs/microservices` transports
  - streaming: native WebSocket, socket.io, EventSource (SSE)
  - graphql: Apollo Client, urql, graphql-request, Relay
  - inbound surface: Express, Fastify, NestJS route handlers
- **Architectural pattern detection** (new analysis output block `architectural_patterns`): saga (orchestration|choreography), CQRS, outbox, BFF, API composition, circuit breaker (resilience4j|hystrix|opossum), schema registry (Confluent|Apicurio), AsyncAPI spec presence.
- **`claudboard-workflow` capability blocks** — add: `RABBITMQ`, `JMS`, `GRAPHQL`, `WEBSOCKET`, `SAGA`, `CQRS`, `OUTBOX`, `CIRCUIT_BREAKER`. Each requires `block-catalog.md` entry + template wrap points in `architect-agent.md.template` and `implementation-agent.md.template`.
- **`claudboard-techdebt` new debt items** — missing circuit breaker on outbound HTTP/gRPC, missing outbox on dual-write (DB + message broker in same transaction), missing schema registry with Kafka.
- **Backward compatibility** — reports without the new schema sections continue to be parseable; consumers emit the existing "limited workflow signals available" warning and default missing blocks off.

## Capabilities

### New Capabilities
- `architectural-patterns-detection`: Detects architectural patterns (saga, CQRS, outbox, BFF, API composition, circuit breaker, schema registry, AsyncAPI) during analysis and emits an `architectural_patterns` block in the report. Workspace + single-repo. Feeds `feature-workflow` capability blocks and `techdebt-scanner` debt items.

### Modified Capabilities
- `workflow-signals-detection`: Cross-service edge schema gains `family`, `protocol`, `direction`, `schema_ref` fields. Detection catalog restructured from a single flat file into family-grouped sub-catalogs. Old `type`-only consumers remain compatible.
- `cross-service-graph`: Outbound/inbound surface extraction extended to the full Java/Spring + TS/Node transport catalog listed under "What Changes". Solace remains supported. Identity matching extended to cover the new protocols.
- `feature-workflow-generation`: New capability flags resolved from analysis report (`RABBITMQ`, `JMS`, `GRAPHQL`, `WEBSOCKET`, `SAGA`, `CQRS`, `OUTBOX`, `CIRCUIT_BREAKER`). Each gated block in `architect-agent.md.template` and `implementation-agent.md.template` activates when the corresponding signal is present.
- `techdebt-scanner`: New debt categories — missing circuit breaker on outbound calls, missing outbox on dual-write, missing schema registry with Kafka producers/consumers.

## Impact

- **Files restructured:** `skills/claudboard/references/workflow-signals.md` split into 6 files (1 dispatcher + 5 sub-catalogs).
- **Files extended:** `skills/claudboard/references/stack-detectors.md` (Cross-Service Surface Detection section delegates to the new sub-catalogs), `skills/claudboard-workflow/references/block-catalog.md` (new flags), `skills/claudboard-workflow/references/substitution-catalog.md` (new edge-type joiners), `skills/claudboard-workflow/references/feature-workflow.template/agents/architect-agent.md.template` and `implementation-agent.md.template` (new wrap points), `skills/claudboard-techdebt/references/` (new debt-pattern entries).
- **Report consumers:** `claudboard-generate`, `claudboard-refresh`, `claudboard-workflow`, `claudboard-techdebt` continue to parse old reports (backward-compatible defaults). Only `claudboard-workflow` and the new architectural-patterns flow read the new sections.
- **Out of scope (explicit):**
  - Kubernetes/Helm/CRD parsing
  - Single-repo cross-service edge extraction (workspace-only)
  - New transports for Go, Python, Rust, .NET (unchanged from today)
- **No version bump implied by this proposal alone** — the change is additive at the report-schema level. A minor bump is appropriate when merged.
