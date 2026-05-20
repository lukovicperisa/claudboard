## 1. Restructure detection catalog (no behavior change)

- [x] 1.1 Create `skills/claudboard/references/edges/` and `skills/claudboard/references/patterns/` directories
- [x] 1.2 Create `edges/sync-rpc.md` with the existing Feign, RestTemplate, WebClient, RestClient, axios, fetch, requests, grpc-java entries moved verbatim from `workflow-signals.md` and `stack-detectors.md → Cross-Service Surface Detection`
- [x] 1.3 Create `edges/messaging.md` with the existing Kafka, Solace SCS, Solace JCSMP entries moved verbatim
- [x] 1.4 Create `edges/streaming.md` (empty section headers ready for new entries)
- [x] 1.5 Create `edges/graphql.md` (empty section headers ready for new entries)
- [x] 1.6 Create `patterns/architectural.md` (empty section headers ready for detection entries)
- [x] 1.7 Rewrite `workflow-signals.md` as a thin dispatcher: schema definition + pointers to the new sub-catalogs. Remove all transport-specific grep commands.
- [x] 1.8 Replace the "Cross-Service Surface Detection" section in `stack-detectors.md` with a single pointer to `workflow-signals.md` and `edges/*.md` (single source of truth).
- [ ] 1.9 Run `/analyse` against `craftsphere.cloud` and confirm output is byte-identical to pre-restructure (only structural file moves so far).

## 2. Extend edge schema (additive, backward-compatible)

- [x] 2.1 Update `workflow-signals.md` schema definition to include `family`, `protocol`, `direction`, `schema_ref` fields with documented defaults
- [x] 2.2 Document the `type` ↔ `protocol` backward-compat synonym rule explicitly
- [x] 2.3 Update every existing entry in `edges/sync-rpc.md` and `edges/messaging.md` to emit all six fields (family, protocol, type, direction, target, schema_ref) in their example outputs
- [x] 2.4 Add schema_ref discovery rule: when an `openapi.yaml`, `*.proto`, `asyncapi.yaml`, or `*.avsc` file co-locates with a transport entry, capture relative path
- [ ] 2.5 Run `/analyse` against craftsphere and verify reports contain new fields while old `type` field still appears

## 3. Add Java/Spring transport entries

- [x] 3.1 `edges/sync-rpc.md`: add OkHttp client URL extraction (grep `OkHttpClient` + `Request.Builder().url(...)`)
- [x] 3.2 `edges/sync-rpc.md`: add Apache HttpClient URL extraction (grep `HttpClients.createDefault` / `CloseableHttpClient` + URI literals)
- [x] 3.3 `edges/messaging.md`: add Spring AMQP entries — `@RabbitListener(queues=...)` (inbound), `RabbitTemplate.convertAndSend(exchange, routingKey, ...)` (outbound)
- [x] 3.4 `edges/messaging.md`: add Spring JMS entries — `@JmsListener(destination=...)` (inbound), `JmsTemplate.send(destination, ...)` (outbound)
- [x] 3.5 `edges/messaging.md`: add AWS SDK SNS/SQS — `SnsClient.publish(PublishRequest.builder().topicArn(...))`, `SqsClient.sendMessage(SendMessageRequest.builder().queueUrl(...))`
- [x] 3.6 `edges/messaging.md`: add Azure Service Bus — `ServiceBusSenderClient.sendMessage(...)` with topic/queue config
- [x] 3.7 `edges/messaging.md`: add Google Pub/Sub — `Publisher.newBuilder(TopicName.of(...))`
- [x] 3.8 `edges/streaming.md`: add Spring WebSocket/STOMP — `@MessageMapping`, `@SubscribeMapping`, registry `addEndpoint(...)`
- [x] 3.9 `edges/streaming.md`: add `SseEmitter` and WebFlux SSE (`Flux<ServerSentEvent>` return type with `MediaType.TEXT_EVENT_STREAM`)
- [x] 3.10 `edges/streaming.md`: add RSocket — `@MessageMapping` with `spring-boot-starter-rsocket`, `RSocketRequester.builder()` for outbound
- [x] 3.11 `edges/graphql.md`: add spring-graphql — `@QueryMapping`, `@MutationMapping`, `@SubscriptionMapping`, `HttpGraphQlClient.builder().url(...)` for outbound
- [x] 3.12 `edges/graphql.md`: add Netflix DGS — `@DgsQuery`, `@DgsMutation`, `@DgsSubscription`

## 4. Add TypeScript/React/Node transport entries

- [x] 4.1 `edges/sync-rpc.md`: add ky (`ky.extend({prefixUrl})`, `ky.get/post/put/delete`)
- [x] 4.2 `edges/sync-rpc.md`: add undici (`new Pool(url)`, `request(url, ...)`)
- [x] 4.3 `edges/sync-rpc.md`: add React Query — extract `queryFn` URL literals inside `useQuery`/`useMutation`/`useInfiniteQuery`
- [x] 4.4 `edges/sync-rpc.md`: add SWR — extract `fetcher` URL argument or first argument of `useSWR(url, ...)`
- [x] 4.5 `edges/sync-rpc.md`: add RTK Query — extract `baseQuery.baseUrl` and per-endpoint `query: ({...}) => '/path'`
- [x] 4.6 `edges/sync-rpc.md`: add tRPC — `createTRPCClient`/`createTRPCProxyClient`, `httpBatchLink({url})`
- [x] 4.7 `edges/sync-rpc.md`: add grpc-web — `new ServiceClient(<host>)`, `createGrpcWebTransport({baseUrl})`
- [x] 4.8 `edges/sync-rpc.md`: add Connect-RPC — `createPromiseClient(Service, transport)` with `baseUrl`
- [x] 4.9 `edges/sync-rpc.md`: add ts-proto generated clients (grep generated `_*ServiceClient` classes referencing host config)
- [x] 4.10 `edges/sync-rpc.md`: add inbound — Express (`app.<method>(path, ...)`, `router.<method>(...)`)
- [x] 4.11 `edges/sync-rpc.md`: add inbound — Fastify (`fastify.<method>(path, ...)`, `fastify.route({method, url})`)
- [x] 4.12 `edges/sync-rpc.md`: add inbound — NestJS (`@Controller`, `@Get/@Post/@Put/@Delete/@Patch`)
- [x] 4.13 `edges/messaging.md`: add kafkajs — `producer.send({topic})`, `consumer.subscribe({topic})`
- [x] 4.14 `edges/messaging.md`: add amqplib — `channel.publish(exchange, routingKey)`, `channel.sendToQueue(queue)`, `channel.consume(queue)`
- [x] 4.15 `edges/messaging.md`: add mqtt.js — `mqtt.connect(url)`, `client.publish(topic)`, `client.subscribe(topic)`
- [x] 4.16 `edges/messaging.md`: add Redis pub/sub — ioredis/redis `publisher.publish(channel)`, `subscriber.subscribe(channel)`
- [x] 4.17 `edges/messaging.md`: add AWS SDK v3 — `SNSClient.send(new PublishCommand({...}))`, `SQSClient.send(new SendMessageCommand({...}))`
- [x] 4.18 `edges/messaging.md`: add `@nestjs/microservices` — `ClientProxy.emit/send`, `@MessagePattern`, `@EventPattern`
- [x] 4.19 `edges/streaming.md`: add native WebSocket — `new WebSocket(url)` (client), `new WebSocketServer({port})` + `wss.on("connection", ...)` (server)
- [x] 4.20 `edges/streaming.md`: add socket.io — `io(url)` (client), `new Server(httpServer)` + `io.on("connection")` + `socket.on(event)` (server)
- [x] 4.21 `edges/streaming.md`: add EventSource (SSE) — `new EventSource(url)` (client), Express/Fastify route returning `text/event-stream` (server)
- [x] 4.22 `edges/graphql.md`: add Apollo Client — `new ApolloClient({uri})`, `useQuery(QUERY)`
- [x] 4.23 `edges/graphql.md`: add urql — `createClient({url})`, `useQuery({query})`
- [x] 4.24 `edges/graphql.md`: add graphql-request — `new GraphQLClient(endpoint)`, `request(endpoint, query)`
- [x] 4.25 `edges/graphql.md`: add Relay — `Environment` config with `fetchQuery({url})` or network layer URL
- [x] 4.26 `edges/graphql.md`: add Apollo Server inbound — `typeDefs` query/mutation names, `new ApolloServer({typeDefs, resolvers})`

## 5. Architectural pattern detection (`patterns/architectural.md`)

- [x] 5.1 Document the `architectural_patterns` output schema (type, evidence, pattern-specific fields)
- [x] 5.2 Add Saga detection — orchestration (Camunda/Zeebe/Spring State Machine/Temporal SDK + orchestrator class with 3+ downstream calls) and choreography (paired `*.Completed`/`*.Failed` event names across services)
- [x] 5.3 Add CQRS detection — parallel `command/`+`query/` packages with ≥2 classes each, OR Axon Framework `@CommandHandler` + `@QueryHandler`
- [x] 5.4 Add Outbox detection — `CREATE TABLE outbox*` in Flyway/Liquibase/Alembic/Knex migrations, OR `transactional-outbox`/Debezium/`eventuate-tram` dependency
- [x] 5.5 Add BFF detection (workspace-only) — controllers + outbound calls to 2+ siblings + no `@Entity`/`@Document` annotations; Next.js `app/api/`/`pages/api/` calling 2+ siblings
- [x] 5.6 Add API Composition detection — single controller method with 2+ outbound HTTP calls combining results
- [x] 5.7 Add Circuit Breaker detection — `@CircuitBreaker`/`@Retry`/`@Bulkhead` (resilience4j), `@HystrixCommand`, `opossum` dep
- [x] 5.8 Add Schema Registry detection — `schema.registry.url` config, `kafka-avro-serializer`, `apicurio-registry-serdes-*`, `@kafkajs/confluent-schema-registry`
- [x] 5.9 Add AsyncAPI detection — find `asyncapi.{yml,yaml,json}` and `**/*.asyncapi.{yml,yaml,json}` excluding `node_modules`/`target`/`dist`/`build`
- [x] 5.10 Document per-pattern minimum-signal thresholds and the "empty evidence → no entry" rule
- [ ] 5.11 Update `claudboard-analyse/SKILL.md` to invoke `patterns/architectural.md` during Phase 1c and emit the "## Architectural Patterns" subsection in single-repo and workspace modes (BFF gated on workspace)
- [ ] 5.12 Update monorepo and workspace report templates so per-service reports include their own "## Architectural Patterns" subsection

## 6. Wire new capability flags into claudboard-workflow

- [ ] 6.1 Add `RABBITMQ` entry to `skills/claudboard-workflow/references/block-catalog.md` (resolution rule, default, template wrap points, removal behavior)
- [ ] 6.2 Add `JMS` entry to `block-catalog.md`
- [ ] 6.3 Add `GRAPHQL` entry to `block-catalog.md`
- [ ] 6.4 Add `WEBSOCKET` entry to `block-catalog.md` (covers websocket/stomp/socket-io/rsocket)
- [ ] 6.5 Add `SAGA` entry to `block-catalog.md` (note style sub-resolution: orchestration vs choreography variants)
- [ ] 6.6 Add `CQRS` entry to `block-catalog.md`
- [ ] 6.7 Add `OUTBOX` entry to `block-catalog.md`
- [ ] 6.8 Add `CIRCUIT_BREAKER` entry to `block-catalog.md`
- [ ] 6.9 Add `<!-- IF RABBITMQ -->` wrap with RabbitMQ design guidance (exchange/queue/routing-key design, DLQ, idempotency) in `feature-workflow.template/agents/architect-agent.md.template`
- [ ] 6.10 Add `<!-- IF JMS -->` wrap with JMS design guidance in `architect-agent.md.template`
- [ ] 6.11 Add `<!-- IF GRAPHQL -->` wrap with GraphQL guidance (schema-first vs code-first, N+1 via DataLoader, versioning) in `architect-agent.md.template`
- [ ] 6.12 Add `<!-- IF WEBSOCKET -->` wrap with streaming guidance (connection lifecycle, backpressure, reconnect) in `architect-agent.md.template`
- [ ] 6.13 Add `<!-- IF SAGA -->` wrap with saga design guidance (compensation, idempotency keys, orchestration vs choreography callout) in `architect-agent.md.template`
- [ ] 6.14 Add `<!-- IF CQRS -->` wrap with CQRS guidance (read/write model separation, projection updates) in `architect-agent.md.template`
- [ ] 6.15 Add `<!-- IF OUTBOX -->` wrap in `implementation-agent.md.template` (transactional write to outbox + entity, polling/CDC, no direct broker send from `@Transactional`)
- [ ] 6.16 Add `<!-- IF CIRCUIT_BREAKER -->` wrap in `implementation-agent.md.template` (wrap new outbound calls with the detected library)
- [ ] 6.17 Update `claudboard-workflow/SKILL.md` flag-resolution section to enumerate the new flags and their source fields
- [ ] 6.18 Update `substitution-catalog.md` if any new `{{VAR}}` tokens are introduced for the new flags

## 7. Wire new techdebt categories

- [x] 7.1 Create `skills/claudboard-techdebt/references/arch-pattern-gaps.md` documenting the three gap detection rules, severity assignment, and fix suggestions
- [x] 7.2 Add missing-circuit-breaker detection — service has outbound sync-rpc/graphql edges AND no `circuit-breaker` entry
- [x] 7.3 Add missing-outbox detection — `@Transactional` method with both repository write AND broker send AND no `outbox` entry
- [x] 7.4 Add missing-schema-registry detection — service has Kafka edges AND no `schema-registry` entry
- [x] 7.5 Update `claudboard-techdebt/SKILL.md` to load `arch-pattern-gaps.md` and emit findings under a new "Architectural Pattern Gaps" heading
- [x] 7.6 Update `report-template.md` to include the new heading in the techdebt report structure
- [x] 7.7 Implement the "Architectural Patterns subsection absent → warn and suppress gap findings" backward-compat behavior

## 8. Backward-compatibility verification

- [ ] 8.1 Generate a synthetic old-schema analysis report (edges with only `type`+`target`, no `architectural_patterns` subsection)
- [ ] 8.2 Run `claudboard-workflow` against the old-schema report and verify it warns and proceeds with new flags defaulted to false
- [ ] 8.3 Run `claudboard-techdebt` against the old-schema report and verify it warns and suppresses architectural-pattern-gap findings
- [ ] 8.4 Run `claudboard-generate` against an old-schema report and verify it is unaffected (does not read the new sections)
- [ ] 8.5 Run `claudboard-refresh` against an old-schema report and verify it is unaffected

## 9. Real-project validation

- [ ] 9.1 Run `/analyse` on craftsphere.cloud (Java/Spring/React monorepo): verify expanded edges include RabbitMQ if present, GraphQL if present; verify architectural_patterns surfaces circuit-breaker if resilience4j is used
- [ ] 9.2 Run `/analyse` on the MEAS workspace (multi-repo Java + Solace): verify Solace detection is unchanged, edge schema upgrade present, BFF detection works if a frontend-aggregator service exists
- [ ] 9.3 Run `/analyse` on a TypeScript-heavy reference repo (e.g., a Next.js + NestJS project): verify Express/Fastify/NestJS inbound routes, axios + React Query outbound, Apollo Client and tRPC detection
- [ ] 9.4 Run `/claudboard-workflow` against a project where new flags resolve true and verify generated `feature-workflow/` contains the wrapped guidance blocks
- [ ] 9.5 Run `/techdebt` against a project with outbound REST and no circuit breaker; verify a missing-circuit-breaker item appears under "Architectural Pattern Gaps"

## 10. Documentation and skill metadata

- [x] 10.1 Update root `CLAUDE.md` "Skill Anatomy" section to reflect the new `edges/` and `patterns/` subdirectories under `skills/claudboard/references/`
- [x] 10.2 Update `skills/claudboard/SKILL.md` (dispatcher) if it references the old flat detection file
- [x] 10.3 Bump plugin version per repo convention (next minor)
