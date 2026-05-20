## Context

claudboard's cross-service detection is implemented in two places that have drifted apart:

1. **`skills/claudboard/references/workflow-signals.md`** — defines the `cross_service_edges` schema with shape `{type, target}` and detection commands for Feign, RestTemplate/WebClient/RestClient, axios/fetch, requests, Kafka, gRPC.
2. **`skills/claudboard/references/stack-detectors.md` → "Cross-Service Surface Detection"** — defines the per-repo outbound/inbound surface extraction used for the workspace dependency graph. Covers the same patterns plus Solace SCS and Solace JCSMP.

Both files mix transports and produce overlapping outputs. The result is a flat catalog that's grown ad-hoc to fit the Bosch test repos (Java + Spring + Kafka + Solace) and is awkward to extend. Real microservice landscapes — especially TS/React-heavy and event-driven — use a much wider transport set, and architectural patterns (saga, CQRS, outbox, circuit breaker) are not detected at all.

Downstream consumers:
- `claudboard-workflow` reads `cross_service_edges` to resolve `CROSS_SERVICE_EDGES` and `KAFKA` capability flags
- `claudboard-techdebt` reads anti-pattern findings (does not yet read architectural patterns)
- `claudboard-generate` does not currently read the signals block at all

Constraint: this is a single atomic change (user choice), so schema, restructure, transports, and architectural patterns all land together.

## Goals / Non-Goals

**Goals:**
- Cover the common microservice transports for Java/Spring and TS/React/Node with **edge extraction** (not just labels)
- Detect common **architectural patterns** as first-class signals feeding both `feature-workflow` and `techdebt-scanner`
- **Restructure** the detection catalog into family-grouped files that can grow without bloating a single document
- Preserve **backward compatibility** for reports written under the old schema (`type`-only edges, no `architectural_patterns` block)
- Keep the **richer edge schema** strictly additive — `type` field retained as a synonym for `protocol`

**Non-Goals:**
- Kubernetes/Helm/CRD parsing (deferred — high value but separate skill area)
- Cross-service edge extraction in **single-repo mode** (workspace mode only)
- New transport coverage for Go, Python, Rust, .NET (unchanged from today; can be follow-up changes)
- Restructuring Solace-specific detection (already works; absorbed into `edges/messaging.md` without behavior change)
- Auto-fix or auto-remediation for missing architectural patterns (techdebt-scanner reports, doesn't fix)

## Decisions

### Decision 1: Restructure into family-grouped sub-catalogs

```
skills/claudboard/references/
├── workflow-signals.md          ← schema + dispatcher (what to load)
├── edges/
│   ├── sync-rpc.md              ← REST clients, gRPC, tRPC, Connect-RPC
│   ├── messaging.md             ← Kafka, RabbitMQ, JMS, Solace, MQTT,
│   │                              Redis pub/sub, SNS/SQS, Service Bus
│   ├── streaming.md             ← WebSocket, SSE, RSocket
│   └── graphql.md               ← Spring GraphQL, DGS, Apollo, urql
└── patterns/
    └── architectural.md         ← saga, CQRS, outbox, BFF, circuit
                                   breaker, schema registry, AsyncAPI
```

`workflow-signals.md` becomes a thin dispatcher: schema definition, output rules, pointers to the sub-catalogs. Each sub-catalog uses the same per-entry template (grep command, extraction rule, target shape, edge example).

**Alternatives considered:**
- *Keep flat, just add entries* — rejected: file is already 250+ lines; doubling content makes it harder to scan and harder to add language-specific signals.
- *One file per protocol* — rejected: too granular; many protocols share extraction patterns (all HTTP clients look similar). Family-level grouping is the right granularity.
- *Split by language instead of family* — rejected: detection is fundamentally per-transport; a Kafka entry needs to live next to other messaging entries regardless of language.

### Decision 2: Edge schema — additive structured fields

Old:
```yaml
- {type: feign, target: "<service-name>"}
```

New:
```yaml
- {family: sync-rpc, protocol: feign, direction: outbound, target: "<service-name>", schema_ref: null}
```

`type` field is retained on emit as a coarse synonym for `protocol` so existing consumers (`claudboard-workflow` reading `KAFKA` flag from `type: kafka`) continue to work without modification.

**Why `family`:**
- Enables coarse grouping in capability blocks (e.g., a `MESSAGING` block can trigger on any messaging protocol, not just Kafka)
- Helps the graph builder (`cross-service-graph`) decide matching strategy: sync-rpc matches by service name, messaging matches by topic name

**Why `direction`:**
- Existing schema implies outbound but doesn't say so. New TS/Node coverage adds inbound (Express/Fastify/NestJS routes), so explicit direction is necessary.
- Inbound entries feed the **inbound surface** that other repos' outbound edges match against.

**Why `schema_ref`:**
- When `openapi.yaml`, `*.proto`, `asyncapi.yaml`, or `*.avsc` is found near a transport entry, the path is captured for downstream consumption (architect-agent can reference it during design)
- Always nullable; absence is normal

**Alternatives considered:**
- *Versioned schema (`schema_version: 2`)* — rejected as overkill; additive fields with `type` synonym is enough. We can introduce versioning later if a true breaking change is needed.
- *Drop `type` immediately* — rejected: would break `claudboard-workflow` block-catalog references and any user-edited custom blocks. Cheap to keep.

### Decision 3: Architectural patterns as a separate top-level signal block

The report gains a new `### Architectural Patterns` subsection alongside `### Workflow Signals`:

```yaml
architectural_patterns:
  - {type: saga, style: orchestration, evidence: ["path/to/orchestrator.java:42", ...]}
  - {type: cqrs, evidence: ["path/to/command/", "path/to/query/"]}
  - {type: outbox, evidence: ["db/migrations/V42__create_outbox.sql"]}
  - {type: circuit-breaker, library: resilience4j, evidence: ["path/with/@CircuitBreaker:88"]}
  - {type: schema-registry, vendor: confluent, evidence: ["application.yml:schema.registry.url"]}
  - {type: asyncapi, spec_path: "docs/asyncapi.yaml"}
```

**Why a separate block (not folded into `workflow_signals`):**
- Conceptually distinct: transports = *how* services talk, patterns = *how* the system is shaped
- Different consumers: transports feed graph + capability flags; patterns feed feature-workflow guidance blocks + techdebt items
- Future-extensible without bloating workflow_signals

**Why `evidence` (a list of file:line refs):**
- Lets downstream consumers (architect-agent, techdebt-scanner) point users at concrete locations
- Avoids vague "found somewhere in repo" labels that aren't actionable

**Alternatives considered:**
- *Fold into `workflow_signals.architectural_patterns`* — rejected: backward compat is cleaner with a separate subsection; missing subsection defaults to empty list, no parser changes needed.
- *Emit patterns as edges* — rejected: a saga is not an edge, it's a property of a set of edges. Squeezing it into the edge schema would distort both.

### Decision 4: Workspace-only for edge extraction; single-repo can still detect patterns

- **Edge extraction** (every transport in `edges/*.md`) — runs only in workspace mode. Per the explore session: edges are only meaningful when there are other repos to point at.
- **Architectural pattern detection** (`patterns/architectural.md`) — runs in **both** workspace and single-repo modes. Patterns like outbox, circuit breaker, schema registry are intra-service properties and useful to detect even when no graph is being built.

**Why split:**
- Avoids wasted work in single-repo mode (no graph to populate)
- Pattern detection genuinely useful for single-repo techdebt scans

### Decision 5: New capability flags in `block-catalog.md`

```
RABBITMQ              ← @RabbitListener or RabbitTemplate detected
JMS                   ← @JmsListener or JmsTemplate detected
GRAPHQL               ← spring-graphql, DGS, Apollo client/server
WEBSOCKET             ← Spring WebSocket, native ws, socket.io
SAGA                  ← architectural_patterns contains saga
CQRS                  ← architectural_patterns contains cqrs
OUTBOX                ← architectural_patterns contains outbox
CIRCUIT_BREAKER       ← architectural_patterns contains circuit-breaker
```

Existing flags (`KAFKA`, `CROSS_SERVICE_EDGES`, etc.) keep their existing resolution rules.

Each new flag wraps one or more guidance blocks in `architect-agent.md.template` and `implementation-agent.md.template`. Format follows the existing `<!-- IF KAFKA --> ... <!-- /IF KAFKA -->` convention documented in `block-catalog.md`.

**Why these eight:**
- Each maps to a guidance burden a feature spec/implementation needs to consider when the pattern is present
- Each is detectable with high confidence from the new signals
- Stops short of `MQTT`/`REDIS_PUBSUB`/`SERVICE_BUS` because guidance for those is less differentiated from generic messaging — they can be added later if real repos demand it

### Decision 6: techdebt new categories

Three additions to `skills/claudboard-techdebt/references/`:

1. **Missing circuit breaker on outbound calls** — when a repo has outbound REST/gRPC edges but no `architectural_patterns` entry for `circuit-breaker`. Severity: MEDIUM.
2. **Missing outbox on dual-write** — when a repo writes to both a database (JPA/Mongo repository call) and a message broker (Kafka producer, etc.) within the same `@Transactional` method, and no outbox pattern is detected. Severity: HIGH (correctness risk).
3. **Missing schema registry with Kafka** — when Kafka producers/consumers exist but no schema registry signal. Severity: MEDIUM (schema evolution risk).

These are pattern-absence checks, distinct from existing code-smell checks. They live in a new `arch-pattern-gaps.md` reference file.

## Risks / Trade-offs

- **[Risk] Schema additions silently break custom block-catalog entries** → **Mitigation:** retain `type` field on emit; document the synonym mapping in `workflow-signals.md`; add a backward-compat note in `block-catalog.md`.
- **[Risk] Atomic change is large; reviewers may struggle to validate all transport detection** → **Mitigation:** each transport entry follows the existing 4-cell template (grep / extraction / target / example); reviewers can verify per-entry without holding the whole change in their head. Tasks file ordered so restructure lands first, then catalogs.
- **[Risk] False positives on architectural pattern detection (e.g., a class named `OrderOrchestrator` that isn't actually a saga)** → **Mitigation:** require multi-signal confirmation per pattern (Camunda dep AND state-machine library AND orchestrator class). Each pattern entry in `patterns/architectural.md` documents the minimum-signal threshold. When uncertain, omit rather than mis-label.
- **[Risk] Drift between `workflow-signals.md` edge catalog and `stack-detectors.md → Cross-Service Surface Detection`** → **Mitigation:** `stack-detectors.md` Cross-Service Surface section is reduced to a thin pointer ("see `workflow-signals.md` and `edges/*.md`"). Single source of truth.
- **[Risk] Generated `feature-workflow` skills for projects with many new flags become huge** → **Mitigation:** capability blocks are removed at generation time when their flag is `false`, so only relevant blocks ship. Same behavior as today — just more potential blocks.
- **[Trade-off] Inbound TS surface (Express/Fastify/NestJS routes) is harder to extract precisely than Spring `@RestController`** → routes are often defined dynamically. We extract what's statically grep-able and accept incomplete coverage; document the limitation in `edges/sync-rpc.md`.
- **[Trade-off] No version bump enforced in this change** → bump happens at merge time per existing repo convention; the schema is additive so old reports remain parseable indefinitely.

## Migration Plan

This is a documentation/skill change with no runtime state to migrate. Old analysis reports remain readable.

**Deployment sequence (matches task ordering):**
1. Restructure `workflow-signals.md` → sub-catalogs (no behavior change yet — old entries are moved, not modified)
2. Extend edge schema with new fields (additive); update existing entries to emit new fields with sensible defaults
3. Add new transport catalogs (additive)
4. Add `architectural_patterns` detection
5. Wire new capability flags in `block-catalog.md` + template wraps
6. Add techdebt arch-pattern-gap entries

**Rollback:** revert the change; no data migration needed. Reports generated under the new schema remain readable by old consumers (they ignore unknown fields).

**Regeneration guidance for users:** After merge, users with existing `.claude/reports/claudboard-analysis.md` can re-run `/claudboard-analyse` to gain the new signals. Existing reports continue to work but won't surface new capability blocks or architectural patterns until refreshed.

## Open Questions

- **Should `claudboard-refresh` re-run pattern detection on incremental updates, or only on full `/analyse`?** Lean: refresh runs pattern detection because patterns can change quickly (a new outbox table, a new `@CircuitBreaker` annotation). Decide during implementation when wiring the refresh delta.
- **Confidence thresholds for architectural patterns** — current proposal sets per-pattern thresholds heuristically. Should there be a single global `min_evidence_count` knob? Lean: no, each pattern has different signal density. Document per-pattern thresholds in `patterns/architectural.md`.
- **AsyncAPI as a transport vs as a pattern** — proposal puts it under architectural patterns. Arguable it's a contract signal (more like `schema_ref`). Resolution: keep under architectural patterns for v1 because it's about the team's adoption practice, not a per-edge property. Revisit if real reports show overlap.
