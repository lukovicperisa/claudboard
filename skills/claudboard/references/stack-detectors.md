# Stack Detection Heuristics

Read this file at the start of Phase 1. Use it to guide what to check, what to extract, and how to interpret signals.

---

## File Priority Order

Read these in parallel. Each file is a detection signal — the more that match, the more confident the stack identification.

### JavaScript / TypeScript / Node.js

| File | What to extract |
|------|----------------|
| `package.json` | `name`, `description`, `scripts` (build/test/lint/start/dev), `dependencies`, `devDependencies`, `workspaces` (npm workspace → monorepo), `type` (module vs commonjs) |
| `tsconfig.json` | `compilerOptions.target`, `compilerOptions.strict`, `paths` (aliases), `references` (project references → multi-package) |
| `tsconfig.*.json` | Multiple configs → separate build targets (e.g., src vs tests) |
| `.eslintrc.*` / `eslint.config.*` | Linting rules in use |
| `.prettierrc.*` | Code formatting enforced |
| `jest.config.*` | Test framework config, coverage thresholds |
| `vitest.config.*` | Vitest (modern, faster alternative to Jest) |
| `playwright.config.*` | E2E testing |
| `next.config.*` | Next.js → SSR/SSG framework |
| `vite.config.*` | Vite → modern build tool |
| `webpack.config.*` | Webpack → older build tool or Module Federation |
| `package-lock.json` / `yarn.lock` / `pnpm-lock.yaml` | Package manager in use |

**Framework detection from `dependencies`:**
- `react` → React
- `next` → Next.js (SSR)
- `vue` → Vue.js
- `@angular/core` → Angular
- `svelte` → Svelte
- `express` → Express.js (API)
- `fastify` → Fastify (API)
- `@nestjs/core` → NestJS (structured backend)
- `@modelcontextprotocol/sdk` → MCP server
- `tailwindcss` → Tailwind CSS
- `zustand` → Zustand state management
- `@reduxjs/toolkit` → Redux Toolkit state management
- `@tanstack/react-query` → React Query (data fetching)
- `react-hook-form` → Form management
- `zod` → Schema validation

**Monorepo signals:**
- `workspaces` array in root `package.json` → npm/yarn workspace
- Multiple `package.json` at depth 1-2 → independent packages
- `pnpm-workspace.yaml` → pnpm workspace
- `lerna.json` → Lerna monorepo

---

### Java / Kotlin / JVM

| File | What to extract |
|------|----------------|
| `pom.xml` | `groupId`, `artifactId`, `version`, `parent` (Spring Boot parent version), `dependencies`, `plugins` |
| `build.gradle` / `build.gradle.kts` | Plugins applied, dependencies, Java version (`sourceCompatibility`), Spring Boot version |
| `settings.gradle` / `settings.gradle.kts` | `include(...)` lines → multi-module project, `rootProject.name` |
| `gradle/libs.versions.toml` | Version catalog → all library versions in one place |
| `gradlew` / `mvnw` | Wrapper present → reproducible builds |
| `checkstyle.xml` | Checkstyle configuration → code style enforced |
| `spotbugs*.xml` | SpotBugs → static analysis |
| `lombok.config` | Lombok in use |
| `.sdkmanrc` | SDK version pinned |

**Framework detection from dependencies:**
- `spring-boot-starter-web` → Spring MVC REST
- `spring-boot-starter-webflux` → Spring WebFlux (reactive)
- `spring-boot-starter-data-mongodb` → MongoDB persistence
- `spring-boot-starter-data-jpa` → JPA/Hibernate
- `spring-kafka` → Kafka consumers/producers
- `spring-boot-starter-security` → Spring Security
- `lombok` → Lombok (boilerplate reduction)
- `mapstruct` → MapStruct (object mapping)
- `testcontainers` → Integration tests with real containers
- `spock-core` → Spock testing framework (Groovy)

**Architecture detection from directory names** (look inside `src/main/java/**`):
- `domain/`, `application/`, `infrastructure/` → Hexagonal / Clean Architecture
- `controller/`, `service/`, `repository/` → Classic Layered
- `aggregate/`, `command/`, `query/` → DDD / CQRS
- `port/`, `adapter/` → Explicit Ports & Adapters

**Quality enforcement detection:**
- `quality/checkstyle/`, `quality/spotbugs/`, or similar directories
- `checkstyle.xml`, `spotbugs-exclude.xml` at any level
- If found: read the config — it tells you which conventions are enforced by tooling vs honor-system

**Multi-module signals:**
- `settings.gradle` has multiple `include(...)` → Gradle multi-project
- Multiple `pom.xml` at different depths → Maven multi-module
- Shared library in `libraries/` or `shared/` or `core/` dir

---

### Python

| File | What to extract |
|------|----------------|
| `pyproject.toml` | `[project]` name/version/dependencies, `[tool.poetry]`, `[tool.ruff]`, `[tool.mypy]` |
| `requirements.txt` | Direct dependency list |
| `requirements-dev.txt` / `requirements-test.txt` | Dev/test deps separate → good hygiene |
| `setup.py` / `setup.cfg` | Legacy packaging |
| `Pipfile` | Pipenv → environment management |
| `uv.lock` | uv → modern Python package manager |
| `.python-version` | Python version pinned |
| `pytest.ini` / `conftest.py` | pytest configuration |
| `mypy.ini` / `[tool.mypy]` | Type checking enforced |
| `ruff.toml` / `[tool.ruff]` | Ruff linting/formatting |
| `.pre-commit-config.yaml` | Pre-commit hooks |

**Framework detection:**
- `fastapi` → FastAPI (modern async API)
- `flask` → Flask (lightweight API)
- `django` → Django (full-stack)
- `anthropic` → Claude/Anthropic SDK
- `openai` → OpenAI SDK
- `pydantic` → Data validation
- `sqlalchemy` → ORM
- `celery` → Task queue
- `langchain` → LangChain (LLM orchestration)

---

### Go

| File | What to extract |
|------|----------------|
| `go.mod` | Module name, Go version, `require` block (key dependencies) |
| `go.sum` | Lockfile present |
| `Makefile` | Build/test/lint commands |

**Framework detection from `go.mod`:**
- `github.com/gin-gonic/gin` → Gin HTTP framework
- `github.com/labstack/echo` → Echo HTTP framework
- `google.golang.org/grpc` → gRPC
- `github.com/stretchr/testify` → Testify (testing)

**Architecture detection:**
- `cmd/` → Multi-binary project (Clean Architecture signal)
- `internal/` → Private packages (idiomatic Go)
- `pkg/` → Shared packages

---

### Rust

| File | What to extract |
|------|----------------|
| `Cargo.toml` | `[package]`, `[dependencies]`, `[workspace]` (workspace members) |
| `Cargo.lock` | Lockfile |

---

### .NET / C#

| File | What to extract |
|------|----------------|
| `*.csproj` | `<TargetFramework>`, `<PackageReference>` items |
| `*.sln` | Solution file → multi-project |
| `global.json` | SDK version pinned |
| `NuGet.config` | Private feeds |

---

## Container / Infrastructure Signals

| File | What to extract |
|------|----------------|
| `Dockerfile` | Base image, multi-stage (good practice), exposed port |
| `docker-compose.yml` | Services, volumes, networks → local dev setup |
| `docker-compose.test.yml` | Test isolation setup |
| `helm/` or `charts/` | Kubernetes Helm charts → K8s deployment |
| `kustomize/` or `kustomization.yaml` | Kustomize → K8s config management |
| `k8s/` or `kubernetes/` | Raw K8s manifests |
| `terraform/` | Terraform IaC |
| `pulumi/` or `Pulumi.yaml` | Pulumi IaC (TypeScript/Python/Go-based) |
| `cdk/` | AWS CDK |
| `env/` with `*.ts` | Pulumi TypeScript IaC (Craftsphere pattern) |
| `.azure-pipelines.yml` or `azure-pipelines.yml` | Azure DevOps CI/CD |
| `.github/workflows/*.yml` | GitHub Actions CI/CD |
| `Jenkinsfile` | Jenkins CI/CD |
| `.gitlab-ci.yml` | GitLab CI/CD |
| `.circleci/config.yml` | CircleCI |
| `Makefile` | Build automation — read targets: `build`, `test`, `lint`, `docker`, `deploy` |
| `Taskfile.yml` or `justfile` | Modern build task runners |

---

## Existing Claude Config Signals

| File | What it means |
|------|--------------|
| `CLAUDE.md` | Already onboarded — read to understand what's covered, merge gaps |
| `.claude/rules/*.md` | Existing rules — read frontmatter `paths:` to know coverage |
| `.claude/skills/*/SKILL.md` | Existing skills — catalog names to avoid duplication |
| `.claude/memories/*.md` | Existing context |
| `.claude/settings.json` | Hooks and permissions already configured |
| `.mcp.json` | MCP servers configured |

---

## Right-Level Check

**Run this check FIRST**, before monorepo detection or any other scanning. Prevents analysing a microservice in isolation when it's part of a larger ecosystem.

### Detection Algorithm

Scan the parent directory (`../`) for sibling directories containing any build file:
- `build.gradle`, `build.gradle.kts`
- `pom.xml`
- `package.json`
- `go.mod`
- `pyproject.toml`
- `Cargo.toml`
- `*.csproj`

**If N ≥ 2 sibling service directories found:**

1. Detect the stack for each sibling (same stack detection signals as below)
2. Present step-up prompt to user:
   ```
   This looks like a microservice within a larger system.
   
   Found sibling services at [parent-dir]:
   • user-service (Java/Spring Boot)
   • frontend (React/TypeScript)
   • notification-service (Java/Spring Boot)
   
   Analyse at ecosystem level for cross-service dependency mapping? [y/n]
   ```

3. Wait for user response:
   - **YES** → re-run analysis from the parent directory (workspace or monorepo detection will trigger)
   - **NO** → proceed with analysis at current directory without further checks

**Skip this check if:**
- CWD has no build file (already at workspace/monorepo root — will trigger later detection)
- Parent directory has fewer than 2 other build-file directories (this is a monolith or standalone service)

**Stack detection for sibling display:**

Use build file presence to infer stack:
- `build.gradle`/`pom.xml` → "Java" (check dependencies for "/Spring Boot" suffix if present)
- `package.json` → "Node.js" (check for `react`/`next`/`vue`/`@angular/core` in dependencies → "React", "Next.js", "Vue", "Angular")
- `go.mod` → "Go"
- `pyproject.toml`/`requirements.txt` → "Python"
- `Cargo.toml` → "Rust"
- `*.csproj` → ".NET"
- Unknown → "(unknown stack)"

---

## Monorepo Detection & Service Classification

Run this check after the Right-Level Check passes (user declined step-up or no siblings found).

### Step 1: Find independent build roots

```bash
# Find build files at depth 1-3, excluding dependency dirs
find . -maxdepth 3 \( \
  -name 'build.gradle' -o -name 'build.gradle.kts' \
  -o -name 'pom.xml' \
  -o -name 'package.json' \
  -o -name 'go.mod' \
  -o -name 'pyproject.toml' \
  -o -name 'Cargo.toml' \
  -o -name '*.csproj' \
\) \
  ! -path '*/node_modules/*' \
  ! -path '*/.venv/*' \
  ! -path '*/vendor/*' \
  ! -path '*/.gradle/*' \
  ! -path '*/target/*' \
  ! -path '*/dist/*' \
  ! -path '*/build/*'
```

- **1 result:** Single-project repo — proceed with standard single-project flow.
- **2+ results:** Potential monorepo — proceed to Step 2.

### Step 2: Classify each build root as service or library

For each build root, check these signals:

| Signal | Service | Library |
|--------|---------|---------|
| `Dockerfile` present in directory | ✓ Strong | ✗ |
| Main entry point (see table below) | ✓ Strong | ✗ |
| Runtime config (`application.yml`, `.env`, `config.yaml`) | ✓ Supporting | ✗ |
| Publish task configured (see table below) | ✗ | ✓ Strong |
| No Dockerfile AND no main entry point | ✗ | ✓ Supporting |

**Main entry point signals by stack:**

| Stack | Service signal | Library signal |
|-------|---------------|----------------|
| Java/Kotlin | `@SpringBootApplication`, `public static void main(` | `maven-publish` plugin, `publishing {` block |
| Node/TS | `"start"` script in package.json | `"publishConfig"` or `"files"` in package.json |
| Python | `__main__.py` or `if __name__ == "__main__":` | `[build-system]` in pyproject.toml, `setup.py` |
| Go | `package main` + `func main()` | Package declares only library types (no `package main`) |
| Rust | `[[bin]]` in Cargo.toml or `src/main.rs` | `[lib]` in Cargo.toml, no `src/main.rs` |
| .NET | Entry point class with `Main()`, `Program.cs` | `<IsPackable>true</IsPackable>` in .csproj |

**Classification rule:**
- ANY service signal → classify as **service**
- ALL library signals (publish task + no main + no Dockerfile) → classify as **library**
- Ambiguous → classify as **service** (default to full analysis)

### Step 3: Handle edge cases

**Gradle/Maven multi-module with shared build root:**
- Signal: single `settings.gradle` with `include(...)` or root `pom.xml` with `<modules>`
- BUT: per-module `Dockerfile` files exist
- Action: ask user: "This looks like a multi-module project with per-module deployments. Treat as monorepo with N services, or as a single project?"

**Shared infrastructure directories** (not services or libraries):
- `infra/`, `env/`, `deploy/`, `charts/`, `helm/`, `terraform/`, `k8s/` — exclude from service list
- `common/`, `shared/`, `core/` without main entry point → check for publish task → library if present, otherwise shared utilities (exclude from service list)

### Step 4: Present topology before proceeding

After classification, present to user:

```
Found N services + M libraries:

Services:
  • order-service/     (Java/Spring Boot)
  • user-service/      (Java/Spring Boot)
  • frontend/          (React/TypeScript)

Libraries:
  • libraries/craftsphere.core/   (Java, maven-publish)

Proceeding with full analysis of each service.
```

Wait for user to confirm or correct misclassifications before proceeding.

---

## Service Identity Resolution

**Applies to: workspace mode (multi-repo) and cross-service dependency graph construction.**

When building the dependency graph, each repo needs a canonical identity to match outbound references (FeignClient names, topic names) against inbound surfaces.

### Resolution Order

1. **Primary: `spring.application.name`**
   - Read from `application.yml` or `application.properties` at any depth in the repo
   - If found, use this value as the service identity (e.g., `"user-service"`)
   - Common location: `src/main/resources/application.yml`

2. **Fallback: directory name**
   - If no `spring.application.name` found, use the directory name as-is (e.g., `order-service/` → `"order-service"`)

3. **Supplementary signals** (use if both primary and fallback are absent or ambiguous):
   - Kubernetes service manifest: `metadata.name` in `k8s/*.yaml` or `helm/templates/service.yaml`
   - Docker Compose service name: service key in `docker-compose.yml`
   - Note: These are supporting signals, not primary — they may not exist or may differ from runtime identity

### Extraction Command

```bash
# Spring application.name (YAML)
grep -r 'spring.application.name' --include='application.yml' --include='application.yaml' .

# Spring application.name (properties)
grep -r 'spring.application.name' --include='application.properties' .

# Kubernetes service name
grep -r 'metadata:' -A 5 --include='service.yaml' k8s/ helm/ | grep 'name:'

# Docker Compose
grep -A 1 'services:' docker-compose.yml
```

### Identity Matching Rules

When matching outbound references to repo identities:
- **REST (FeignClient):** `@FeignClient(name = "user-service")` → matches repo with identity `"user-service"`
- **REST (URL-based):** `RestTemplate` URL containing `/user-service/` → matches repo with identity `"user-service"`
- **Kafka/Solace:** topic names are matched exactly (see Cross-Service Surface Detection below)

---

## Cross-Service Surface Detection

**Applies to: workspace mode (multi-repo) only.** Runs during per-repo analysis (Phase 1b) to extract each repo's communication surface for the cross-service dependency graph (Phase 1c).

**Single source of truth:** `workflow-signals.md` and `edges/*.md`

All transport-specific grep commands and extraction rules are in the sub-catalogs:

| Transport family | Reference file |
|-----------------|----------------|
| REST clients, gRPC, tRPC, inbound routes | `edges/sync-rpc.md` |
| Kafka, RabbitMQ, JMS, Solace, MQTT, Redis pub/sub, SNS/SQS, Service Bus, Google Pub/Sub | `edges/messaging.md` |
| WebSocket, SSE, RSocket, socket.io | `edges/streaming.md` |
| Spring GraphQL, DGS, Apollo, urql, graphql-request, Relay | `edges/graphql.md` |

See `workflow-signals.md` for the full output schema, field definitions, and the `type` ↔ `protocol` backward-compat synonym rule.

---

## Size Thresholds

| Repo size | Strategy |
|-----------|---------|
| <50 source files | Full analysis — read all relevant source files (skip Wide Scan) |
| 50-500 source files | Wide Scan + strategic sampling (up to 25 files) |
| >500 source files | Wide Scan + strict strategic sampling (up to 15 files) |
| >1GB | Flag immediately; analyze only top-level structure + build configs |

Source files = non-config code files (`.java`, `.ts`, `.py`, `.go`, etc.). Exclude `node_modules/`, `.git/`, `dist/`, `build/`, `target/`, `__pycache__/`, `.venv/`, `vendor/`, `.gradle/`.

---

## Language-Specific Wide Scan Patterns

For Wide Scan anti-patterns, conventions, security, observability, API surface, and dependencies, load the language-specific file:

| Language | File to load |
|----------|-------------|
| Java / Kotlin | `stack-detectors-java.md` |
| TypeScript / JavaScript | `stack-detectors-typescript.md` |
| Python | `stack-detectors-python.md` |
| Go | `stack-detectors-go.md` |
| Rust | `stack-detectors-rust.md` |
| .NET / C# | `stack-detectors-dotnet.md` |

Each language-specific file contains 7 categories:
1. Custom pattern detection
2. Anti-pattern inventory
3. Convention detection
4. Security pattern detection
5. API surface detection
6. Observability pattern detection
7. Dependency health checks

---

### Custom Pattern Detection (all languages)

**Parallel class hierarchies** (naming similarity signals duplication):
```bash
# Root/Branch/Leaf pattern (Java)
grep -rl 'class Root\|class Branch\|class Leaf\|extends Root\|extends Branch\|extends Leaf' \
  --include='*.java' src/

# V1/V2 versioned duplication
grep -rl 'class.*V1\|class.*V2\|Controller.*V1\|Service.*V2' --include='*.java' --include='*.ts' src/
```

**Interface-implementation pairs** (ports & adapters signal):
```bash
# Java interfaces + implementations in different packages
INTERFACES=$(grep -rl '^public interface\|^interface ' --include='*.java' src/main/ | wc -l)
IMPLS=$(grep -rn 'implements ' --include='*.java' src/main/ | wc -l)
# High INTERFACES count + distinct impl locations → hexagonal/clean architecture
```

**Hotspot detection** (most actively changed files):
```bash
git log --since=3.months --name-only --format="" 2>/dev/null \
  | grep -v '^$' | sort | uniq -c | sort -rn | head -10
```

---

### Project-Specific Workflow Detection

These patterns are not detectable by grep alone. They require reading documentation and reconstructing multi-file workflows. These are the highest-value patterns for skill generation — they capture how *this* project does things, not how a framework works.

**Sources to check:**
1. `README.md` — look for "Getting Started", "Contributing", "How to add..." sections that describe multi-step rituals
2. `docs/adr/` or `ADR/` — architecture decision records describing non-obvious workflows or constraints
3. Most recently added subclass of any base class with 5+ subclasses — reconstruct the workflow by reading the commit that added it:
   ```bash
   git log --diff-filter=A --name-only --format="%H %s" -- <subclass-file>
   ```

**What to record:**
- Workflow name (e.g., "Add a new leaf entity type")
- Steps (files created/modified in order)
- Files involved
- Source of discovery (README section, ADR, git history)

**When to generate a skill:** If the workflow involves creating 3+ files in a specific order, it is a strong skill candidate with `scaffold.sh` potential. Prioritize these over framework-generic skills (e.g., "add a REST controller") — Claude already knows framework patterns, but not project-specific rituals.
