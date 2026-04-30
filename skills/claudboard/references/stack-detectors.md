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

## Monorepo Boundary Detection

Run this check during structure mapping:

1. Count `package.json` / `pom.xml` / `build.gradle` files at depth 1-2
2. If >1 independent build file found:
   - Look for containing dir: `services/`, `packages/`, `apps/`, `modules/`, `libs/`
   - If containing dir found → **monorepo with service boundary**
   - If `workspaces` in root `package.json` → **npm workspace monorepo**
   - If `settings.gradle` has `include()` → **Gradle multi-module**
3. For monorepos: analyze shared infra first, then sample 2-3 representative services — NOT all services

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

## Wide Scan Grep Patterns

Run during Phase 1 step 1c. All greps exclude build output dirs. Run in parallel.

### Java / Kotlin

**Custom patterns (inheritance & annotations):**
```bash
# Custom annotation declarations
grep -rn '@interface' --include='*.java' --include='*.kt' src/

# Abstract base classes
grep -rn '^public abstract class\|^abstract class' --include='*.java' src/

# Inheritance usage (exclude comments and tests)
grep -rn ' extends ' --include='*.java' src/main/ | grep -v '//'

# Interface implementations
grep -rn ' implements ' --include='*.java' src/main/ | grep -v '//'
```

**Anti-pattern signals:**
```bash
# God class candidates (files >300 LOC in main source)
find . -name '*.java' -path '*/src/main/*' ! -path '*/test/*' \
  | xargs wc -l 2>/dev/null | sort -rn | head -20

# Field injection count
grep -rc '@Autowired' --include='*.java' src/main/ | awk -F: '{s+=$2}END{print s}'

# Constructor injection indicator
grep -rc 'private final' --include='*.java' src/main/ | awk -F: '{s+=$2}END{print s}'

# Broad exception catching
grep -rn 'catch (Exception\|catch (Throwable' --include='*.java' src/main/

# Null returns
grep -rn 'return null;' --include='*.java' src/main/

# Reflection in business logic
grep -rn 'ReflectionUtils\|getDeclaredField\|setAccessible(true)\|Method\.invoke\|ParameterizedType' \
  --include='*.java' src/main/

# Legacy java.util.Date usage
grep -rl 'import java\.util\.Date' --include='*.java' src/main/

# Console logging (production code only)
grep -rn 'System\.out\.print\|System\.err\.print' --include='*.java' src/main/

# Star imports
grep -rn 'import .*\.\*;' --include='*.java' src/main/

# TODO/FIXME/HACK count
grep -rc 'TODO\|FIXME\|HACK' --include='*.java' src/main/ | grep -v ':0$'
```

**Convention frequency:**
```bash
# Logging style: @Slf4j vs LoggerFactory
SLF4J_ANNOT=$(grep -rl '@Slf4j' --include='*.java' src/ | wc -l)
SLF4J_FACTORY=$(grep -rl 'LoggerFactory.getLogger' --include='*.java' src/ | wc -l)
# Report: "@Slf4j (N files) vs LoggerFactory (M files)"

# Test naming pattern
find src/test -name '*Test.java' -o -name '*Spec.groovy' -o -name '*IT.java' 2>/dev/null | head -5
```

**Security posture signals:**
```bash
# Spring Security framework
grep -rl 'SecurityFilterChain\|@EnableMethodSecurity\|@EnableWebSecurity' \
  --include='*.java' src/main/

# Method-level auth annotations
grep -rn '@PreAuthorize\|@Secured\|@RolesAllowed' --include='*.java' src/main/

# Custom auth annotations (detect name, then count usage)
# Step 1: find custom @interface annotations with auth-related names
grep -rn '@interface.*[Aa]uthor\|@interface.*[Aa]uth\|@interface.*[Ss]ecur' \
  --include='*.java' src/main/
# Step 2: for each found annotation (e.g. @Authorize), count usage on controller methods
grep -rn '@Authorize\|@RequiresAuth' --include='*.java' src/main/ | wc -l

# Auth filters (custom OncePerRequestFilter implementations)
grep -rn 'extends OncePerRequestFilter\|implements Filter' --include='*.java' src/main/

# CORS configuration
grep -rl 'CorsConfigurationSource\|@CrossOrigin\|addCorsMappings\|CorsConfiguration' \
  --include='*.java' src/main/

# Endpoint count vs auth-annotated endpoint count (coverage gap detection)
TOTAL_ENDPOINTS=$(grep -rc '@GetMapping\|@PostMapping\|@PutMapping\|@DeleteMapping\|@PatchMapping\|@RequestMapping' \
  --include='*.java' src/main/ | awk -F: '{s+=$2}END{print s}')
AUTH_ENDPOINTS=$(grep -rc '@PreAuthorize\|@Secured\|@Authorize\|@RolesAllowed' \
  --include='*.java' src/main/ | awk -F: '{s+=$2}END{print s}')
# If AUTH_ENDPOINTS < TOTAL_ENDPOINTS: flag potential unprotected routes
```

**API surface signals:**
```bash
# Endpoint tally by HTTP method
GET_COUNT=$(grep -rc '@GetMapping' --include='*.java' src/main/ | awk -F: '{s+=$2}END{print s}')
POST_COUNT=$(grep -rc '@PostMapping' --include='*.java' src/main/ | awk -F: '{s+=$2}END{print s}')
PUT_COUNT=$(grep -rc '@PutMapping' --include='*.java' src/main/ | awk -F: '{s+=$2}END{print s}')
DELETE_COUNT=$(grep -rc '@DeleteMapping' --include='*.java' src/main/ | awk -F: '{s+=$2}END{print s}')
PATCH_COUNT=$(grep -rc '@PatchMapping' --include='*.java' src/main/ | awk -F: '{s+=$2}END{print s}')
# Report: "GET:N POST:M PUT:P DELETE:Q PATCH:R  total: N+M+P+Q+R endpoints"

# API versioning (URL-based)
grep -rn '@RequestMapping.*v[0-9]\|@GetMapping.*v[0-9]\|@PostMapping.*v[0-9]' \
  --include='*.java' src/main/ | grep -oP '/v\d+/' | sort -u
# If versions found: report "URL-based versioning: v1, v2..." else "No versioning detected"

# OpenAPI / Swagger documentation tooling (check deps, not source)
# Look in build.gradle or pom.xml (handled in dep detection step):
grep -r 'springdoc\|springfox\|swagger' build.gradle settings.gradle pom.xml 2>/dev/null | head -5
```

**Observability signals:**
```bash
# Spring Actuator
grep -r 'spring-boot-starter-actuator' build.gradle pom.xml 2>/dev/null

# Micrometer metrics
grep -r 'micrometer-core\|micrometer-registry' build.gradle pom.xml 2>/dev/null
grep -rn '@Timed\|MeterRegistry' --include='*.java' src/main/ | wc -l

# Distributed tracing
grep -r 'micrometer-tracing\|spring-cloud-sleuth\|io\.opentelemetry\|opentelemetry-api' \
  build.gradle pom.xml 2>/dev/null

# Structured logging
grep -r 'logstash-logback-encoder\|logback-json' build.gradle pom.xml 2>/dev/null
grep -rn 'net\.logstash\.logback' --include='*.java' --include='*.xml' src/ 2>/dev/null | wc -l

# Actuator endpoint config
grep -rn 'management\.endpoints\|management\.endpoint' \
  src/main/resources/application*.yml src/main/resources/application*.properties 2>/dev/null | head -5
```

**Dependency deep-scan signals:**
```bash
# BOM usage (Gradle)
grep -rn 'platform(\|enforcedPlatform(' --include='*.gradle' --include='*.kts' .

# BOM usage (Maven)
grep -rn '<type>pom</type>' pom.xml 2>/dev/null

# Dependency conflict resolution (Gradle)
grep -rn 'resolutionStrategy\|force =\|forceVersion' --include='*.gradle' --include='*.kts' .
# Dependency exclusions (Maven)
grep -c '<exclusion>' pom.xml 2>/dev/null

# SBOM generation
grep -r 'cyclonedx\|spdx\|sbom' build.gradle pom.xml azure-pipelines.yml .github/workflows/*.yml 2>/dev/null

# Cross-module version mismatch (multi-module Gradle projects)
# After detecting multi-module, compare same dep version across included build files:
grep -rn 'testcontainers\|spring-boot\|mapstruct' \
  --include='*.gradle' --include='*.kts' --include='*.toml' . \
  | grep -v '.gradle/\|build/' | sort
# If same artifact appears at different versions across modules: flag MEDIUM severity
```

---

### TypeScript / JavaScript

**Custom patterns:**
```bash
# Abstract classes and inheritance
grep -rn 'abstract class\| extends ' --include='*.ts' src/ | grep -v node_modules | grep -v '//'

# Interface declarations
grep -rn '^export interface\|^interface ' --include='*.ts' src/

# Type declarations
grep -rn '^export type ' --include='*.ts' src/
```

**Anti-pattern signals:**
```bash
# God component/class candidates
find . -name '*.ts' -o -name '*.tsx' | grep -v node_modules | grep -v dist \
  | xargs wc -l 2>/dev/null | sort -rn | head -20

# TypeScript `any` usage
grep -rn '\bany\b\| as any\b\|// @ts-ignore\|// @ts-nocheck' \
  --include='*.ts' --include='*.tsx' src/ | grep -v node_modules

# Console.log in production (not test files)
grep -rn '\bconsole\.log\b' --include='*.ts' --include='*.tsx' src/ \
  --exclude-dir=test --exclude-dir=__tests__ --exclude-dir=spec
```

**Convention frequency:**
```bash
# Naming: PascalCase components vs lowercase files
find src -name '*.tsx' | head -20  # Check naming pattern in output

# Import style: absolute (tsconfig paths) vs relative
grep -rn "from '\.\." --include='*.ts' --include='*.tsx' src/ | wc -l  # relative
grep -rn "from '@/" --include='*.ts' --include='*.tsx' src/ | wc -l    # alias-based
```

---

### Python

**Custom patterns:**
```bash
# Abstract base classes and protocols
grep -rn 'class.*ABC\|class.*Protocol\|class.*BaseModel\|@abstractmethod' --include='*.py' src/

# Class inheritance
grep -rn '^class.*(' --include='*.py' src/ | grep -v '():\|object):'  # non-trivial inheritance
```

**Anti-pattern signals:**
```bash
# God class candidates
find . -name '*.py' ! -path '*/.venv/*' ! -path '*/test*' \
  | xargs wc -l 2>/dev/null | sort -rn | head -20

# Broad exception catching
grep -rn 'except Exception\|except:\|bare except' --include='*.py' src/

# Type ignore
grep -rn '# type: ignore\|# noqa' --include='*.py' src/

# TODO/FIXME/HACK
grep -rc 'TODO\|FIXME\|HACK' --include='*.py' src/ | grep -v ':0$'
```

**Convention frequency:**
```bash
# Type hints presence
grep -rl 'def .*->.*:' --include='*.py' src/ | wc -l  # functions with return types
grep -rl 'def ' --include='*.py' src/ | wc -l  # total function files
```

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
