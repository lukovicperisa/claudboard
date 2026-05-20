# Workflow Signals Detection

Used by `claudboard-analyse` to populate the "### Workflow Signals" and "### Architectural Patterns" subsections of the analysis report. Consumed by `claudboard-workflow` for capability-flag resolution and by `claudboard-techdebt` for pattern-gap findings. Backward-compatible additive — a missing subsection defaults all signals to unknown/empty.

---

## Output Schema

### Cross-Service Edges

```yaml
workflow_signals:
  cross_service_edges:
    - {family: sync-rpc, protocol: feign, type: feign, direction: outbound, target: "<service-name>", schema_ref: null}
    - {family: sync-rpc, protocol: http,  type: http,  direction: outbound, target: "<url-or-unknown>", schema_ref: null}
    - {family: messaging, protocol: kafka, type: kafka, direction: outbound, target: "<topic-name>", schema_ref: null}
    - {family: sync-rpc, protocol: grpc,  type: grpc,  direction: inbound,  target: "<service-name-or-unknown>", schema_ref: "path/to/file.proto"}
    - {family: graphql,  protocol: graphql, type: graphql, direction: inbound, target: "getOrder", schema_ref: "src/schema.graphqls"}
  shared_libraries:
    - {name: "<artifactId-or-package>", consumer_count: <N>}
  auth_perimeter: "gateway|in-service-jwt|none|unknown"
  ticket_prefix: "PROJ|null"
```

**Field definitions:**

| Field | Values | Notes |
|-------|--------|-------|
| `family` | `sync-rpc`, `messaging`, `streaming`, `graphql` | Transport family for coarse grouping |
| `protocol` | `feign`, `http`, `grpc`, `kafka`, `rabbitmq`, `jms`, `solace-scs`, `solace-jcsmp`, `sns`, `sqs`, `azure-service-bus`, `google-pubsub`, `mqtt`, `redis-pubsub`, `kafkajs`, `nestjs-microservice`, `websocket`, `stomp`, `sse`, `rsocket`, `socketio`, `trpc`, `graphql`, ... | Specific transport protocol |
| `type` | Same as `protocol` | Backward-compat synonym for `protocol`. Always emit alongside `protocol`. |
| `direction` | `inbound`, `outbound` | `inbound` = this service receives; `outbound` = this service sends |
| `target` | service name, URL, topic name, route path | What is being called/published-to/subscribed-to |
| `schema_ref` | relative file path or `null` | Path to co-located schema contract file (OpenAPI, proto, AsyncAPI, Avro, GraphQL schema) |

**Rules:**
- `cross_service_edges`: list of detected communication edges; empty list `[]` if none
- `shared_libraries`: list of libraries used by 2+ services; empty list `[]` for single-repo or if none
- `auth_perimeter`: exactly one of `gateway`, `in-service-jwt`, `none`, or `unknown`
- `ticket_prefix`: string (e.g. `"PLAT"`) or `null`
- **Always emit this block** even when all signals are empty/unknown — the subsection must always be present in the report
- **Edge extraction runs in workspace mode only.** In single-repo mode, emit `cross_service_edges: []`.

### Backward-Compat: `type` ↔ `protocol` synonym

The old schema used only `{type, target}`. The new schema uses `{family, protocol, type, direction, target, schema_ref}`. To preserve compatibility with consumers reading the old `type` field:

- **Always emit `type` alongside `protocol`** with the same value
- Consumers reading only `type` continue to work (e.g., `claudboard-workflow` checking `type: kafka`)
- Consumers that understand the new schema should use `protocol` and `family` instead

Example: old consumer reads `type: feign` → still works. New consumer reads `protocol: feign, family: sync-rpc, direction: outbound` → richer context.

### Architectural Patterns

```yaml
architectural_patterns:
  - {type: saga, style: orchestration, evidence: ["path/to/orchestrator.java:42"]}
  - {type: cqrs, evidence: ["src/main/java/com/example/command/", "src/main/java/com/example/query/"]}
  - {type: outbox, evidence: ["db/migrations/V42__create_outbox.sql"]}
  - {type: circuit-breaker, library: resilience4j, evidence: ["path/with/@CircuitBreaker:88"]}
  - {type: schema-registry, vendor: confluent, evidence: ["application.yml:schema.registry.url"]}
  - {type: asyncapi, spec_path: "docs/asyncapi.yaml"}
```

- Emit `architectural_patterns: []` (empty list) when no patterns are detected
- Pattern runs in both workspace and single-repo modes
- BFF detection is workspace-only (requires sibling service context)
- "Empty evidence → no entry" rule: omit a pattern entry when its minimum-signal threshold is not met

---

## Sub-Catalogs

Transport-specific grep commands and extraction rules are in the sub-catalogs. Load the relevant files during analysis:

| What to detect | Load file |
|----------------|-----------|
| REST clients, gRPC, tRPC, Connect-RPC, inbound routes | `edges/sync-rpc.md` |
| Kafka, RabbitMQ, JMS, Solace, MQTT, Redis pub/sub, SNS/SQS, Service Bus | `edges/messaging.md` |
| WebSocket, SSE, RSocket, socket.io | `edges/streaming.md` |
| Spring GraphQL, DGS, Apollo, urql, graphql-request, Relay | `edges/graphql.md` |
| Saga, CQRS, Outbox, BFF, Circuit Breaker, Schema Registry, AsyncAPI | `patterns/architectural.md` |

Also see `patterns/architectural.md` → "schema_ref Discovery" for the rule on capturing co-located schema contract files.

---

## Detection: Shared Libraries

Only meaningful in **workspace or monorepo mode**. In single-repo mode, emit `shared_libraries: []`.

### Maven (Java/Kotlin)

```bash
find . -name 'pom.xml' \
  ! -path '*/node_modules/*' ! -path '*/target/*' ! -path '*/.gradle/*'
```

For each `pom.xml` found, extract all `<artifactId>` values within `<dependency>` sections. Count how many distinct `pom.xml` files reference each `<artifactId>`. Report those with count ≥ 2:

```bash
grep -rh '<artifactId>' --include='pom.xml' . \
  | sed 's/.*<artifactId>\(.*\)<\/artifactId>.*/\1/' \
  | sort | uniq -c | sort -rn | awk '$1 >= 2 {print $1, $2}'
```

Each result → `{name: "<artifactId>", consumer_count: <N>}`. Filter out known external artifacts; focus on internal group IDs.

### NPM Workspace (TypeScript/JavaScript)

```bash
find . -name 'package.json' \
  ! -path '*/node_modules/*' ! -path '*/dist/*' ! -path '*/build/*'
```

1. From root `package.json`, identify workspace globs
2. Collect all internal package names (packages in workspace globs or `@<scope>/` prefix)
3. Count how many other `package.json` files list each internal package in `dependencies` or `devDependencies`
4. Report those with count ≥ 2: `{name: "<package-name>", consumer_count: <N>}`

---

## Detection: Auth Perimeter

Classify into exactly one of: `gateway`, `in-service-jwt`, `none`, `unknown`. Apply in order — first match wins.

### gateway

```bash
find . -maxdepth 3 -type d \( \
  -name '*gateway*' -o -name '*api-gateway*' -o -name '*proxy*' \
\)
grep -rn 'spring-cloud-starter-gateway' --include='pom.xml' --include='*.gradle' --include='*.gradle.kts' .
find . -name 'kong.yml' -o -name 'kong.yaml'
find . -name 'traefik.yml' -o -name 'traefik.yaml'
```

If any match → `auth_perimeter: "gateway"`

### in-service-jwt

```bash
grep -rn 'JwtDecoder\|oauth2ResourceServer()' --include='*.java' --include='*.kt' src/
grep -rn 'OAuth2PasswordBearer' --include='*.py' src/
grep -rn 'expressjwt\|jsonwebtoken' --include='*.ts' --include='*.js' --include='*.tsx' src/
```

If any match (and no gateway) → `auth_perimeter: "in-service-jwt"`

### none / unknown

- No auth signals → `auth_perimeter: "none"`
- Auth signals found but do not match gateway or JWT patterns (custom session, SAML, proprietary) → `auth_perimeter: "unknown"`

---

## Detection: Ticket Prefix

### Step 1: Scan commit messages

```bash
git log --oneline -50 | grep -oP '^[a-f0-9]+ [A-Z]+-[0-9]+' | grep -oP '[A-Z]+' \
  | sort | uniq -c | sort -rn | head -5
```

If ≥50% of the last 50 commits match AND ≥80% of those share the same alphabetic prefix → use that prefix.

### Step 2: Scan branch names (fallback)

```bash
git branch -a | grep -oP '[a-z]+/([A-Z]+-[0-9]+)/' | grep -oP '[A-Z]+' \
  | sort | uniq -c | sort -rn | head -5
```

Apply same threshold: ≥50% of last 20 branch names AND ≥80% share the same prefix → use that prefix.

### Step 3: Null fallback

If neither step yields a confident prefix → `ticket_prefix: null`

---

## Backward Compatibility

Consumers (`claudboard-generate`, `claudboard-refresh`, `claudboard-techdebt`) treat a missing "### Workflow Signals" section as normal. Only `claudboard-workflow` reads this subsection.

When the subsection is missing, `claudboard-workflow` warns:

> "Limited workflow signals available — capability blocks may default off; consider re-running `/analyse` to refresh."

and continues with all signals defaulted:
- `cross_service_edges: []`
- `shared_libraries: []`
- `auth_perimeter: "unknown"`
- `ticket_prefix: null`

When `architectural_patterns` subsection is absent (old-schema report), `claudboard-workflow` defaults all pattern-derived flags to `false` and `claudboard-techdebt` suppresses architectural-pattern-gap findings with a warning:

> "Architectural patterns subsection absent in analysis report — pattern-gap findings suppressed. Re-run `/analyse` to enable."
