## ADDED Requirements

### Requirement: Discovery script consolidates Phase 1b, 1c, and 1g into one tool call

The `claudboard-analyse` skill SHALL provide an executable `scripts/discover.sh` that runs the global file scan (Phase 1b), Wide Scan (Phase 1c), and duplication detection (Phase 1g) for a target repo path in a single bash invocation. The script SHALL emit a single JSON document to stdout containing all detection results. The analyse SKILL.md SHALL invoke `scripts/discover.sh <repo-path>` as its primary discovery step and consume the JSON output, replacing the prose-driven sequence of individual `grep` and `find` tool calls for those phases.

#### Scenario: Single-project run uses the discovery script

- **WHEN** `/analyse` runs on a single-project repo
- **THEN** the model invokes `bash scripts/discover.sh <repo-path>` exactly once for the repo
- **AND** the model does NOT issue separate `grep` or `find` tool calls for the patterns covered by the script (Phase 1b global file scan, Phase 1c Wide Scan, Phase 1g duplication detection)
- **AND** the discovery JSON appears in the conversation as a single tool result

#### Scenario: Monorepo run invokes the script per service

- **WHEN** `/analyse` runs on a monorepo with N services
- **THEN** the model invokes `scripts/discover.sh` once per service, each scoped to that service's directory
- **AND** the global-scope detection in Phase 1b (CI/CD files, root-level docs, shared libraries) is invoked separately at the repo root, also via the script

#### Scenario: Workspace sub-agent invokes the script for its repo

- **WHEN** `/analyse` runs in workspace mode and dispatches a per-repo sub-agent
- **THEN** the sub-agent invokes `scripts/discover.sh` once for its assigned repo path
- **AND** the per-repo report the sub-agent writes is based on the JSON output of that invocation

### Requirement: Discovery script output has a versioned schema

The `scripts/discover.sh` JSON output SHALL include a top-level `schema_version` field whose value is a string identifying the contract version. The analyse SKILL.md SHALL assert on the `schema_version` and stop with an actionable error message if the version does not match the version the SKILL.md was authored against.

#### Scenario: Schema version matches

- **WHEN** the discovery JSON contains `schema_version` matching the SKILL.md's expected version
- **THEN** the model proceeds with the run

#### Scenario: Schema version mismatch

- **WHEN** the discovery JSON contains a `schema_version` the SKILL.md does not recognise
- **THEN** the model stops the run and reports an error naming both the observed and expected versions and the path to `scripts/discover.sh`
- **AND** the model does NOT proceed to Phase 2 or write a report

### Requirement: Discovery script exposes reference-load signals

The `scripts/discover.sh` JSON output SHALL include a `ref_load_signals` object with boolean fields `messaging`, `streaming`, `graphql`, and `architectural`. Each boolean SHALL be true when the script detected at least one keyword match for that family in the repo (e.g., `messaging: true` when any of Kafka, AMQP, JMS, SNS/SQS, Solace, or RabbitMQ markers are present).

#### Scenario: REST-only Java repo signals all four as false except architectural-when-applicable

- **WHEN** the script runs on a repo with `@RestController` annotations but no Kafka, no WebSocket, no GraphQL, and no saga/CQRS/outbox markers
- **THEN** `ref_load_signals.messaging` is false
- **AND** `ref_load_signals.streaming` is false
- **AND** `ref_load_signals.graphql` is false
- **AND** `ref_load_signals.architectural` is false

#### Scenario: Event-driven repo with Kafka signals messaging true

- **WHEN** the script runs on a repo with `@KafkaListener` and `KafkaTemplate` usages
- **THEN** `ref_load_signals.messaging` is true

### Requirement: Conditional reference loading gated on discovery signals

The analyse SKILL.md SHALL load `edges/messaging.md`, `edges/streaming.md`, `edges/graphql.md`, and `patterns/architectural.md` only when their corresponding `ref_load_signals` boolean is true in the discovery JSON. The SKILL.md SHALL document the gate mapping explicitly as a table or equivalent machine-readable structure.

#### Scenario: REST-only repo skips event/streaming/graphql/pattern refs

- **WHEN** the discovery JSON reports all four `ref_load_signals` as false
- **THEN** the model does NOT load `edges/messaging.md`, `edges/streaming.md`, `edges/graphql.md`, or `patterns/architectural.md`
- **AND** the model still loads `workflow-signals.md` (always required as the dispatcher)
- **AND** the workflow-signals YAML block in the report uses `cross_service_edges: []` and `architectural_patterns: []` as defaults

#### Scenario: Event-driven repo loads only messaging ref

- **WHEN** the discovery JSON reports `messaging: true` and the other three signals as false
- **THEN** the model loads `edges/messaging.md`
- **AND** the model does NOT load `edges/streaming.md`, `edges/graphql.md`, or `patterns/architectural.md`

### Requirement: Elastic call-path tracing scoped to detected signals

Phase 1f call-path tracing SHALL include exactly the path types whose "When to include" condition matches the discovery JSON, rather than padding to a fixed count. Path types with always-include conditions (Simple CRUD, Complex business) SHALL always be traced. Conditional path types (Async/event, Auth/security, External integration) SHALL only be traced when their triggering signals are present in the discovery JSON.

#### Scenario: Simple repo traces only the always-include paths

- **WHEN** the discovery JSON shows no `@Async`, no auth annotations, and no `@FeignClient` or HTTP client usages
- **THEN** Phase 1f traces 2 paths: Simple CRUD and Complex business
- **AND** Phase 1f does NOT trace Async/event, Auth/security, or External integration paths

#### Scenario: Full-feature repo traces all five path types

- **WHEN** the discovery JSON shows `@Async`, custom auth annotations, and `@FeignClient` all present
- **THEN** Phase 1f traces all 5 path types

### Requirement: Duplication detection skipped on small repos

Phase 1g duplication detection SHALL be skipped entirely when the discovery JSON reports `repo.source_file_count < 30`. The skip SHALL be silent in the report (no "duplication not run" disclaimer) and Phase 2's "Code duplication" line SHALL be "None detected" in this case.

#### Scenario: Small repo skips duplication detection

- **WHEN** the discovery JSON reports `repo.source_file_count = 18`
- **THEN** the model does NOT execute Phase 1g duplication greps
- **AND** the Phase 2 report records "Code duplication: None detected"

#### Scenario: Medium and large repos run duplication detection

- **WHEN** the discovery JSON reports `repo.source_file_count >= 30`
- **THEN** Phase 1g executes per the existing prose

### Requirement: Trigger catalogs live in language packs, not in analyse SKILL.md

The Wide Scan trigger-annotation lists and the anti-pattern grep block SHALL live in the language-specific `stack-detectors-{language}.md` reference files, not inline in the analyse SKILL.md. The analyse SKILL.md SHALL retain only the procedural rules (when to run Wide Scan, how to interpret the discovery JSON, how to record findings); the specific patterns SHALL be deferred to whichever language pack matches the detected stack.

#### Scenario: Java repo loads Java triggers from the Java language pack

- **WHEN** `/analyse` runs on a Java repo
- **THEN** the model loads `stack-detectors-java.md` for the Java-specific Spring annotation triggers and Java-specific anti-pattern greps
- **AND** the analyse SKILL.md does NOT itself contain inline Java trigger lists

#### Scenario: TypeScript repo does not see Java triggers

- **WHEN** `/analyse` runs on a TypeScript-only repo
- **THEN** the model loads `stack-detectors-typescript.md` for the TypeScript triggers
- **AND** the model does NOT load `stack-detectors-java.md` (Java triggers are not seen by this run)

### Requirement: analyse SKILL.md size budget

The analyse SKILL.md size SHALL be at most 8K tokens (approximately 750 lines) after the trim. CI or a manual review checklist SHALL flag any change that grows the file beyond this budget without an explicit budget update.

#### Scenario: SKILL.md respects budget

- **WHEN** the analyse SKILL.md is measured at any point after the change is merged
- **THEN** its size is at most 8K tokens

### Requirement: Reports remain backwards-compatible

The structure, section names, YAML frontmatter fields, and file paths of `.claude/reports/claudboard-analysis*.md` SHALL be unchanged by this change. Existing consumers (`/generate`, `/refresh`, `/claudboard-workflow`, `/techdebt`) SHALL continue to read the reports without modification.

#### Scenario: Report diff before and after is content-equivalent

- **WHEN** `/analyse` runs on the same repo before and after this change
- **THEN** the produced reports have the same section headings, the same YAML frontmatter keys, and content that conveys the same detected findings (modulo non-deterministic ordering of list items)

#### Scenario: /generate consumes a post-change report without modification

- **WHEN** `/generate` runs on a project whose report was produced by the post-change `/analyse`
- **THEN** `/generate` proceeds without errors and produces the same artifacts it would have produced from a pre-change report
