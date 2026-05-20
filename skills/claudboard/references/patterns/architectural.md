# Architectural Pattern Detection

Detection rules for system-level architectural patterns. Emitted as an `architectural_patterns` block in the analysis report. Consumed by `claudboard-workflow` (capability flag resolution) and `claudboard-techdebt` (pattern-gap findings).

**Applies to:** single-repo and workspace modes. BFF detection is workspace-only (requires sibling service context).

---

## Output Schema

```yaml
architectural_patterns:
  - {type: saga, style: orchestration, evidence: ["path/to/orchestrator.java:42"]}
  - {type: cqrs, evidence: ["src/main/java/com/example/command/", "src/main/java/com/example/query/"]}
  - {type: outbox, evidence: ["db/migrations/V42__create_outbox.sql"]}
  - {type: bff, evidence: ["src/main/java/com/example/aggregator/BffController.java"]}
  - {type: api-composition, evidence: ["src/main/java/com/example/service/AggregatorService.java:88"]}
  - {type: circuit-breaker, library: resilience4j, evidence: ["src/main/java/com/example/client/OrderClient.java:55"]}
  - {type: schema-registry, vendor: confluent, evidence: ["src/main/resources/application.yml:schema.registry.url"]}
  - {type: asyncapi, spec_path: "docs/asyncapi.yaml"}
```

**Rules:**
- `evidence`: list of file paths (with optional `:line` suffix) that confirm the pattern
- `empty evidence → no entry`: if the minimum-signal threshold is not met, omit the entry entirely
- Pattern-specific fields (`style`, `library`, `vendor`, `spec_path`) are added only when relevant
- When uncertain, **omit rather than mis-label** — false positives are more harmful than missed detections

---

## Minimum-Signal Thresholds

Each pattern requires all signals in its threshold group to be satisfied before emitting an entry. Partial signals → no entry (note as "insufficient evidence" in report if relevant).

---

## Saga

**Style: Orchestration**

Minimum signals (ALL required):
1. Saga orchestration dependency present: Camunda/Zeebe (`camunda-bpm-spring-boot-starter`, `zeebe-spring-boot-starter`), Spring State Machine (`spring-statemachine-core`), or Temporal SDK (`temporal-sdk`)
2. A class named `*Orchestrator*`, `*SagaManager*`, or `*Workflow*` (for Temporal) with 3+ outbound service calls (Feign clients, `KafkaTemplate.send`, `RestTemplate` calls) within methods

```bash
# Signal 1 — dependency
grep -rn 'camunda-bpm-spring-boot-starter\|zeebe-spring-boot-starter\|spring-statemachine-core\|io.temporal' \
  --include='pom.xml' --include='*.gradle' .

# Signal 2 — orchestrator class
grep -rn 'class.*Orchestrator\|class.*SagaManager\|class.*Workflow' \
  --include='*.java' --include='*.kt' src/
```

**Style: Choreography**

Minimum signals (ALL required):
1. Paired event name patterns: at least one `*.Completed` / `*.Failed` pair OR `*Created` / `*Failed` pair across Kafka topic names or message class names
2. At least 2 different services (in workspace mode) or 2 different packages (in single-repo mode) each consuming one event from the paired set

```bash
# Paired event scan — Kafka topic literals
grep -rn 'KafkaTemplate.*send\|@KafkaListener' --include='*.java' --include='*.kt' src/ | \
  grep -i 'completed\|failed\|created\|cancelled\|rejected'

# TS equivalent
grep -rn 'producer\.send\|consumer\.subscribe' --include='*.ts' src/ | \
  grep -i 'completed\|failed\|created\|cancelled\|rejected'
```

**Edge example:**
```yaml
- {type: saga, style: orchestration, evidence: ["src/main/java/com/example/saga/OrderOrchestrator.java:25"]}
- {type: saga, style: choreography, evidence: ["src/main/java/com/example/consumer/OrderCompletedConsumer.java", "src/main/java/com/example/consumer/OrderFailedConsumer.java"]}
```

---

## CQRS

Minimum signals (EITHER group):

**Group A — Package structure:**
1. Parallel `command/` + `query/` packages both exist under the same parent package
2. Each package contains ≥ 2 classes

```bash
# Group A
find src -type d \( -name 'command' -o -name 'commands' -o -name 'query' -o -name 'queries' \) | head -10
```

**Group B — Axon Framework:**
1. `axonframework` dependency present
2. Both `@CommandHandler` and `@QueryHandler` annotations present in source

```bash
# Group B — dependency
grep -rn 'axonframework' --include='pom.xml' --include='*.gradle' .

# Group B — annotations
grep -rn '@CommandHandler\|@QueryHandler' --include='*.java' --include='*.kt' src/
```

**Edge example:**
```yaml
- {type: cqrs, evidence: ["src/main/java/com/example/command/", "src/main/java/com/example/query/"]}
```

---

## Outbox

Minimum signals (EITHER group):

**Group A — Migration script:**
1. A Flyway, Liquibase, Alembic, or Knex migration file contains `CREATE TABLE outbox` (case-insensitive)

```bash
grep -rni 'create table outbox' \
  --include='*.sql' --include='*.xml' --include='*.yaml' --include='*.yml' --include='*.js' --include='*.ts' .
```

**Group B — Dependency:**
1. Any of: `eventuate-tram-spring-events`, `spring-modulith-events-kafka`, Debezium connector (`debezium-connector-*`), `transactional-outbox`

```bash
grep -rn 'eventuate-tram\|spring-modulith-events\|debezium-connector\|transactional-outbox' \
  --include='pom.xml' --include='*.gradle' --include='package.json' .
```

**Edge example:**
```yaml
- {type: outbox, evidence: ["db/migration/V12__create_outbox_table.sql"]}
```

---

## BFF (Backend for Frontend)

**Workspace-only.** Requires sibling service context to determine "calls 2+ siblings."

Minimum signals (ALL required):
1. The repo contains REST controllers OR Next.js `app/api/`/`pages/api/` route files
2. The repo makes outbound REST calls to 2+ sibling repos (resolved via cross-service edges from the workspace dependency graph)
3. The repo does NOT contain `@Entity` or `@Document` annotations (no direct persistence ownership)

```bash
# Signal 1a — Spring controllers
grep -rn '@RestController\|@Controller' --include='*.java' --include='*.kt' src/

# Signal 1b — Next.js API routes
find . -path '*/app/api/*' -name '*.ts' -o -path '*/pages/api/*' -name '*.ts' | head -5

# Signal 3 — no persistence
grep -rn '@Entity\|@Document' --include='*.java' --include='*.kt' src/ | wc -l
```

**Edge example:**
```yaml
- {type: bff, evidence: ["src/main/java/com/example/aggregator/OrderAggregatorController.java"]}
```

---

## API Composition

Minimum signals (ALL required):
1. A single controller method body contains 2+ outbound HTTP calls (RestTemplate, WebClient, FeignClient, fetch, axios)
2. The method combines results from those calls before returning (evidence: multiple variables from calls + return statement using both)

```bash
# Look for methods with multiple restTemplate calls
grep -rn -A 20 '@GetMapping\|@RequestMapping.*GET' --include='*.java' src/ | \
  grep -c 'restTemplate\|webClient\|feignClient'
```

This pattern requires reading candidate method bodies — use grep hits as candidates, then read the method body to confirm 2+ calls with result combination.

**Edge example:**
```yaml
- {type: api-composition, evidence: ["src/main/java/com/example/service/ProductAggregationService.java:88"]}
```

---

## Circuit Breaker

Minimum signals (ANY ONE group):

**Group A — resilience4j:**
```bash
grep -rn '@CircuitBreaker\|@Retry\|@Bulkhead\|@RateLimiter' --include='*.java' --include='*.kt' src/
```

**Group B — Hystrix:**
```bash
grep -rn '@HystrixCommand\|@HystrixCollapser' --include='*.java' --include='*.kt' src/
```

**Group C — opossum (Node.js):**
```bash
grep -rn 'opossum\|CircuitBreaker' --include='*.ts' --include='*.js' --include='package.json' . | \
  grep -v node_modules
```

**Edge example:**
```yaml
- {type: circuit-breaker, library: resilience4j, evidence: ["src/main/java/com/example/client/InventoryClient.java:55"]}
```

Capture `library` field: `resilience4j`, `hystrix`, or `opossum`.

---

## Schema Registry

Minimum signals (ANY ONE):

**Signal A — config property:**
```bash
grep -rn 'schema\.registry\.url' \
  --include='application.yml' --include='application.yaml' --include='application.properties' .
```

**Signal B — Confluent / Apicurio serializers (Java):**
```bash
grep -rn 'kafka-avro-serializer\|apicurio-registry-serdes\|ConfluentKafkaAvroSerializer\|AvroDeserializer' \
  --include='pom.xml' --include='*.gradle' --include='*.java' .
```

**Signal C — kafkajs schema registry (TypeScript):**
```bash
grep -rn '@kafkajs/confluent-schema-registry\|SchemaRegistry' \
  --include='package.json' --include='*.ts' . | grep -v node_modules
```

Capture `vendor` field: `confluent`, `apicurio`, or `unknown` when signal is only a config property.

**Edge example:**
```yaml
- {type: schema-registry, vendor: confluent, evidence: ["src/main/resources/application.yml:schema.registry.url"]}
```

---

## AsyncAPI

Minimum signals (ANY file found):

```bash
find . \( -name 'asyncapi.yml' -o -name 'asyncapi.yaml' -o -name 'asyncapi.json' \
  -o -name '*.asyncapi.yml' -o -name '*.asyncapi.yaml' -o -name '*.asyncapi.json' \
\) \
  ! -path '*/node_modules/*' \
  ! -path '*/target/*' \
  ! -path '*/dist/*' \
  ! -path '*/build/*'
```

- Any file found → emit the entry with `spec_path` set to the relative path of the first file found
- If multiple files found → list all paths in `evidence`

**Edge example:**
```yaml
- {type: asyncapi, spec_path: "docs/asyncapi.yaml", evidence: ["docs/asyncapi.yaml"]}
```

---

## schema_ref Discovery

When any of the following schema contract files co-locates with a transport entry (same directory or a well-known schema directory in the repo):

- `openapi.yaml`, `openapi.yml`, `openapi.json`
- `*.proto` (gRPC / Protobuf)
- `asyncapi.yaml`, `asyncapi.yml`
- `*.avsc` (Avro schema)
- `*.graphqls`, `schema.graphql` (GraphQL schema)

Capture the relative path as `schema_ref` on the transport edge. Set `schema_ref: null` when no schema contract file is found.

```bash
find . \( -name 'openapi.yaml' -o -name 'openapi.yml' -o -name '*.proto' \
  -o -name 'asyncapi.yaml' -o -name '*.avsc' -o -name '*.graphqls' -o -name 'schema.graphql' \
\) \
  ! -path '*/node_modules/*' ! -path '*/target/*' ! -path '*/dist/*' ! -path '*/build/*'
```
