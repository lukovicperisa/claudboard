---
name: claudboard-analyse
description: >
  Deep-analyzes a project repository: detects tech stack, architecture patterns,
  coding conventions, testing strategies, CI/CD pipelines, quality signals, and
  anti-patterns. Produces a structured analysis report saved to
  .claude/reports/claudboard-analysis.md.
  Use when: /analyse, "analyze this codebase", "scan this repo", "project
  health check", "audit this project", "what patterns does this repo use",
  "understand this project", "code quality review", "architecture audit".
---

# Analyse — Codebase Discovery & Analysis

Scans a repository, detects patterns, and saves a structured analysis report. **Read-only** — never modifies source code or generates artifacts.

## Invocation

```
/analyse [path]
```

Path defaults to the current working directory. Works on any language/framework.

---

## Phase 1: Discovery

Load `../claudboard/references/stack-detectors.md` first — it lists which files to check and what to extract per language. For Wide Scan patterns, load the language-specific file: `stack-detectors-java.md`, `stack-detectors-typescript.md`, `stack-detectors-python.md`, `stack-detectors-go.md`, `stack-detectors-rust.md`, or `stack-detectors-dotnet.md`.

### 1a. Right-level check, workspace/monorepo detection, & service classification

**Step 0: Right-level check** — run FIRST, before any other detection.

Follow `../claudboard/references/stack-detectors.md` → "Right-Level Check":

1. Check if CWD has a build file AND parent directory (`../`) contains N≥2 sibling directories with build files
2. If siblings found:
   - Detect stack for each sibling (use build file signals from stack-detectors.md)
   - Present step-up prompt with sibling list and detected stacks:
     ```
     This looks like a microservice within a larger system.
     
     Found sibling services at [parent-dir]:
     • user-service (Java/Spring Boot)
     • frontend (React/TypeScript)
     
     Analyse at ecosystem level for cross-service dependency mapping? [y/n]
     ```
   - Wait for user response:
     - **YES** → re-run analysis from parent directory (proceed to Step 1 from there)
     - **NO** → proceed with analysis at CWD, skip to Step 1

3. **Skip right-level check if:**
   - CWD has no build file (already at workspace/monorepo root)
   - Parent has <2 other build-file directories

**Step 1: Monorepo or workspace detection**

Follow `../claudboard/references/stack-detectors.md` → "Monorepo Detection & Service Classification":

1. Find all independent build roots at depth 1-3 (excluding dependency dirs):
   ```bash
   find . -maxdepth 3 \( \
     -name 'build.gradle' -o -name 'build.gradle.kts' \
     -o -name 'pom.xml' -o -name 'package.json' \
     -o -name 'go.mod' -o -name 'pyproject.toml' \
     -o -name 'Cargo.toml' -o -name '*.csproj' \
   \) ! -path '*/node_modules/*' ! -path '*/.venv/*' ! -path '*/vendor/*' \
      ! -path '*/.gradle/*' ! -path '*/target/*' ! -path '*/dist/*' ! -path '*/build/*'
   ```

2. **If 1 build root found:** Single-project repo. Skip to Phase 1b and proceed with standard single-project flow.

3. **If 2+ build roots found:** Check for `.git/` in each build root directory:
   - **All build-root dirs have `.git/`** → **Workspace mode** (multi-repo)
   - **No build-root dirs have `.git/` (only at repo root)** → **Monorepo mode**
   - **Mixed** (some with `.git/`, some without) → build-root dirs WITH `.git/` are independent repos; dirs WITHOUT `.git/` are treated as shared libraries/infra and excluded from service list

4. **If no build files found anywhere:** Report error: "No projects found at [path]. Check the path and try again." Stop.

**Step 2: Service vs library classification** (monorepo and workspace modes)

For each build root (monorepo services or workspace repos):

1. Classify as **service** or **library** using per-stack signals from `../claudboard/references/stack-detectors.md` → "Service Classification":
   - Service signals: `Dockerfile`, main entry point, runtime config
   - Library signals: publish task configured, no main entry point, no Dockerfile
   - Ambiguous → default to **service** (full analysis)

2. **Exclude** infrastructure directories from service list:
   - `infra/`, `env/`, `deploy/`, `charts/`, `helm/`, `terraform/`, `k8s/`
   - `common/`, `shared/`, `core/` without main entry point → check for publish task → library if present, otherwise exclude

**Step 3: Topology presentation**

Present detected topology to user and wait for confirmation:

```
Found N repos: [services list] + [libraries list]. Running full analysis of each service.

Services:
  • order-service/     (Java/Spring Boot)
  • user-service/      (Java/Spring Boot)
  • frontend/          (React/TypeScript)

Libraries:
  • libraries/shared-core/   (Java, maven-publish)

Proceeding with full analysis of each service.
```

Wait for user to confirm or correct misclassifications before proceeding.

**Flow Summary:**

- **Single-project:** Phases 1b-1h run once for the whole repo.
- **Monorepo:** Phase 1b runs once (global scope), then Phases 1c-1h run once per service.
- **Workspace:** Phase 1b runs once per repo (no global scope), then new Phase 1c (graph construction) and Phase 1d (ecosystem injection) run once after all repos analyzed.

### Workspace parallelisation protocol (workspace mode only)

**Run immediately after presenting the topology (Step 3), before any per-repo work begins.**

**Step 1: Pre-create report directory**

```bash
mkdir -p "<workspace>/.claude/reports"
```

Create this directory before spawning any sub-agents. This is idempotent and must complete before fan-out.

**Step 2: Dispatch parallel sub-agents — one per service repo**

Spawn ALL service-repo sub-agents in a **single tool-call message** (one Agent invocation per repo, all in the same batch). Do NOT dispatch sequentially.

Library repos are NOT delegated — the orchestrator handles them directly with a lighter scan (identity, dependency list, publish target) and produces their per-repo report inline.

Sub-agent prompt template (fill in `<repo-path>`, `<report-path>`, `<workspace-root>` for each repo):

```
You are a code analysis agent. Analyse the service repo at:
  <repo-path>

Scope: run claudboard-analyse Phases 1b–1h scoped entirely to <repo-path>.
Load stack-detectors.md, run Wide Scan, Strategic Sampling, call-path tracing,
duplication detection, and existing .claude/ inventory exactly as specified in
the analyse SKILL.md. Do NOT analyse any other repo or the workspace root.

After completing analysis, write the FULL analysis report (including all Phase 2
content: What/How/Why/Quality Assessment/Proposed Artifacts/Workflow Signals)
to this exact absolute path BEFORE returning:
  <report-path>

Write ONLY to <report-path>. Do NOT also write to <repo-path>/.claude/reports/.
The workspace report directory is the single source of truth — per-repo copies
are not created in workspace mode.

The report MUST include this YAML frontmatter:
---
generated_at: <ISO 8601 timestamp>
repo: <repo-path>
workspace_member: true
workspace_root: <workspace-root>
version: "2.1.0"
---

After writing the file, return ONLY the following compact YAML summary block
(do not return the full report — the orchestrator has access to the file):

service_identity: <resolved service name>
inbound:
  rest_endpoints: <count>
  kafka_topics_consumed: [<topic>, ...]
  solace_topics_consumed: [<topic>, ...]
outbound:
  feign_clients: [<name>, ...]
  kafka_topics_produced: [<topic>, ...]
  solace_topics_produced: [<topic>, ...]
quality_avg: <X.X>
watch_top3:
  - <finding 1>
  - <finding 2>
  - <finding 3>
```

The orchestrator uses these YAML summaries for Phase 1c graph construction without re-reading all per-repo reports.

**Step 3: Write-verification and serial recovery**

After all sub-agents return, verify that every expected report file exists:

```bash
# Check for each expected repo report
ls "<workspace>/.claude/reports/claudboard-analysis-<repo-name>.md"
```

For any missing report file (sub-agent failed or returned without writing):
- Re-run that single repo's analysis serially (do not re-run the full batch)
- Use the same phases and report format
- Write the missing file before proceeding

Do NOT proceed to Phase 1c until all expected per-repo report files are confirmed on disk.

### 1b. Global scan (runs once for both single-project and monorepo)

**For single-project repos:** Standard parallel file detection for the whole repo.

**For monorepos:** Run only the global-scope detection here. Per-service detection happens in Phases 1c-1h.

In a single pass, check for all of the following in parallel:

**Build & dependency files:** `package.json`, `tsconfig.json`, `pom.xml`, `build.gradle`, `build.gradle.kts`, `settings.gradle`, `go.mod`, `pyproject.toml`, `requirements.txt`, `Cargo.toml`, `*.csproj`, `*.sln`, `Makefile`, `Taskfile.yml`, `gradle/libs.versions.toml`

**Container & infra:** `Dockerfile`, `docker-compose.yml`, `docker-compose.test.yml`, any `charts/` or `helm/` directory, `kustomization.yaml`, `Pulumi.yaml`, `terraform/`

**CI/CD:** `.github/workflows/*.yml`, `azure-pipelines.yml`, `Jenkinsfile`, `.gitlab-ci.yml`, `.circleci/config.yml`

**Existing Claude config:** `CLAUDE.md`, `.claude/rules/*.md`, `.claude/skills/*/SKILL.md`, `.claude/memories/*.md`, `.claude/settings.json`, `.mcp.json`

**Documentation:** `README.md`, `README`, `docs/adr/`, `ADR/`

**For monorepos, also extract globally:**
- Cross-service communication: shared event topics (Kafka, RabbitMQ), REST contract files (OpenAPI specs, Feign clients), shared proto definitions
- Shared library inventory: what each library exposes (from its build file / README)
- Branch strategy and commit conventions: from root README, `.git/config`, CI pipeline naming patterns
- Top-level directory structure (annotate each dir as service / library / infra / docs)

**For workspace mode, additionally extract per repo:**

Before running Phases 1c-1h for each repo, extract:

1. **Service identity** (task 3.3):
   - Follow `../claudboard/references/stack-detectors.md` → "Service Identity Resolution"
   - Primary: `spring.application.name` from `application.yml` or `application.properties`
   - Fallback: directory name
   - Record the resolved identity for graph construction

2. **Communication surface** (task 4.9):
   - Follow `../claudboard/references/stack-detectors.md` → "Cross-Service Surface Detection"
   - **Outbound REST:** `@FeignClient` names, `RestTemplate`/`WebClient` URLs, Axios/fetch URLs with service names
   - **Inbound REST:** `@RestController` paths, service identity
   - **Outbound Kafka:** `KafkaTemplate.send` topic literals, `@SendTo` values
   - **Inbound Kafka:** `@KafkaListener` topics
   - **Outbound Solace SCS:** `spring.cloud.stream.bindings.{channel}.destination` config values
   - **Inbound Solace SCS:** `@StreamListener` binding destinations (resolved from config)
   - **Outbound Solace JCSMP:** `Topic.of("...")` and `Queue.get("...")` literals; grep for constant definitions if topic is a constant; note unresolved constants
   - **Inbound Solace JCSMP:** `XMLMessageConsumer.addSubscription(Topic.of("..."))` values
   - Record all surface data for this repo (used in Phase 1c graph construction)

Skip: `node_modules/`, `.git/`, `dist/`, `build/`, `target/`, `__pycache__/`, `.venv/`, `vendor/`, `.gradle/`, `.idea/`

---

> **Monorepo mode — per-service loop:** For each detected **service** (not library), run Phases 1c through 1h independently, scoping all file paths and grep commands to the service's directory. Repeat the full Phase 1c-1h cycle for each service before moving to Phase 2.

> **Workspace mode — per-repo loop:** For each detected **service repo** (not library), run identity extraction + surface extraction (above), then Phases 1c through 1h independently, scoping all commands to that repo's directory. After all repos analyzed, proceed to new Phase 1c (graph construction).

---

### 1c. Discovery (wide scan + anti-patterns)

**Skip if repo has <50 source files** — read all source files directly in step 1d instead (skip the bash script invocation; go straight to 1d).

**In monorepo mode:** invoke the script once per service directory. Each service gets its own Pattern Inventory.

Run `bash scripts/discover.sh <repo-path>` as a **single tool call**, where `<repo-path>` is:
- **Single-project:** the repo root
- **Monorepo:** each service directory individually (after the global 1b scan)
- **Workspace sub-agent:** the repo path scoped to this agent's assigned repo

> **Schema assertion:** read `schema_version` from the JSON. If it does not equal `"1"`, stop immediately and report:
> `"discover.sh schema mismatch: got {observed}, expected 1. Check that scripts/discover.sh and this SKILL.md are at the same version (see scripts/schema/discover-v1.md for the bump procedure)."`

The JSON provides the Pattern Inventory for all subsequent phases:

| JSON field | Used for |
|---|---|
| `repo.source_file_count` | Skip 1c when < 50; skip 1g when < 30 |
| `wide_scan.skill_triggers` | Trigger → count + best_example; drive 1d file selection |
| `wide_scan.anti_patterns` | Flag in Phase 2 Watch; combine with 1f call-path findings |
| `wide_scan.conventions` | di_style, logging — confirm in 1d, record in Phase 2 |
| `wide_scan.god_class_candidates` | Priority files for 1d; "Complex business" path entry in 1f |
| `wide_scan.inheritance_map` | 1d abstract base class reads; workflow candidate detection |
| `duplication.candidates` | Phase 2 "Code duplication" line ([] when count < 30 — see 1g) |
| `ref_load_signals` | Which reference files to load (see Reference Load Gates below) |

**Still run manually (not covered by the script):**
- Project-specific workflows: read `README.md` "Getting Started"/"Contributing"; check `docs/adr/` or `ADR/`
- From `wide_scan.inheritance_map`: if a base class has 5+ subclasses, examine the most recent (by git log) to reconstruct the "add a new X" workflow — strong skill candidate
- Security, API surface, and observability interpretation: the script counts the signals; load the language-specific `stack-detectors-{lang}.md` for interpretation context (the file is already loaded at the start of Phase 1)

#### Reference Load Gates

After reading the discovery JSON, load these reference files **only when the signal is `true`**:

| Signal | Reference file | Load when |
|---|---|---|
| `ref_load_signals.messaging` | `../claudboard/references/edges/messaging.md` | any Kafka/AMQP/JMS/SNS/SQS/Solace/RabbitMQ marker found |
| `ref_load_signals.streaming` | `../claudboard/references/edges/streaming.md` | any WebSocket/SSE/RSocket marker found |
| `ref_load_signals.graphql` | `../claudboard/references/edges/graphql.md` | any GraphQL/Apollo marker found |
| `ref_load_signals.architectural` | `../claudboard/references/patterns/architectural.md` | any Saga/CQRS/Outbox/EventStore marker found |

`workflow-signals.md` is **always** loaded (dispatcher schema). `edges/sync-rpc.md` is **always** loaded in workspace mode for REST/gRPC edge detection.

#### Fallback (discover.sh unavailable)

If `scripts/discover.sh` is missing or errors (bash unavailable, jq not installed):

1. Run each grep listed in the language-specific `stack-detectors-{lang}.md` Wide Scan section manually
2. Record trigger counts, anti-pattern counts, and conventions from the grep output
3. Compute `ref_load_signals` by checking whether any messaging/streaming/graphql/architectural keyword appears in the repo
4. Proceed with the same Phase 1d onward, using the manually collected data in place of the discovery JSON

**Output: Pattern Inventory** (internal — use it to drive step 1d decisions):
```
inheritance_map: [base class → subclass count + sample files]  ← from wide_scan.inheritance_map
custom_annotations: [annotation name → usage count + files]   ← from wide_scan.skill_triggers
skill_triggers: [trigger → count + best_example file]         ← from wide_scan.skill_triggers
anti_patterns: [type → severity + count + files]               ← from wide_scan.anti_patterns
god_class_candidates: [file → LOC]                            ← from wide_scan.god_class_candidates
conventions: {di_style, logging, test_naming}                  ← from wide_scan.conventions
security, api_surface, observability, dependency_deep          ← interpret from trigger counts + stack-detectors-{lang}.md
workflows: [workflow name → steps → files → source]           ← from README/ADR manual reads
```

### 1d. Strategic sampling

**For repos <50 source files:** Read all source files — no sampling needed.

**For repos ≥50 source files:** Use the Pattern Inventory from step 1c to select files purposefully. Every file read has a reason.

**File selection algorithm** (apply in priority order until budget exhausted):

1. **All abstract base classes** with 3+ subclasses — these are the architecture backbone
2. **All custom `@interface` annotation declarations** — project-specific patterns are invisible without them
3. **Top 3 God class candidates** (largest LOC) — confirm anti-pattern, understand scope
4. **Best example per detected skill trigger** — pick the *smallest, cleanest* file with that trigger; it becomes the template for the generated skill
5. **Top 3 git hotspots** (if git history available): `git log --since=3.months --name-only --format="" | sort | uniq -c | sort -rn | head -10` — active code = important code
6. **1 representative test file** per test framework detected

**File budget by repo size:**

| Repo size | Max files to read fully |
|-----------|------------------------|
| <50 source files | All (no sampling) |
| 50-200 | 25 |
| 200-500 | 20 |
| 500+ | 15 |

**For monorepos with M services:**
- If M ≤ 3: use full budget per service
- If M > 3: allocate budget proportionally across services (e.g., 15-file budget split as 5 files per service for 3 services)

**Record the reason for each file selected** (used in Phase 2 reporting):
- "AbstractDataEntity.java — base class with 43 subclasses"
- "CanvasService.java — God class candidate at 609 LOC"
- "NoteController.java — best example of @RestController trigger (21 lines, cleanest)"

From each file, detect:
- Naming conventions (classes, methods, files)
- Dependency injection pattern (constructor vs field)
- Error handling approach (exceptions, Result types, Optional)
- Logging framework and format pattern
- Architecture layering (from directory/package names AND import patterns)
- Any `TODO/FIXME/HACK` comments

### 1e. Test strategy detection

Check for test framework, test directories, coverage tooling, and whether tests appear in CI pipeline. See `../claudboard/references/quality-signals.md` → "Testing" checklist.

**In monorepo mode:** detect test frameworks, coverage tooling, and CI gate independently per service — scoped to the current service's directory and CI job. A service using JUnit 5 and a service using Spock should each be recorded separately.

### 1f. Call-path tracing

File sampling catches naming conventions and structure but misses flow anti-patterns — duplication across call chains, reflection in the hot path, exception handling strategies that only become visible when you follow the full operation.

Trace exactly the path types whose "When to include" condition is satisfied by the discovery JSON. Do not pad to a fixed count.

| Path type | When to include | Entry point | What it reveals |
|-----------|----------------|-------------|-----------------|
| Simple CRUD | Always | Smallest controller | Happy path, base patterns |
| Complex business | Always (or skip if `wide_scan.god_class_candidates` is empty) | Method in largest service | Real complexity, edge cases |
| Async/event | `wide_scan.skill_triggers["@Async"].count > 0` OR `"@EventListener".count > 0` | Async method or listener | Error handling in async, threading |
| Auth/security | `wide_scan.skill_triggers["SecurityFilterChain"].count > 0` OR any custom auth annotation | Annotated controller → aspect | AOP patterns, security flow |
| External integration | `wide_scan.skill_triggers["@FeignClient"].count > 0` OR any HTTP client trigger | Client call chain | Resilience, error mapping |

Expected path counts: 2 paths on simple repos, up to 5 on full-feature repos.

For each path, trace end-to-end: controller → service → helpers/callbacks → repository. Read each file in the chain. Record per path:

- **DI pattern:** constructor vs field vs property injection
- **Exception handling:** specific vs broad catch, wrap-and-rethrow vs propagate, log-and-throw
- **Logging:** framework, levels used, structured vs plain
- **Validation:** where it happens (controller vs service vs domain)
- **Reflection:** any `ReflectionUtils`, `getDeclaredField`, `setAccessible` in the hot path (see `../claudboard/references/pattern-catalog.md` → "Reflection Anti-Patterns")
- **Duplicated logic:** same method body across parallel hierarchies
- **Defensive code:** try-catch inside lambdas, silent null guards repeated everywhere

### 1g. Duplication detection

**Skip entirely when `repo.source_file_count < 30`** (from discovery JSON). Small repos have insufficient surface area to harbour copy-paste duplication; record `"Code duplication: None detected"` in Phase 2 without running any greps.

For repos ≥ 30 source files: use `duplication.candidates` from the discovery JSON as the primary input — the script pre-computed recurring patterns. If the list is non-empty, review the top candidates by reading the referenced files and confirming they represent genuine duplication (not false-positive regex matches).

Also check for parallel class hierarchies: classes with shared naming patterns (e.g., `Root*Service`, `Branch*Service`, `Leaf*Service`). If found, diff key methods across hierarchies — identical or near-identical method bodies indicate structural duplication.

### 1h. Existing `.claude/` inventory

If `.claude/` exists:
- List all existing rules (filenames + `paths:` globs)
- List all existing skills (names)
- Note what's covered — this feeds into the Proposed Artifacts section

---

### NEW PHASE 1c: Cross-Service Dependency Graph Construction (workspace mode only)

**Run this phase ONLY in workspace mode**, after all per-repo analyses (Phases 1b-1h) are complete for every service repo.

Using the service identity and communication surface data extracted in Phase 1b, build a directed dependency graph.

**Step 1: Match outbound references against inbound surfaces** (task 5.1)

For each repo A:
  For each outbound reference in A:
    For each repo B (where B ≠ A):
      - **REST match:** outbound FeignClient `name` or URL segment contains B's identity → edge A→B (REST)
      - **Kafka match:** outbound producer topic name equals B's inbound consumer topic name (exact string match) → edge A→B (Kafka)
      - **Solace match:** outbound SCS/JCSMP topic equals B's inbound SCS/JCSMP topic (exact string match) → edge A→B (Solace)
      - **No match:** record as "external dependency (unresolved)" → A → `[service-name] (external)` (task 5.2)

**Step 2: Classify coupling strength per edge** (task 5.3)

For each edge in the graph:

| Edge Type | Coupling Strength | Condition |
|-----------|------------------|-----------|
| REST | **TIGHT** | No `@CircuitBreaker`, `@Retry`, or Resilience4j config detected in caller |
| REST | **MODERATE** | `@CircuitBreaker`, `@Retry`, or Resilience4j config detected in caller |
| Kafka/Solace async | **LOOSE** | Always |
| Shared DB | **TIGHT** | Same DB connection string in multiple repos (if detected) |

Grep for resilience patterns in the calling repo:
```bash
# Circuit breaker detection
grep -r '@CircuitBreaker\|@Retry\|resilience4j' --include='*.java' src/

# Feign client resilience config
grep -r 'feign.circuitbreaker.enabled' --include='*.yml' --include='*.properties' .
```

**Step 3: Detect compound patterns** (tasks 5.4-5.5)

- **Synchronous chain** (task 5.4): A→B→C where all edges are REST/TIGHT
  - Flag: "Latency amplification and failure cascade risk — synchronous chain: A→B→C"

- **Circular dependency** (task 5.5): A→B→A (any protocol)
  - Flag: "Circular dependency — architectural risk: A ↔ B"

**Step 4: Present graph for review** (task 5.6)

Display the full graph to the user with edges, coupling classifications, and warnings:

```
Cross-Service Dependency Graph:

Edges:
  order-service ──REST/TIGHT──▶ user-service
  order-service ──Kafka/LOOSE──▶ notification-service
  user-service ──REST/MODERATE──▶ auth-service
  frontend ──REST/TIGHT──▶ order-service
  frontend ──REST/TIGHT──▶ user-service

External Dependencies (unresolved):
  order-service → payment-gateway (REST, not in workspace)

Warnings:
  ⚠ TIGHT: order-service → user-service (REST, no circuit breaker)
  ⚠ TIGHT: frontend → order-service (REST, no circuit breaker)

Proceed with ecosystem injection? [y/n/edit]
```

Wait for user confirmation before proceeding to Phase 1d.

If user selects "edit" or indicates corrections, adjust the graph and re-present.

---

### NEW PHASE 1d: Ecosystem Context Injection (workspace mode only)

**Run this phase ONLY in workspace mode**, after user confirms the graph in Phase 1c.

> **Authorship:** ecosystem.md files are written by the **orchestrator** during this phase, NOT by per-repo sub-agents — sub-agents have no graph context.

For each **service repo** (not library repos, not workspace root):

**Step 1: Write `.claude/memories/ecosystem.md`** (task 6.1)

Path: `<repo-dir>/.claude/memories/ecosystem.md`

Skip:
- Library repos (excluded from service list in Phase 1a)
- Workspace root directory (no file written there)

**Step 2: Populate file content** (tasks 6.2-6.7)

```markdown
<!-- Managed by claudboard — do not edit manually. Run /refresh from workspace root to update. -->

# Ecosystem Context: <service-name>

## Role

<one sentence describing this service's position and purpose in the ecosystem, inferred from its inbound/outbound surface and name>

## Depends On

| Service | Protocol | Purpose | Source File |
|---------|----------|---------|-------------|
| <target> | REST (sync) | <inferred purpose> | <FeignClient file or RestTemplate usage file> |
| <target> | Kafka (async) | <inferred purpose> | <producer class> |
| <target> | Solace (async) | <inferred purpose> | <publisher class or config> |
| <external-service> | REST | [external — not in workspace] | <source file> |

## Used By

| Service | Protocol | How |
|---------|----------|-----|
| <caller> | REST | <endpoint paths called> |
| <caller> | Kafka | consumes topic: <topic-name> |
| <caller> | Solace | consumes topic: <topic-name> |

## Shared Contracts

**Kafka/Solace Topics:**
- `topic-name` (producer/consumer) — <schema file if detected, otherwise "schema not detected">

**OpenAPI Spec:**
- `<path-to-openapi-spec>` (if detected via `springdoc-openapi` or manual `openapi.yaml`)

## Coupling Warnings

⚠ **TIGHT:** REST call to <target-service> has no circuit breaker — if <target> is unavailable, <this-service> fails (file: <source>)

⚠ **TIGHT:** <caller-service> calls this service synchronously with no circuit breaker

⚠ **Synchronous chain:** <service-a> → <this-service> → <service-b> — latency amplifies, failure cascades

⚠ **Circular dependency:** <this-service> ↔ <other-service>
```

**Content population rules:**

- **Role** (task 6.3): Infer from service name, inbound/outbound count, and protocol types (e.g., "order-service is the core transactional service, handling order creation and exposing REST endpoints to frontend; publishes order events to Kafka")
- **Depends On** (task 6.4): One row per outbound edge; for external unresolved deps, mark as `[external — not in workspace]`
- **Used By** (task 6.5): One row per inbound edge from the graph
- **Shared Contracts** (task 6.6): List unique topics this service publishes or consumes; detect OpenAPI spec from `@OpenAPIDefinition` or `springdoc.api-docs.path` config or `openapi.yaml` file presence
- **Coupling Warnings** (task 6.7): List all TIGHT edges involving this service (both as caller and callee), synchronous chains, circular dependencies

---

### NEW: Workflow Signals & Architectural Pattern detection (run once per project/service)

After Wide Scan, compute workflow signals and detect architectural patterns. These are lightweight computations that piggyback on Phase 1 data.

Load `../claudboard/references/workflow-signals.md` for the schema, sub-catalog pointers, and detection heuristics.

**Workflow Signals — detect and record:**
1. **Cross-service edges** — from Wide Scan transport hits; load `edges/sync-rpc.md`, `edges/messaging.md`, `edges/streaming.md`, `edges/graphql.md` for per-transport extraction rules (workspace mode only; in single-repo mode emit `cross_service_edges: []`)
2. **Shared libraries** — from dependency analysis (workspace/monorepo mode only)
3. **Auth perimeter** — from security scan results in Wide Scan
4. **Ticket prefix** — from `git log --oneline -50` and `git branch -a` (run these commands)

**Architectural Pattern detection — always run (single-repo and workspace modes):**

Load `../claudboard/references/patterns/architectural.md` for detection rules and minimum-signal thresholds.

Run pattern detection in parallel:
- Saga (orchestration + choreography)
- CQRS
- Outbox
- BFF (workspace mode only — requires sibling service context from graph)
- API Composition
- Circuit Breaker
- Schema Registry
- AsyncAPI

Apply "empty evidence → no entry" rule: if a pattern's minimum-signal threshold is not met, omit it from the `architectural_patterns` list entirely.

These signals feed the "### Workflow Signals" and "### Architectural Patterns" subsections in the analysis report (Phase 2).

---

## Phase 2: Analysis Report

Present findings to the user. Use **WHAT / HOW / WHY / CONCERNS** structure.

Load `../claudboard/references/pattern-catalog.md` to identify architecture patterns and anti-patterns. Load `../claudboard/references/quality-signals.md` to score quality dimensions and decide rule depth.

**For monorepos:** produce one global report section plus one per-service section (same structure). See "Monorepo Report Structure" below.

### Report format

Load `../claudboard/references/report-template.md` for the exact section structure, field formats, YAML blocks, and template placeholders. Follow the template precisely.

Key format rules (do NOT deviate):
- Quality scores are whole numbers 1-10; use scoring criteria from `quality-signals.md`
- The `### Workflow Signals` YAML block is always emitted, even when all values are empty/unknown
- `architectural_patterns: []` when no pattern meets its minimum-signal threshold
- Code duplication: "None detected" when `repo.source_file_count < 30` (no disclaimer)
- After listing Watch findings, apply compound severity rules from `pattern-catalog.md`
- Skill dedup check required before finalizing proposed skills list

---

Present all sections to the user.

If patterns are ambiguous or inconsistent, ask the user now — e.g.:
- "Found both field injection and constructor injection — which should be the standard?"
- "Naming conventions vary between modules — document the predominant pattern or leave as TODO?"
- "Skills X and Y overlap — merge into one or keep separate?"

---

## Phase 3: Save Report & Next Steps

**Execute these steps in order. Do not skip or reorder. Do not ask the user anything until step 3 is complete.**

All saved files must include YAML frontmatter:

```yaml
---
generated_at: <ISO 8601 timestamp>
repo: <absolute path to project root>
version: "2.1.0"
---
```

### Step 1: Create the reports directory

Create the reports directory before writing any file. This is idempotent — safe to run even if the directory exists.

- **Single-project / monorepo:** `mkdir -p <project-root>/.claude/reports`
- **Workspace:** `mkdir -p <workspace>/.claude/reports`

### Step 2: Write report file(s) using the Write tool

**Use the Write tool to create each file. Displaying the analysis content to the user does NOT substitute for writing the file to disk.**

**Single-project:** Write the full report to `.claude/reports/claudboard-analysis.md`.

**Monorepo:** Write two levels:
- `.claude/reports/claudboard-analysis.md` — global report (topology, CI/CD, cross-service patterns, per-service summary table, proposed global artifacts). Frontmatter additionally includes `monorepo: true` and `services: [<dir-name>, ...]`.
- `.claude/reports/claudboard-analysis-<dir-name>.md` — one per detected service (e.g., `claudboard-analysis-order-service.md`). Use the service's directory name as-is — no transformation.

Write the global report first, then each per-service report. All writes complete before Step 3.

**Workspace:**
- Verify all per-repo sub-agent reports exist in `<workspace>/.claude/reports/` (written during the Phase 1a parallelisation protocol). If any are missing, recover them serially before proceeding.
- Write `<workspace>/.claude/reports/claudboard-analysis-workspace.md` — global workspace summary (topology table, cross-service dependency graph, per-repo summary table with quality scores, global Watch findings, proposed global artifacts). Frontmatter includes `workspace: true`, `repos: [<service-dir-name>, ...]`, and `libraries: [<library-dir-name>, ...]`.
- Per-repo reports were written by sub-agents — do NOT re-write them here. Only the workspace summary is written in this step.

Each per-repo sub-agent report frontmatter must include `workspace_member: true` and `workspace_root: <absolute workspace path>`.

**If any Write tool call fails** (permission error, disk full, path conflict): report the error to the user and stop. Do not proceed to Step 3. Do not claim the analysis is saved.

### Step 3: Confirm save and ask about generation

After all writes succeed, confirm to the user:

> Analysis saved to:
> - `.claude/reports/claudboard-analysis.md` (single-project / monorepo)
> - or list all written paths (workspace)

Then ask:

> Would you like to generate artifacts now, or run `/generate` in a fresh session? (Fresh session recommended — analysis fills context with discovery data not needed during generation.)

- If user chooses to generate now: proceed with `../claudboard-generate/SKILL.md` steps starting from Phase 2 (skip Phase 1 report loading — you already have the data).
- If user defers: end with "Run `/generate` in a fresh session when ready. For tech debt analysis, run `/techdebt`."

---

## Error Handling

| Condition | Behavior |
|-----------|----------|
| Target path doesn't exist | Report error with path and stop |
| No source files found | Report "no source files found at [path]", suggest checking the path, stop |
| Grep command returns no results | Continue — report "none detected" for that category |
| Build file not recognized | Note "unrecognized project type" and proceed with structure-based analysis |

## Constraints

- **Read-only for source code.** Files written depend on mode: single-project writes `.claude/reports/claudboard-analysis.md`; monorepo additionally writes `.claude/reports/claudboard-analysis-<service>.md` per service; workspace writes `<workspace>/.claude/reports/claudboard-analysis-workspace.md` plus `<workspace>/.claude/reports/claudboard-analysis-<repo>.md` per service repo (by sub-agents) and `<repo>/.claude/memories/ecosystem.md` per service repo (by orchestrator). In workspace mode, per-repo `.claude/reports/` directories are NOT written — the workspace report directory is the single source of truth.
- **Never modify source code, tests, or existing files.**
- **Max ~50 source files read** for large repos — note sampling in report.
- **Secrets found during scan:** Report file:line only, never print the value.
- **If path doesn't exist:** State clearly and stop.

## Reference Files

| File | When to load |
|------|-------------|
| `../claudboard/references/stack-detectors.md` | Start of Phase 1 — shared detection heuristics |
| `../claudboard/references/stack-detectors-{lang}.md` | Phase 1c — load language-specific file (java, typescript, python, go, rust, or dotnet); trigger and anti-pattern catalogs live there |
| `../claudboard/references/pattern-catalog.md` | Phase 2 — pattern/anti-pattern identification |
| `../claudboard/references/quality-signals.md` | Phase 2 — quality scoring, rule depth, skill triggers |
| `../claudboard/references/workflow-signals.md` | Phase 1 (after Wide Scan) — always load; workflow signal schema, sub-catalog pointers, shared-lib and auth-perimeter detection |
| `../claudboard/references/edges/sync-rpc.md` | Phase 1 — always load in workspace mode; REST/gRPC/tRPC transport extraction |
| `../claudboard/references/edges/messaging.md` | **Gated:** load only when `ref_load_signals.messaging == true` |
| `../claudboard/references/edges/streaming.md` | **Gated:** load only when `ref_load_signals.streaming == true` |
| `../claudboard/references/edges/graphql.md` | **Gated:** load only when `ref_load_signals.graphql == true` |
| `../claudboard/references/patterns/architectural.md` | **Gated:** load only when `ref_load_signals.architectural == true` |

## Discovery Script

`scripts/discover.sh` — runs Phase 1b (global file scan), Phase 1c (wide scan), and Phase 1g (duplication detection) as a single bash invocation. Emits a versioned JSON document consumed by Phase 1c.

**Schema version:** `"1"` (see `scripts/schema/discover-v1.md` for field semantics and the schema-bump procedure).

**Language packs:** `scripts/lang/{java,typescript,python,go,rust,dotnet}.sh` — per-language grep sets dispatched from `discover.sh`. Add a new file here to add a language; update `SCHEMA_VERSION` in `discover.sh` if any new JSON field is added.
