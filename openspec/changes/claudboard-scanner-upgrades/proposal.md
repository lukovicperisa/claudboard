## Why

Claudboard's scanner produces solid structural analysis (stack detection, anti-patterns, conventions) but misses several dimensions that real-world brownfield projects expose. Running it against `meas.cloud.datahandler` revealed: no security posture analysis despite custom `@Authorize` aspect + JWT auth, no API surface inventory despite 9 controllers, no observability checks, proposed skills with overlapping scope (mongodb-entity vs leaf-entity), and severity ratings that don't account for compounding risks (null returns + reflection + cascading deletes = silent data loss, not just INFO).

These gaps reduce the scanner's value for enterprise Java/Spring projects — exactly the target audience.

## What Changes

- Add **security posture detection** to Phase 1 wide scan and Phase 2 quality assessment — auth filters, RBAC/ABAC patterns, CORS, custom auth annotations
- Add **API surface inventory** to Phase 1 — endpoint count, versioning strategy, OpenAPI/Swagger presence, pagination patterns
- Add **observability detection** — Spring Actuator, Micrometer metrics, distributed tracing, structured logging
- Add **skill deduplication logic** to Phase 2 — detect overlapping skill proposals before presenting to user
- Add **compound severity escalation** to Phase 2 — when anti-patterns reinforce each other, escalate severity beyond individual ratings
- Expand **dependency analysis** — BOM detection, exclude/force patterns, SBOM presence

## Capabilities

### New Capabilities
- `security-posture`: Detection patterns for auth flows, RBAC, CORS, rate limiting; new quality dimension in scoring
- `api-surface-inventory`: Endpoint counting, versioning detection, OpenAPI presence check; new report section
- `observability-detection`: Actuator, metrics, tracing, structured logging detection; new quality dimension
- `skill-dedup`: Logic to detect and resolve overlapping skill proposals before Phase 3
- `compound-severity`: Cross-referencing anti-pattern findings to escalate severity when risks compound
- `dependency-deep-scan`: BOM detection, conflict resolution patterns, SBOM presence

### Modified Capabilities

## Impact

- `skills/claudboard/SKILL.md` — Phase 1c (new grep patterns), Phase 2 (new report sections, dedup logic, compound severity)
- `skills/claudboard/references/quality-signals.md` — 3 new scoring dimensions (Security, API Surface, Observability)
- `skills/claudboard/references/stack-detectors.md` — new detection patterns per capability
- `skills/claudboard/references/pattern-catalog.md` — compound severity rules, security anti-patterns
- No breaking changes — all additive to existing scan flow
