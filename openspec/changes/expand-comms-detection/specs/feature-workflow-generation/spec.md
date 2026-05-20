## ADDED Requirements

### Requirement: New transport capability flags
The `claudboard-workflow` skill SHALL resolve the following new capability flags from the analysis report and use them to gate template blocks: `RABBITMQ`, `JMS`, `GRAPHQL`, `WEBSOCKET`. Each flag SHALL evaluate to `true` when the corresponding protocol appears in the `cross_service_edges` list (matched on `protocol` field, with fallback to legacy `type` field).

#### Scenario: RABBITMQ flag true
- **WHEN** the analysis report's `cross_service_edges` list contains at least one edge with `protocol: "rabbitmq"` (or legacy `type: "rabbitmq"`)
- **THEN** the `RABBITMQ` capability flag SHALL resolve to `true` and all `<!-- IF RABBITMQ -->`-guarded blocks SHALL be retained in the generated skill

#### Scenario: JMS flag true
- **WHEN** the analysis report contains at least one edge with `protocol: "jms"` (or legacy `type: "jms"`)
- **THEN** the `JMS` capability flag SHALL resolve to `true`

#### Scenario: GRAPHQL flag true
- **WHEN** the analysis report contains at least one edge with `family: "graphql"`
- **THEN** the `GRAPHQL` capability flag SHALL resolve to `true`

#### Scenario: WEBSOCKET flag true
- **WHEN** the analysis report contains at least one edge with `family: "streaming"` AND `protocol` in {`websocket`, `stomp`, `socket-io`, `rsocket`}
- **THEN** the `WEBSOCKET` capability flag SHALL resolve to `true`

#### Scenario: Flag defaults
- **WHEN** the analysis report contains no matching edges for a given new flag
- **THEN** that flag SHALL resolve to `false` and its guarded blocks SHALL be removed from the generated skill

### Requirement: New architectural pattern capability flags
The `claudboard-workflow` skill SHALL resolve the following architectural-pattern capability flags from the analysis report's `architectural_patterns` block: `SAGA`, `CQRS`, `OUTBOX`, `CIRCUIT_BREAKER`. Each flag SHALL evaluate to `true` when an entry of the corresponding `type` exists in `architectural_patterns`.

#### Scenario: SAGA flag true
- **WHEN** the analysis report's `architectural_patterns` list contains an entry with `type: "saga"` (any style)
- **THEN** the `SAGA` capability flag SHALL resolve to `true`

#### Scenario: CQRS flag true
- **WHEN** the analysis report's `architectural_patterns` list contains an entry with `type: "cqrs"`
- **THEN** the `CQRS` capability flag SHALL resolve to `true`

#### Scenario: OUTBOX flag true
- **WHEN** the analysis report's `architectural_patterns` list contains an entry with `type: "outbox"`
- **THEN** the `OUTBOX` capability flag SHALL resolve to `true`

#### Scenario: CIRCUIT_BREAKER flag true
- **WHEN** the analysis report's `architectural_patterns` list contains an entry with `type: "circuit-breaker"`
- **THEN** the `CIRCUIT_BREAKER` capability flag SHALL resolve to `true`

#### Scenario: Architectural Patterns subsection missing
- **WHEN** the analysis report does not contain an "## Architectural Patterns" subsection
- **THEN** the system SHALL warn "Architectural Patterns subsection absent — pattern-based capability blocks may default off; consider re-running /analyse." and resolve all architectural-pattern flags to `false`

### Requirement: Template wrap points for new flags
Each new capability flag SHALL have at least one corresponding template-wrap point in the feature-workflow template tree. Wrap points SHALL follow the existing `<!-- IF <FLAG> --> ... <!-- /IF <FLAG> -->` convention.

#### Scenario: RABBITMQ wrap in architect-agent template
- **WHEN** `architect-agent.md.template` is rendered with `RABBITMQ: true`
- **THEN** the output SHALL contain RabbitMQ-specific design guidance (exchange/queue/routing-key design, dead-letter strategy, idempotency)

#### Scenario: SAGA wrap in architect-agent template
- **WHEN** `architect-agent.md.template` is rendered with `SAGA: true`
- **THEN** the output SHALL contain saga-specific design guidance (compensation actions, idempotency keys, orchestration vs choreography callout based on the detected style)

#### Scenario: OUTBOX wrap in implementation-agent template
- **WHEN** `implementation-agent.md.template` is rendered with `OUTBOX: true`
- **THEN** the output SHALL contain outbox-specific implementation guidance (transactional write to outbox + entity, polling/CDC mention, no direct broker send from `@Transactional`)

#### Scenario: CIRCUIT_BREAKER wrap in implementation-agent template
- **WHEN** `implementation-agent.md.template` is rendered with `CIRCUIT_BREAKER: true`
- **THEN** the output SHALL contain guidance to wrap new outbound calls with the detected circuit-breaker library (e.g., `@CircuitBreaker(name="...")`)

#### Scenario: GRAPHQL wrap in architect-agent template
- **WHEN** `architect-agent.md.template` is rendered with `GRAPHQL: true`
- **THEN** the output SHALL contain GraphQL-specific guidance (schema-first vs code-first, N+1 risk via DataLoader, schema versioning)

#### Scenario: WEBSOCKET wrap in architect-agent template
- **WHEN** `architect-agent.md.template` is rendered with `WEBSOCKET: true`
- **THEN** the output SHALL contain WebSocket-specific guidance (connection lifecycle, backpressure, reconnect strategy)

### Requirement: block-catalog.md documentation entries
The `skills/claudboard-workflow/references/block-catalog.md` file SHALL contain one entry per new capability flag, documenting: flag name, resolution rule (which edges/patterns activate it), default value, and a list of every template file containing wrap points for that flag.

#### Scenario: Catalog entry per new flag
- **WHEN** `block-catalog.md` is reviewed for any new flag (`RABBITMQ`, `JMS`, `GRAPHQL`, `WEBSOCKET`, `SAGA`, `CQRS`, `OUTBOX`, `CIRCUIT_BREAKER`)
- **THEN** the file SHALL contain a heading `## <FLAG>` followed by the resolution rule, default value, list of template wrap points, and "Removal behavior" subsection (matching the existing entry format for `KAFKA` and `CROSS_SERVICE_EDGES`)
