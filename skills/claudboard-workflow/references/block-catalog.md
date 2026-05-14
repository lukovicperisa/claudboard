# Block Catalog — v1 Capability Flags

All 10 capability flags used in feature-workflow templates. For each flag, this
catalog documents when it resolves true, where the value comes from, which
template blocks reference it, and what gets dropped when it is false.

---

## JIRA_AVAILABLE

**Resolves true when:** An Atlassian MCP server entry is present in the project's
`.mcp.json` (project-level) or in `~/.claude/mcp_servers.json` /
`~/.claude.json` (user-level). Detection looks for server keys or names
containing "atlassian", "jira", or "confluence", or command/args referencing
`@atlassian/`.

**Source:** MCP configuration inspection during Phase 1d of the orchestrator.
Project-level config takes precedence over user-level.

**Capability blocks that reference it:**

- `SKILL.md.template` — wraps the entire "Jira" phase in the start-feature flow
  (ticket fetch, acceptance criteria population, sprint assignment).
- `config.json.template` — wraps the top-level `"jira": { ... }` key.
- `agents/jira-agent.md` — the jira-agent file itself is only written when this
  flag is true (it is a verbatim conditional file, not a templated one).
- `agents/architect-agent.md.template` — wraps Jira-aware context sections
  (ticket ID in session context, AC reference in design prompts).
- `agents/implementation-agent.md.template` — wraps Jira ticket cross-reference
  in commit message instructions.
- `agents/spec-reviewer.md.template` — wraps AC-completeness check against the
  Jira ticket.

**When false:**

- `agents/jira-agent.md` is not written to the target directory.
- All Jira phases in `SKILL.md.template` are removed (ticket fetch step, sprint
  assignment step, AC population step).
- The `"jira"` key block in `config.json.template` is removed; the output
  `config.json` will have no Jira section.
- Jira cross-references in agent templates are removed.
- The completion report adds an MCP warning:
  > ADO_AVAILABLE = false — Jira MCP not detected. Jira-specific phases in the
  > generated skill are stubbed.

---

## ADO_AVAILABLE

**Resolves true when:** An Azure DevOps MCP server entry is present in the
project's `.mcp.json` or user-level MCP config. Detection looks for server keys
or names containing "azure-devops", "ado", or command/args referencing
`azure-devops-mcp` or `@microsoft/azure`.

**Source:** MCP configuration inspection during Phase 1d of the orchestrator.

**Capability blocks that reference it:**

- `SKILL.md.template` — wraps ADO-specific steps: PR creation via ADO MCP,
  pipeline trigger checks, work item linking in PR description.
- `config.json.template` — wraps the top-level `"azureDevOps": { ... }` key.
- `agents/pr-agent.md.template` — wraps ADO PR creation instructions (vs GitHub
  CLI fallback).
- `agents/git-agent.md.template` — wraps ADO branch policy enforcement notes.

**When false:**

- All ADO-specific phases in `SKILL.md.template` are removed.
- The `"azureDevOps"` key block in `config.json.template` is removed.
- `agents/pr-agent.md` falls back to GitHub CLI instructions.
- The completion report adds an MCP warning:
  > ADO_AVAILABLE = false — Azure DevOps MCP not detected. ADO-specific phases
  > in the generated skill are stubbed. To enable, configure the Azure DevOps
  > MCP server and re-generate.

---

## WORKSPACE_MODE

**Resolves true when:** The analysis report frontmatter contains
`workspace: true` OR the report body contains a "Workspace mode" topology
section OR the claudboard-analyse report was generated from a workspace/multi-repo
root (indicated by the "Flow Summary" noting "Workspace:" mode).

**Source:** Analysis report frontmatter and report body sections.

**Capability blocks that reference it:**

`SKILL.md.template`:
- Workspace configuration section — explains the `repos: { ... }` map shape in
  `config.json` and the `<workspaceRoot>` variable.
- Agent architecture workspace block — per-repo context-loading mandate
  (`load-repo-context.sh`), per-repo agent spawning model.
- Phase 1a-ws — affected_repos inference + user confirmation gate.
- Phase 1c-ws — per-repo plan slices written to `.claude/changes/<TICKET>/`.
- Phase 2 prefix — branch created in all affected repos in parallel.
- Phase 3 prefix — development loop over `implementationOrder`.
- Phase 4 prefix — commit each affected repo independently in parallel.
- Phase 5 prefix — run reviewers for each affected repo.
- Phase 6 — parallel PR creation for all repos + merge-order recommendation.
- Phase 7a — per-repo breakdown in worklog comment body.

`agents/architect-agent.md.template`:
- Workspace-wide rules preamble (ecosystem-coupling, shared-lib-bumps).
- `action: "infer-affected-repos"` handler.
- `action: "write-plan-slices"` handler.
- Plan template sections: Affected repos, Recommended PR merge order.

`agents/implementation-agent.md.template`:
- Repo-scoping preamble (`REPO_ROOT`, `load-repo-context.sh`).
- Workspace-wide rules note.
- Baseline workspace step (module-name discovery).

`agents/git-agent.md.template`:
- Repo-scoping preamble (`REPO_ROOT`, `(cd "$REPO_ROOT" && ...)`).

`agents/pr-agent.md.template`:
- Repo-scoping override (`config.repos[repo].azureDevOps.repositoryId`).

`agents/design-reviewer.md.template`:
- Repo-scoping preamble (`load-repo-context.sh`, scoped `git diff`).

`agents/spec-reviewer.md.template`:
- Repo-scoping preamble (same as design-reviewer).

`config.json.template`:
- `repos: {{REPOS_MAP_JSON}}` key — top-level repos map.

`scripts/load-repo-context.sh`:
- New verbatim file; only written when `WORKSPACE_MODE = true`.

**When false:**

- All workspace/sibling-service context blocks are removed.
- Agent instructions treat the repo as fully self-contained.
- `{{WORKSPACE_NAME}}`, `{{REPO_COUNT}}`, `{{REPO_LIST_BULLETS}}`,
  `{{REPOS_MAP_JSON}}` variables are irrelevant (only appear inside
  WORKSPACE_MODE blocks).
- `scripts/load-repo-context.sh` is NOT written to the target.
- `config.json` does not include the `repos: { ... }` key.

---

## CROSS_SERVICE_EDGES

**Resolves true when:** The "Workflow Signals" subsection of the analysis report
lists at least one cross-service edge (e.g., a REST dependency on another
service, a Kafka topic consumed by another service).

**Source:** Workflow Signals subsection → `cross_service_edges` list (count ≥ 1).

**Capability blocks that reference it:**

- `agents/architect-agent.md.template` — wraps cross-service impact analysis
  instructions: tells the architect to enumerate affected downstream services
  before finalising design.
- `SKILL.md.template` — wraps a "cross-service impact check" step in the
  planning phase.

**When false:**

- Cross-service impact analysis blocks are removed.
- The architect agent treats all changes as locally contained.

---

## SHARED_LIB

**Resolves true when:** The "Workflow Signals" subsection lists at least one
shared library with `consumer_count ≥ 2` (i.e., at least 2 sibling services
depend on it).

**Source:** Workflow Signals subsection → `shared_libs` list, where at least one
entry has `consumer_count >= 2`.

**Capability blocks that reference it:**

- `agents/architect-agent.md.template` — wraps shared-library versioning
  guidance: bump shared-lib version, update all consumer `pom.xml` / `package.json`
  references, note downstream breakage risk.
- `agents/implementation-agent.md.template` — wraps shared-lib change checklist
  (build shared lib, verify consumers compile, update CHANGELOG).
- `SKILL.md.template` — wraps a "shared library impact" step in implementation
  phase.

**When false:**

- Shared-library guidance blocks are removed.
- Agents assume no cross-consumer library impact.

---

## AUTH_PERIMETER

**Resolves true when:** The Workflow Signals `auth_perimeter` field is not "none"
and not "unknown" — i.e., the project has a detectable authentication boundary
(e.g., "gateway", "in-service-jwt").

**Source:** Workflow Signals subsection → `auth_perimeter` field.

**Capability blocks that reference it:**

- `agents/architect-agent.md.template` — wraps auth-perimeter awareness: tells
  the architect to check whether new endpoints require authentication, whether
  new routes need gateway registration, and whether JWT scopes need updating.
- `agents/spec-reviewer.md.template` — wraps security checklist items (e.g.,
  "does the spec document which auth scopes this endpoint requires?").
- `SKILL.md.template` — wraps an "auth impact" check in the planning phase.

**When false:**

- Auth-perimeter guidance blocks are removed.
- Agents do not include security-scope prompts in planning or review.

---

## MEMORIES_PRESENT

**Resolves true when:** The directory `.claude/memories/` exists in the project
root and contains at least one `.md` file.

**Source:** Filesystem check at orchestrator runtime (not from analysis report).

**Capability blocks that reference it:**

- `agents/architect-agent.md.template` — wraps a "load memories" instruction at
  the top of the agent prompt: tells the architect to read all `.md` files in
  `.claude/memories/` before starting design work.
- `agents/implementation-agent.md.template` — wraps a similar "load memories"
  preamble.
- `SKILL.md.template` — wraps a note in session-start instructions about
  auto-loaded memories.

**When false:**

- Memory-loading preamble blocks are removed.
- Agents do not reference `.claude/memories/` in their prompts.

---

## MONGODB

**Resolves true when:** The analysis report detects Spring Data MongoDB — evidence
includes `spring-data-mongodb` dependency in `pom.xml` / `build.gradle`, the
`@Document` annotation on domain classes, or a `MongoRepository` subclass.

**Source:** Analysis report stack detection section / Wide Scan pattern inventory.

**Capability blocks that reference it:**

- `agents/architect-agent.md.template` — wraps MongoDB-specific design guidance:
  document schema evolution strategy, index recommendations, aggregation
  pipeline considerations.
- `agents/implementation-agent.md.template` — wraps MongoDB-specific coding
  reminders: use `@Document` on new entities, extend `MongoRepository`, avoid
  loading full collections.
- `{{STACK_REMINDERS}}` in `SKILL.md.template` — the "Preserve" bullet for
  MongoDB conventions contributes to this variable's rendered value.

**When false:**

- MongoDB-specific guidance blocks are removed.

---

## JPA

**Resolves true when:** The analysis report detects Spring Data JPA or Hibernate
— evidence includes `spring-data-jpa` or `hibernate-core` dependency, the
`@Entity` annotation on domain classes, or a `JpaRepository` subclass.

**Source:** Analysis report stack detection section / Wide Scan pattern inventory.

**Capability blocks that reference it:**

- `agents/architect-agent.md.template` — wraps JPA-specific design guidance:
  entity relationship design, fetch strategy (LAZY vs EAGER), N+1 query risk,
  migration script requirement.
- `agents/implementation-agent.md.template` — wraps JPA coding reminders:
  `@Entity` / `@Table` annotations, `@Column` constraints, Liquibase/Flyway
  migration for schema changes.
- `agents/sdd-expert-agent.md.template` — wraps data model documentation
  requirements (ER diagram, migration rationale).

**When false:**

- JPA-specific guidance blocks are removed.

---

## KAFKA

**Resolves true when:** The analysis report detects Kafka producers or consumers
— evidence includes `spring-kafka` dependency, `@KafkaListener` annotation,
`KafkaTemplate` usage, or `@EnableKafka` configuration.

**Source:** Analysis report stack detection section / Wide Scan pattern inventory.

**Capability blocks that reference it:**

- `agents/architect-agent.md.template` — wraps Kafka design guidance: topic
  naming conventions, message schema and versioning, consumer group naming,
  dead-letter topic strategy.
- `agents/implementation-agent.md.template` — wraps Kafka coding reminders:
  producer acknowledgement config, idempotent consumer pattern, error handler
  registration.
- `SKILL.md.template` — wraps a note in the implementation checklist about Kafka
  schema compatibility before deploying.

**When false:**

- Kafka-specific guidance blocks are removed.

---

## Flag Summary Table

| Flag | Source type | Default when Workflow Signals absent |
|------|-------------|--------------------------------------|
| `JIRA_AVAILABLE` | MCP config | `false` |
| `ADO_AVAILABLE` | MCP config | `false` |
| `WORKSPACE_MODE` | Analysis report | `false` |
| `CROSS_SERVICE_EDGES` | Workflow Signals | `false` |
| `SHARED_LIB` | Workflow Signals | `false` |
| `AUTH_PERIMETER` | Workflow Signals | `false` |
| `MEMORIES_PRESENT` | Filesystem check | Evaluated regardless |
| `MONGODB` | Analysis report | `false` |
| `JPA` | Analysis report | `false` |
| `KAFKA` | Analysis report | `false` |
