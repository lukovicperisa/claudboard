## ADDED Requirements

### Requirement: Write ecosystem.md memory file per repo
After graph construction is confirmed, the system SHALL write `.claude/memories/ecosystem.md` in each analysed service repo. This file is auto-loaded by Claude Code and provides cross-service context when working in any service.

The file SHALL NOT be written to library repos or the workspace root directory.

#### Scenario: Ecosystem file created for each service
- **WHEN** graph injection is confirmed AND 3 service repos are detected
- **THEN** the system SHALL write `order-service/.claude/memories/ecosystem.md`, `user-service/.claude/memories/ecosystem.md`, and `frontend/.claude/memories/ecosystem.md`

#### Scenario: Ecosystem file not written to workspace root
- **WHEN** graph injection is confirmed
- **THEN** NO file SHALL be written to the workspace directory itself

#### Scenario: Ecosystem file not written for libraries
- **WHEN** a repo is classified as a library
- **THEN** NO `ecosystem.md` SHALL be written for it (libraries are referenced from service ecosystem files instead)

### Requirement: Ecosystem.md content structure
Each `ecosystem.md` SHALL contain the following sections, populated from the dependency graph:

1. **Role**: one sentence describing this service's position and purpose in the ecosystem, inferred from its inbound/outbound surface and name
2. **Depends On**: table of services this repo calls (service, protocol, purpose, source file)
3. **Used By**: table of services that call this repo (service, protocol, how)
4. **Shared Contracts**: list of Kafka/Solace topics and schemas this service participates in; OpenAPI spec path if detected
5. **Coupling Warnings**: list of TIGHT edges or architectural risks involving this service

#### Scenario: Depends-on table populated
- **WHEN** order-service calls user-service via FeignClient in `UserServiceClient.java`
- **THEN** order-service's ecosystem.md SHALL contain a Depends On row: `user-service | REST (sync) | user validation | UserServiceClient.java`

#### Scenario: Used-by table populated
- **WHEN** order-service is called by frontend (REST) and consumed by reporting-service (Kafka)
- **THEN** order-service's ecosystem.md SHALL contain Used By rows for both

#### Scenario: Coupling warning injected
- **WHEN** order-service → user-service edge is classified TIGHT (no circuit breaker)
- **THEN** order-service's ecosystem.md SHALL contain: "⚠ REST call to user-service has no circuit breaker — if user-service is unavailable, order creation fails"
- **AND** user-service's ecosystem.md SHALL contain: "⚠ order-service calls this service synchronously with no circuit breaker"

#### Scenario: Unresolved external dependency noted
- **WHEN** order-service has an unresolved outbound reference to "payment-gateway"
- **THEN** order-service's ecosystem.md SHALL list it under Depends On as: `payment-gateway | REST | [external — not in workspace] | [source file]`

### Requirement: Ecosystem.md is overwritten on refresh
The `ecosystem.md` file is fully managed by claudboard. On workspace-level refresh, it SHALL be completely overwritten with updated graph data. It is not hand-editable — any manual edits will be lost on next refresh.

The first line of the file SHALL include a managed-file notice.

#### Scenario: Managed file notice present
- **WHEN** ecosystem.md is written
- **THEN** the first line SHALL be: `<!-- Managed by claudboard — do not edit manually. Run /refresh from workspace root to update. -->`

#### Scenario: Overwritten on workspace refresh
- **WHEN** `/refresh` is run from workspace root AND graph is reconstructed
- **THEN** all `ecosystem.md` files SHALL be completely overwritten with current graph data

### Requirement: CLAUDE.md lightweight ecosystem reference
If a CLAUDE.md is generated or updated for a service repo, it SHALL include a brief "Ecosystem" section pointing to the ecosystem.md memory file — not duplicating its content.

#### Scenario: CLAUDE.md ecosystem reference added
- **WHEN** a service CLAUDE.md is generated in workspace mode
- **THEN** it SHALL contain a section: "## Ecosystem\nThis service is part of [project]. Cross-service dependencies and coupling analysis: `.claude/memories/ecosystem.md` (auto-loaded)."
