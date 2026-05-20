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

### 1c. Wide Scan (pattern inventory)

**Skip if repo has <50 source files** — read all source files directly in step 1d instead.

**In monorepo mode:** scope all grep and find commands to the current service's directory (e.g., `find order-service/src/main -name '*.java'` not `find . -name '*.java'`). Each service gets its own Pattern Inventory.

Run grep-based scans across the entire repo before reading any source file fully. Load the language-specific file from `../claudboard/references/` (e.g., `stack-detectors-java.md` for Java/Kotlin projects, `stack-detectors-typescript.md` for TypeScript/JavaScript, etc.) for exact grep commands per language. Each file contains 7 categories: custom patterns, anti-patterns, conventions, security, API surface, observability, and dependencies. If any category returns 0 results, record "none detected" and continue with other categories.

Run in parallel:

**Inheritance & abstraction map** (find project-specific patterns):
```
# Custom annotations (project-specific!)
grep -rn '@interface' --include='*.java' src/
grep -rn '@interface' --include='*.kt' src/

# Abstract base classes
grep -rn '^public abstract class\|^abstract class' --include='*.java' src/

# Who extends what (inheritance tree)
grep -rn 'extends ' --include='*.java' src/ | grep -v '//' | grep -v 'test\|Test'

# TypeScript
grep -rn 'abstract class\|extends ' --include='*.ts' src/

# Python
grep -rn 'class.*ABC\|class.*Protocol\|class.*BaseModel' --include='*.py' src/
```

Tally results: if N >= 3 classes extend the same base class → **that base class is a skill candidate**. If a custom annotation appears on 3+ classes → **that annotation is a rule candidate**.

**Project-specific workflows** (highest-value patterns — invisible to grep):
- Read `README.md` "Getting Started"/"Contributing" sections for documented rituals
- Check `docs/adr/` or `ADR/` for architecture decision records describing multi-step workflows
- From inheritance map: if a base class has 5+ subclasses, examine the most recent (by git log) to reconstruct the "add a new X" workflow — strong skill candidate
- Record: workflow name → steps → files involved → "discovered from [source]"

**Skill trigger signals** (full catalog — run all in parallel):
```
# Java / Spring
@RestController, @Controller, @FeignClient
@KafkaListener, @KafkaHandler, @RabbitListener
@Repository, @Document (MongoDB)
@Scheduled, @EnableScheduling
@Async, @EnableAsync, CompletableFuture
@EventListener, ApplicationEvent
@Aspect, @Around, @Before, @After
@MessageMapping (WebSocket)
@GraphQlController, @QueryMapping, @MutationMapping
@ShellComponent (Spring Shell CLI)
implements Validator, ConstraintValidator (custom validators)
SecurityFilterChain, @EnableMethodSecurity
@FeignClient

# Frontend (TypeScript/React)
useQuery, useMutation (React Query)
useState, useEffect (custom hook signal)
react-hook-form, useForm
zustand, create( (Zustand)
createSlice, createAsyncThunk (Redux Toolkit)
ModuleFederationPlugin (Micro-Frontends)

# Python
@app.route, @router.get, @router.post (FastAPI/Flask)
@tool, tool_use (MCP tools)
class.*Model (Pydantic)
class.*Task, @celery.task (Celery)

# Infrastructure
V\d+__.*\.sql, *.migration.ts (DB migrations)
charts/, helm/ (Helm)
Pulumi.yaml, index.ts in env/ (Pulumi IaC)
```

Record: trigger name → file count → best example file (smallest/cleanest = best template).

**Anti-pattern signals** (whole-repo grep — not just sampled files):
```
# God class candidates (>300 LOC in src/main or equivalent)
find . -name '*.java' -path '*/src/main/*' -not -path '*/test/*' \
  | xargs wc -l 2>/dev/null | sort -rn | head -20

# Field injection (Java)
grep -rc '@Autowired' --include='*.java' src/main/

# Broad exception catching
grep -rn 'catch (Exception\|catch (Throwable' --include='*.java' src/main/

# Null returns
grep -rn 'return null;' --include='*.java' src/main/

# Reflection in business logic
grep -rn 'ReflectionUtils\|getDeclaredField\|setAccessible\|Method\.invoke\|ParameterizedType' \
  --include='*.java' src/main/

# TODO/FIXME/HACK density
grep -rc 'TODO\|FIXME\|HACK' --include='*.java' --include='*.ts' --include='*.py' src/ \
  | grep -v ':0$'

# TypeScript `any` usage
grep -rn '\bany\b\|// @ts-ignore\| as any\b' --include='*.ts' src/
```

**Convention frequency** (DI style, logging, naming consistency):
```
# Java DI ratio
FIELD_INJ=$(grep -rc '@Autowired' --include='*.java' src/main/ | awk -F: '{s+=$2}END{print s}')
CONST_DI=$(grep -rc 'private final' --include='*.java' src/main/ | awk -F: '{s+=$2}END{print s}')

# Logging style (Java)
grep -rl '@Slf4j' --include='*.java' src/ | wc -l
grep -rl 'LoggerFactory.getLogger' --include='*.java' src/ | wc -l
```

Also run security, API surface, and observability scans **in the same parallel pass** — these are included in the language-specific file you loaded for Wide Scan patterns (categories 4-6). Record findings alongside anti-patterns.

**Output: Pattern Inventory** (internal — use it to drive step 1d decisions):
```
inheritance_map: [base class → subclass count + sample files]
custom_annotations: [annotation name → usage count + files]
skill_triggers: [trigger → count + best_example file]
anti_patterns: [type → severity + count + files]
god_class_candidates: [file → LOC]
conventions: {di_style, logging, test_naming}
security: {framework, method_level_auth, cors, custom_auth_annotation, auth_coverage_gap}
api_surface: {total_endpoints, by_method, versioning, openapi_tooling}
observability: {actuator, metrics, tracing, structured_logging}
dependency_deep: {bom, sbom, conflict_resolution, cross_module_mismatches}
workflows: [workflow name → steps → files → source]
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

**Trace 3-5 paths** (not just one). Select based on Wide Scan findings:

| Path type | When to include | Entry point | What it reveals |
|-----------|----------------|-------------|-----------------|
| Simple CRUD | Always | Smallest controller | Happy path, base patterns |
| Complex business | Always | Method in largest service (God class) | Real complexity, edge cases |
| Async/event | @Async or @EventListener detected | Async method or listener | Error handling in async, threading |
| Auth/security | Custom auth annotations detected | Annotated controller → aspect | AOP patterns, security flow |
| External integration | @FeignClient or HTTP client detected | Client call chain | Resilience, error mapping |

For each path, trace end-to-end: controller → service → helpers/callbacks → repository. Read each file in the chain. Record per path:

- **DI pattern:** constructor vs field vs property injection
- **Exception handling:** specific vs broad catch, wrap-and-rethrow vs propagate, log-and-throw
- **Logging:** framework, levels used, structured vs plain
- **Validation:** where it happens (controller vs service vs domain)
- **Reflection:** any `ReflectionUtils`, `getDeclaredField`, `setAccessible` in the hot path (see `../claudboard/references/pattern-catalog.md` → "Reflection Anti-Patterns")
- **Duplicated logic:** same method body across parallel hierarchies
- **Defensive code:** try-catch inside lambdas, silent null guards repeated everywhere

### 1g. Duplication detection

After sampling source files, pick 2-3 distinctive code patterns seen in the first files (e.g., a try-catch inside a lambda, a reflection call sequence, a validation block). Grep for them across the codebase. If the same ~5-line pattern appears 3+ times in different files, flag as "copy-paste duplication" in the anti-patterns section.

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

### Single-project report template

```
## Project Analysis: <repo-name>

### What (purpose & value)
<inferred from README, package names, API surface, domain vocabulary in code>

### How (design & patterns)
- Architecture: <pattern name> — detected from <specific evidence>
- Build: <commands> — from <source file>
- Testing: <framework + strategy> — <CI gate status>
- CI/CD: <platform> — <stages/jobs detected>
- Deploy: <model> — <IaC tool if detected>

### Why (reasoning behind decisions)
- <detected constraint → inferred decision>
  e.g., "Azure Pipelines → team is on Azure; Pulumi TypeScript → IaC in same language as app code"

### Quality Assessment

Score each dimension 1-10 (whole numbers only) using criteria from `../claudboard/references/quality-signals.md`.

**Testing:** [N]/10
Evidence: [framework, CI gate, coverage %]

**Architecture:** [N]/10
Evidence: [pattern name, consistency]

**Conventions:** [N]/10
Evidence: [linting enforcement, DI pattern, god classes, anti-patterns]

**Dependencies:** [N]/10
Evidence: [versions, BOM status, SBOM, cross-module mismatches]

**CI/CD:** [N]/10
Evidence: [pipeline stages, quality gates, deploy automation]

**Documentation:** [N]/10
Evidence: [README, CLAUDE.md, ADRs, inline docs]

**Security:** [N]/10
Evidence: [framework, method-level auth coverage, CORS, secrets]

**Observability:** [N]/10
Evidence: [actuator, metrics, tracing, structured logging]

**API Surface:**
- Controllers: N | Endpoints: ~M (GET:X POST:Y PUT:Z DELETE:W)
- Versioning: [URL-based v1/v2 / None detected]
- Documentation: [springdoc-openapi / springfox / None]

**Reflection usage:** [None / Config-only / Business-logic (flag)] — from Phase 1c grep
**Code duplication:** [None detected / Minor / Structural (parallel hierarchies)] — from Phase 1g

**Quality Score Summary:**

| Dimension | Score | Evidence |
|-----------|-------|----------|
| Testing | [N]/10 | [1-line] |
| Architecture | [N]/10 | [1-line] |
| Conventions | [N]/10 | [1-line] |
| Dependencies | [N]/10 | [1-line] |
| CI/CD | [N]/10 | [1-line] |
| Documentation | [N]/10 | [1-line] |
| Security | [N]/10 | [1-line] |
| Observability | [N]/10 | [1-line] |
| **Average** | **[X.X]/10** | |

**Adaptive Depth Decision:** [≥7.0 avg] → Full rules | [4.0-6.9 avg] → Medium rules | [<4.0 avg] → Skeleton rules

**Preserve:**
- <good pattern> — <where found>

**Watch:**
- [SEVERITY] <anti-pattern> — <file/location>
Include findings from Phase 1f (call-path tracing) and Phase 1g (duplication detection).
For severity assignment, use the **Overview** column from `../claudboard-techdebt/references/severity-matrix.md`.
For reflection or deeply-embedded anti-patterns: note whether they belong
in conventions rules (actionable today) or tech-debt rules (document but
can't avoid in current architecture). See pattern-catalog.md →
"Reflection Anti-Patterns" → "Reporting guidance".

After listing all Watch findings, **apply compound severity rules** from `../claudboard/references/pattern-catalog.md` → "Compound Severity Rules" (analyse-scoped rules):
- Check each pair of Watch findings against the compound severity table
- For any matching pair, add a compound entry: `[HIGH — compound] Finding A + Finding B → risk description (individually: severityA + severityB)`

**Debt:**
- [INFO] <tech debt> — <impact>

### Existing .claude/ Coverage
[If .claude/ exists:]
- `<existing rule>` — covers <X>
- `<existing skill>` — covers <Y>

[If no .claude/:]
- No existing Claude context found

### Workflow Signals

```yaml
workflow_signals:
  cross_service_edges:
    - {family: sync-rpc, protocol: feign, type: feign, direction: outbound, target: "<service-name>", schema_ref: null}
    - {family: sync-rpc, protocol: http,  type: http,  direction: outbound, target: "<url-or-unknown>", schema_ref: null}
    - {family: messaging, protocol: kafka, type: kafka, direction: outbound, target: "<topic-name>", schema_ref: null}
    - {family: sync-rpc, protocol: grpc,  type: grpc,  direction: inbound,  target: "<service-name-or-unknown>", schema_ref: "path/to/file.proto"}
  shared_libraries:
    - {name: "<artifactId-or-package>", consumer_count: <N>}
  auth_perimeter: "gateway|in-service-jwt|none|unknown"
  ticket_prefix: "PROJ|null"
```

[Emit this block even if all signals are empty/unknown — the subsection must always be present]

### Architectural Patterns

```yaml
architectural_patterns:
  - {type: saga, style: orchestration, evidence: ["path/to/orchestrator.java:42"]}
  - {type: circuit-breaker, library: resilience4j, evidence: ["path/with/@CircuitBreaker:88"]}
  - {type: schema-registry, vendor: confluent, evidence: ["application.yml:schema.registry.url"]}
```

[Emit `architectural_patterns: []` when no patterns are detected. Omit any entry whose minimum-signal threshold is not met (empty evidence → no entry). BFF detection is workspace-only.]

### Proposed Artifacts

**CLAUDE.md** — [outline: commands table, architecture bullets, rules/skills index, critical rules count]
[If existing: "Will add [X] to existing CLAUDE.md — preserving current content"]

**Rules (N files):**
- `<filename>.md` (paths: `<glob>`) — <what it covers, adaptive depth: full/medium/skeleton>

**Skills (M to generate):**

Before listing skills, **run skill dedup check** (see `../claudboard/references/quality-signals.md` → "Skill Deduplication"):
- Compare each pair of proposed skills for file glob overlap >50% or shared trigger annotations
- If overlap found, present it explicitly:
  ```
  **Skill overlap detected:**
  - `skill-a` and `skill-b` share: [overlapping globs or triggers]
    → Merge into one skill or keep separate with distinct scopes?
  ```
- Wait for user decision before listing final skill set
- Document decision in the skill descriptions

[If no overlap or after user resolves overlap:]
- `<skill-name>/` — <what triggers it, what it creates, full scope: SKILL.md + references/ + scripts/>

[If existing .claude/ found:]
**Already covered (no action):**
- `<existing rule>` — no gaps detected
- `<existing skill>` — already defined

### Context Overhead Estimate

| Artifact | Est. lines | Est. tokens |
|----------|-----------|-------------|
| CLAUDE.md | ~N | ~X |
| Rules (M files) | ~N total | ~X |
| Skills (K dirs) | ~N total | ~X |
| **Total persistent** | **~N** | **~X** |

(CLAUDE.md always loaded; rules loaded when paths: globs match; skill refs loaded on-demand.
See `../claudboard/references/quality-signals.md` → "Token Estimation Guide" for heuristics.)
```

---

### Monorepo report structure

For monorepos, produce **two levels** of report content:

**Global report** (covers the whole repo — CI/CD, shared libs, cross-service patterns):

```
## Project Analysis: <repo-name> (Monorepo)

### What (purpose & value)
<repo-level purpose>

### Monorepo Topology
| Service | Stack | Directory | Purpose |
|---------|-------|-----------|---------|
| <name> | <stack> | `<dir>/` | <1-phrase> |

| Library | Directory | Consumed by |
|---------|-----------|-------------|
| <name> | `<dir>/` | [services] |

### How (global — applies to all services)
- CI/CD: <platform> — <stages/jobs>
- Deploy: <model> — <IaC tool>
- Branch strategy: <detected pattern>
- Commit conventions: <detected format>
- Cross-service communication: <event bus / REST contracts if detected>

### Per-Service Summary

| Service | Testing | Architecture | Conventions | Avg Score |
|---------|---------|--------------|-------------|-----------|
| <name> | [N]/10 | [N]/10 | [N]/10 | [X.X]/10 |

**Quality variance:** [e.g., "Testing: 2/3 services scored 7+, 1/3 scored 4-6 — variance noted"]
**Adaptive Depth:** [determined per service from average scores — see per-service reports]

### Global Watch
- [SEVERITY] <cross-service anti-pattern> — <evidence>

### Proposed Global Artifacts
**CLAUDE.md** — monorepo variant (services table, per-service commands, shared libs, global conventions)
**Rules (global, no paths:):**
- `ci-cd.md` — CI/CD and deployment conventions (applies everywhere)
- `gitops.md` — IaC and GitOps constraints (applies everywhere) [if detected]
```

**Per-service report** (one per detected service):

```
## Service Analysis: <service-name>

### Stack & Versions
<stack, key dependencies, detected versions>

### Quality Assessment
[Same 1-10 scoring table as single-project, scoped to this service]

**Average:** [X.X]/10

**Adaptive Depth Decision:** [≥7.0] → Full | [4.0-6.9] → Medium | [<4.0] → Skeleton

### Preserve / Watch
[Same format as single-project, scoped to this service]

### Workflow Signals

```yaml
workflow_signals:
  cross_service_edges:
    - {family: sync-rpc, protocol: feign, type: feign, direction: outbound, target: "<service-name>", schema_ref: null}
    - {family: sync-rpc, protocol: http,  type: http,  direction: outbound, target: "<url-or-unknown>", schema_ref: null}
    - {family: messaging, protocol: kafka, type: kafka, direction: outbound, target: "<topic-name>", schema_ref: null}
    - {family: sync-rpc, protocol: grpc,  type: grpc,  direction: inbound,  target: "<service-name-or-unknown>", schema_ref: "path/to/file.proto"}
  shared_libraries:
    - {name: "<artifactId-or-package>", consumer_count: <N>}
  auth_perimeter: "gateway|in-service-jwt|none|unknown"
  ticket_prefix: "PROJ|null"
```

[Emit this block even if all signals are empty/unknown — the subsection must always be present]

### Architectural Patterns

```yaml
architectural_patterns:
  - {type: saga, style: orchestration, evidence: ["path/to/orchestrator.java:42"]}
  - {type: circuit-breaker, library: resilience4j, evidence: ["path/with/@CircuitBreaker:88"]}
  - {type: schema-registry, vendor: confluent, evidence: ["application.yml:schema.registry.url"]}
```

[Emit `architectural_patterns: []` when no patterns are detected. Omit any entry whose minimum-signal threshold is not met (empty evidence → no entry). BFF detection is workspace-only.]

### Proposed Artifacts (scoped to this service)
**Rules:**
- `<service-name>-conventions.md` (paths: `<service-dir>/**`) — <conventions>
**Skills:**
- `<skill-name>/` — scoped to <service-dir>/
```

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

- **Read-only for source code.** Files written depend on mode: single-project writes `.claude/reports/claudboard-analysis.md`; monorepo additionally writes `.claude/reports/claudboard-analysis-<service>.md` per service; workspace writes `<workspace>/.claude/reports/claudboard-analysis-workspace.md` plus `<workspace>/.claude/reports/claudboard-analysis-<repo>.md` per service repo (by sub-agents) and `<repo>/.claude/memories/ecosystem.md` per service repo (by orchestrator).
- **Never modify source code, tests, or existing files.**
- **Max ~50 source files read** for large repos — note sampling in report.
- **Secrets found during scan:** Report file:line only, never print the value.
- **If path doesn't exist:** State clearly and stop.

## Reference Files

| File | When to load |
|------|-------------|
| `../claudboard/references/stack-detectors.md` | Start of Phase 1 — shared detection heuristics |
| `../claudboard/references/stack-detectors-{lang}.md` | Phase 1c Wide Scan — load language-specific file (java, typescript, python, go, rust, or dotnet) |
| `../claudboard/references/pattern-catalog.md` | Phase 2 — pattern/anti-pattern identification |
| `../claudboard/references/quality-signals.md` | Phase 2 — quality scoring, rule depth, skill triggers |
| `../claudboard/references/workflow-signals.md` | Phase 1 (after Wide Scan) — workflow signal schema, sub-catalog pointers, shared-lib and auth-perimeter detection |
| `../claudboard/references/edges/sync-rpc.md` | Phase 1 — REST/gRPC/tRPC transport extraction (workspace mode, edge detection) |
| `../claudboard/references/edges/messaging.md` | Phase 1 — Kafka/Solace/AMQP/JMS messaging extraction (workspace mode, edge detection) |
| `../claudboard/references/edges/streaming.md` | Phase 1 — WebSocket/SSE/RSocket extraction (workspace mode, edge detection) |
| `../claudboard/references/edges/graphql.md` | Phase 1 — GraphQL client/server extraction (workspace mode, edge detection) |
| `../claudboard/references/patterns/architectural.md` | Phase 1 (after Wide Scan) — architectural pattern detection (all modes) |
