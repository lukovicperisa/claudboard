# Architectural Pattern Gap Detection

Detects **missing architectural patterns** — cases where a pattern should be present given detected transports, but is not. These are distinct from code smells (pass 1) and design debt (pass 2). They represent structural correctness risks at the system level.

**Load this file during Pass 4 (Architecture Debt) in `claudboard-techdebt/SKILL.md`.**

**Prerequisite:** Analysis report must contain an `### Architectural Patterns` subsection. If absent, suppress all findings in this file and emit a single warning:

> "Architectural patterns subsection absent in analysis report — pattern-gap findings suppressed. Re-run `/analyse` to enable this check."

---

## Output heading in report

Emit findings under:

```markdown
## Architectural Pattern Gaps
```

This heading appears after the standard Architecture Debt section in each module report. If no findings are emitted, omit the heading entirely (no empty section).

---

## Gap 1: Missing Circuit Breaker on Outbound Calls

### Detection rule

**Condition (ALL must be true):**
1. The report's `workflow_signals.cross_service_edges` list contains ≥1 edge with `direction: outbound` and `family` in `{sync-rpc, graphql}` (i.e., at least one synchronous outbound HTTP/gRPC/GraphQL call exists)
2. The report's `architectural_patterns` subsection does NOT contain an entry with `type: circuit-breaker`

**Grep confirmation (run if condition looks true):**
```bash
# Confirm outbound sync calls exist but no circuit-breaker annotations
grep -rn '@FeignClient\|RestTemplate\|WebClient\|RestClient\|axios\.create\|fetch(' \
  --include='*.java' --include='*.ts' src/ | wc -l

grep -rn '@CircuitBreaker\|@Retry\|@Bulkhead\|@HystrixCommand\|opossum\|circuitBreaker' \
  --include='*.java' --include='*.ts' --include='package.json' . | grep -v node_modules | wc -l
```

If outbound call count ≥ 1 AND circuit-breaker annotation count = 0 → emit debt item.

### Debt item

**Severity:** MEDIUM  
**Category:** Architecture  
**Effort:** M (medium — adding annotations is low-effort per call, but deciding the right threshold values and fallback strategy takes design time)

```markdown
#### [TD-NNN] Missing circuit breaker on synchronous outbound calls

**Severity:** MEDIUM  
**Effort:** M  
**Category:** Architectural Pattern Gap

**Issue:** This service makes synchronous outbound calls (<list the detected clients: FeignClient names, RestTemplate targets, etc.>) but has no circuit breaker configured. If any upstream service is slow or unavailable, requests block here until timeout — causing latency amplification and potential cascade failure.

**Evidence:** <detected outbound edge file:line references from analysis report>

**Fix:**  
1. Add resilience4j dependency (if not present): `resilience4j-spring-boot3` or `resilience4j-circuitbreaker`  
2. Annotate outbound client methods with `@CircuitBreaker(name = "<service>-cb", fallbackMethod = "fallback<Method>")`  
3. Add `@Retry(name = "<service>-retry")` where appropriate  
4. Configure thresholds in `application.yml`: `resilience4j.circuitbreaker.<name>.*`  
5. Implement fallback methods that return a safe default or throw a specific exception  

**References:** Resilience4j Spring Boot starter documentation; existing project circuit-breaker patterns (if any found in sibling services)

**Depends on:** —
```

---

## Gap 2: Missing Outbox Pattern on Dual-Write

### Detection rule

**Condition (ALL must be true):**
1. The report's `workflow_signals.cross_service_edges` list contains ≥1 edge with `protocol` in `{kafka, rabbitmq, jms, google-pubsub, azure-service-bus, sns, sqs}` (i.e., a message broker is used)
2. The codebase has `@Transactional` methods that also contain broker send calls (DB write + broker send in same transaction boundary)
3. The report's `architectural_patterns` subsection does NOT contain an entry with `type: outbox`

**Grep confirmation:**
```bash
# Find files with both @Transactional and broker send calls
grep -rln '@Transactional' --include='*.java' src/ | \
  xargs grep -l 'KafkaTemplate\|RabbitTemplate\|JmsTemplate\|SnsClient\|SqsClient\|publisher\.send\|producer\.send' 2>/dev/null

# TS equivalent
grep -rln 'transaction\|@Transaction\|sequelize.transaction\|prisma.\$transaction' \
  --include='*.ts' src/ | \
  xargs grep -l 'producer\.send\|channel\.publish\|SNSClient\|SQSClient' 2>/dev/null
```

If any files match → emit debt item.

### Debt item

**Severity:** HIGH  
**Category:** Architecture  
**Effort:** L (large — outbox implementation is non-trivial; requires schema change + relay setup)

```markdown
#### [TD-NNN] Dual-write risk: database write and broker send in same transaction

**Severity:** HIGH  
**Effort:** L  
**Category:** Architectural Pattern Gap

**Issue:** This service writes to the database AND publishes a message to the broker within the same `@Transactional` method boundary. If the broker is unavailable or the transaction rolls back after the broker call succeeds, data becomes inconsistent: the broker message was sent but the DB change was not committed (or vice versa depending on commit order).

**Evidence:** <list the file:line references where @Transactional + broker send co-occur>

**Fix (Transactional Outbox pattern):**  
1. Create an `outbox_events` table (or collection) with columns: `id`, `event_type`, `payload`, `created_at`, `status`  
2. Add a Flyway/Liquibase migration for the outbox table  
3. Replace the direct broker send with an `OutboxRepository.save(outboxEvent)` — this runs inside the same `@Transactional` as the domain write  
4. Add a relay component (polling or CDC via Debezium) that reads pending outbox events and publishes them to the broker, marking them as processed on success  
5. Ensure the relay handles broker failures without re-sending already-processed events (idempotency via `status` column)  

**Alternative (if Debezium is already in the stack):** Configure the outbox event sourcing connector instead of a polling relay.

**References:** Eventuate Tram, Spring Modulith Events, or Debezium Outbox Event Router; existing outbox patterns in sibling services (if any)

**Depends on:** —
```

---

## Gap 3: Missing Schema Registry with Kafka

### Detection rule

**Condition (ALL must be true):**
1. The report's `workflow_signals.cross_service_edges` list contains ≥1 edge with `protocol: kafka` (Kafka producers or consumers are present)
2. The report's `architectural_patterns` subsection does NOT contain an entry with `type: schema-registry`

**Grep confirmation:**
```bash
# Confirm Kafka present without schema registry
grep -rn 'KafkaTemplate\|@KafkaListener\|spring-kafka\|kafkajs' \
  --include='*.java' --include='*.ts' --include='*.gradle' --include='pom.xml' --include='package.json' . | \
  grep -v node_modules | wc -l

grep -rn 'schema\.registry\.url\|kafka-avro-serializer\|apicurio-registry\|confluent-schema-registry' \
  --include='*.yml' --include='*.yaml' --include='*.properties' --include='pom.xml' --include='*.gradle' --include='package.json' . | \
  grep -v node_modules | wc -l
```

If Kafka count ≥ 1 AND schema registry count = 0 → emit debt item.

### Debt item

**Severity:** MEDIUM  
**Category:** Architecture  
**Effort:** M (medium — adding schema registry requires agreement on schema format and potential refactoring of serialization code)

```markdown
#### [TD-NNN] No schema registry with Kafka — schema evolution risk

**Severity:** MEDIUM  
**Effort:** M  
**Category:** Architectural Pattern Gap

**Issue:** This service uses Kafka producers/consumers but has no schema registry configured. Kafka messages are serialized without a shared schema contract (likely plain JSON). Without a registry, schema changes (adding/removing fields, changing types) are not validated and can silently break consumers when producers are updated first.

**Evidence:** <detected Kafka edge file:line references from analysis report>

**Fix:**  
1. Choose a schema registry: Confluent Schema Registry, Apicurio Registry, or AWS Glue Schema Registry  
2. Define Avro (or Protobuf/JSON Schema) schemas for each Kafka message type  
3. Add the schema registry serializer/deserializer dependency:  
   - Java: `kafka-avro-serializer` (Confluent) or `apicurio-registry-serdes-avro-serde` (Apicurio)  
   - Node.js: `@kafkajs/confluent-schema-registry`  
4. Configure `schema.registry.url` in `application.yml` / environment config  
5. Set producer `value.serializer` and consumer `value.deserializer` to use the registry-backed serializer  
6. Adopt a schema evolution strategy: backward/forward/full compatibility based on team agreement  

**References:** Confluent Schema Registry best practices; Avro schema evolution rules

**Depends on:** —
```

---

## Severity and Effort Reference

| Gap | Severity | Effort | Rationale |
|-----|----------|--------|-----------|
| Missing circuit breaker | MEDIUM | M | Risk is real in production but not a correctness bug in dev/test |
| Dual-write (missing outbox) | HIGH | L | Data inconsistency is a correctness bug — can cause lost messages or phantom messages in prod |
| Missing schema registry | MEDIUM | M | Schema drift is a risk that compounds over time but is not immediately critical |

Severity and effort values follow the **Debt** column from `severity-matrix.md`. Apply compound severity rules from that file if any gap co-occurs with other findings (e.g., missing outbox + God class in the producer service → escalate).
