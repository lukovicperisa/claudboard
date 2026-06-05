## MODIFIED Requirements

### Requirement: Write a single ecosystem.md at the umbrella root

After graph construction is confirmed, the system SHALL write exactly one `ecosystem.md` memory file at `<umbrella_root>/.claude/memories/ecosystem.md`. This applies to BOTH workspace mode and monorepo mode. The file is auto-loaded by Claude Code when sessions start at the umbrella root, providing cross-service context to all agents working anywhere within the project.

The prior per-repo behaviour (one ecosystem.md per service repo at `<repo>/.claude/memories/ecosystem.md`) is REPLACED. Per-repo ecosystem.md files are not written by default `/analyse` or by `/generate`/`/refresh` under any mode.

The rationale is that Claude Code discovers memories by walking UP from the session's CWD. When feature-workflow runs from the umbrella root (the normal case), per-repo `<repo>/.claude/memories/*.md` files are DOWN from CWD and are not loaded. Only an umbrella-root ecosystem.md is reliably loaded at workflow runtime.

In single-project mode (no cross-service split), ecosystem.md is either omitted entirely or written as a short degenerate file stating no cross-service dependencies exist.

#### Scenario: Workspace mode writes one umbrella ecosystem.md
- **WHEN** workspace-mode `/analyse` runs against a workspace with 14 service repos
- **THEN** exactly one ecosystem.md is written at `<workspace>/.claude/memories/ecosystem.md` containing entries for all 14 services
- **AND** no `<repo>/.claude/memories/ecosystem.md` files are written

#### Scenario: Monorepo mode writes one umbrella ecosystem.md
- **WHEN** monorepo-mode `/analyse` runs against a monorepo with 19 services
- **THEN** exactly one ecosystem.md is written at `<repo-root>/.claude/memories/ecosystem.md` containing entries for all 19 services

#### Scenario: Library repos do not get a section
- **WHEN** a repo or directory is classified as a library
- **THEN** the umbrella ecosystem.md does NOT contain a section dedicated to it as a service; the library may be referenced in the "Shared Contracts" or dependencies of services that consume it

#### Scenario: Single-project mode degenerate case
- **WHEN** `/analyse` runs against a single-project repo
- **THEN** either no ecosystem.md is written OR a short ecosystem.md is written stating the project has no cross-service dependencies

---

### Requirement: Umbrella ecosystem.md content structure

The umbrella ecosystem.md SHALL contain a top-level introduction (one paragraph naming the project and listing service count and detected stacks) followed by one section per service, populated from the dependency graph. Each per-service section SHALL contain:

1. **Header**: service name and one-sentence role description (inferred from inbound/outbound surface and name)
2. **Depends On**: table of services this service calls (target service, protocol, purpose, source file)
3. **Used By**: table of services that call this service (caller service, protocol, how)
4. **Shared Contracts**: list of Kafka/Solace topics, schemas, and shared library dependencies this service participates in; OpenAPI spec path if detected
5. **Coupling Warnings**: list of TIGHT edges or architectural risks involving this service

The first line of the file SHALL be a managed-file notice:

```
<!-- Managed by claudboard — do not edit manually. Run /refresh from the umbrella root to update. -->
```

#### Scenario: All services have sections in umbrella ecosystem.md
- **WHEN** workspace mode detects 14 service repos (and 0 libraries) and writes umbrella ecosystem.md
- **THEN** the file contains an introduction AND 14 per-service sections, each with the five sub-sections above

#### Scenario: Depends-on entries populated from graph
- **WHEN** order-service calls user-service via FeignClient in `UserServiceClient.java`
- **THEN** the order-service section of umbrella ecosystem.md contains a Depends On row: `user-service | REST (sync) | user validation | UserServiceClient.java`

#### Scenario: Coupling warning surfaces in both directions
- **WHEN** order-service → user-service edge is classified TIGHT (no circuit breaker)
- **THEN** the order-service section contains "REST call to user-service has no circuit breaker — if user-service is unavailable, order creation fails"
- **AND** the user-service section contains "order-service calls this service synchronously with no circuit breaker"

#### Scenario: External unresolved dependency noted
- **WHEN** order-service has an unresolved outbound reference to "payment-gateway"
- **THEN** the order-service section lists payment-gateway under Depends On as: `payment-gateway | REST | [external — not in project] | <source file>`

---

### Requirement: Umbrella ecosystem.md is overwritten on each `/analyse` and `/refresh` run

The umbrella ecosystem.md is fully managed by claudboard. `/analyse` and `/refresh` SHALL completely overwrite it with current graph data on each run. It is not hand-editable; manual edits are lost on the next regeneration.

#### Scenario: Overwritten on next `/analyse`
- **WHEN** `/analyse` runs against a project that already has an umbrella ecosystem.md
- **THEN** the file is completely overwritten with newly-derived content

---

### Requirement: Umbrella CLAUDE.md SHALL reference ecosystem.md

The umbrella CLAUDE.md generated by `/generate` SHALL contain a brief section pointing to the umbrella ecosystem.md memory file — not duplicating its content.

Per-service CLAUDE.md (when generated, per the `umbrella-root-output` capability) SHALL also reference the umbrella ecosystem.md by relative path.

#### Scenario: Umbrella CLAUDE.md references ecosystem.md
- **WHEN** `/generate` writes the umbrella CLAUDE.md
- **THEN** the file contains: "## Ecosystem\nCross-service dependencies and coupling analysis: `.claude/memories/ecosystem.md` (auto-loaded)."

#### Scenario: Per-service CLAUDE.md references umbrella ecosystem.md
- **WHEN** `/generate` writes `<workspace>/meas.cloud.controller/CLAUDE.md`
- **THEN** the file contains a line pointing to `<umbrella>/.claude/memories/ecosystem.md` (e.g. "For workspace topology, see umbrella `.claude/memories/ecosystem.md`")
