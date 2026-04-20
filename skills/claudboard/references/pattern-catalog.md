# Architecture Pattern Catalog

Use this during Phase 1 convention inference and Phase 2 quality assessment. Match detection signatures to identify patterns, then cite the evidence in the analysis report.

---

## Architecture Patterns

### Hexagonal Architecture (Ports & Adapters)

**Detection signals:**
- Directory names: `domain/`, `application/`, `infrastructure/` at the top of source tree
- OR explicit: `port/`, `adapter/` directories
- Domain layer has interfaces only (ports), infrastructure has implementations (adapters)
- Use cases in `application/use-cases/` or `application/service/`

**Craftsphere example:** `services/<name>/src/main/java/com/bosch/<name>/{model,database,controller,service}`

**What to say:** "Hexagonal architecture — domain model isolated from infrastructure via port interfaces and adapters."

**Good signal:** Domain doesn't import from infrastructure packages. Adapters implement domain port interfaces.

**Anti-pattern signal:** Infrastructure imports leak into domain (e.g., `@Document` annotation on domain model, JPA annotations on domain entity).

---

### Classic Layered (Controller → Service → Repository)

**Detection signals:**
- Flat `controller/`, `service/`, `repository/` directories at same level
- No explicit port/adapter separation

**What to say:** "Classic 3-layer architecture — presentation (controllers), business logic (services), data access (repositories)."

**Tech debt signal if combined with hexagonal:** Mixed patterns suggest architectural refactoring in progress.

---

### Domain-Driven Design (DDD)

**Detection signals:**
- Directories named after business concepts: `order/`, `payment/`, `customer/`
- Each contains its own `model/`, `repository/`, `service/`
- `aggregate/` directory or classes named `*Aggregate`
- `command/` and `query/` directories (CQRS variant)
- Value objects, entities, domain events as class patterns

**What to say:** "DDD with bounded contexts — each domain concept (X, Y, Z) owns its model, repository, and services."

---

### Microservices

**Detection signals:**
- Multiple independent build files (Gradle/Maven/package.json) at service boundaries
- Each service has its own `Dockerfile`
- Independent CI/CD pipelines per service OR shared template with service-specific trigger
- Inter-service communication: REST, gRPC, message broker (Kafka, RabbitMQ)
- Service discovery config (Kubernetes services, Consul, Eureka)

**What to say:** "Microservices — N independent services, each deployable independently."

**Risks to flag:** Shared databases (no service boundary), synchronous chains (latency amplification), missing circuit breakers.

---

### Micro-Frontends (MFE)

**Detection signals:**
- `webpack.config.js` with `ModuleFederationPlugin` → Webpack Module Federation
- Multiple `package.json` under `frontend/` or `apps/`
- Shell app + remote apps pattern
- `@module-federation/` dependencies

**What to say:** "Micro-frontend architecture via Module Federation — shell app (X) composes remotes (Y, Z)."

---

### Event-Driven Architecture

**Detection signals:**
- Kafka: `spring-kafka` dep, `@KafkaListener` classes, `KafkaTemplate`, Avro schemas (`.avsc` files)
- RabbitMQ: `spring-rabbit`, `@RabbitListener`
- AWS SNS/SQS: `aws-sdk` with sns/sqs clients
- Topic/queue config files
- `consumer/` and `producer/` directories

**What to say:** "Event-driven — services communicate via [Kafka/RabbitMQ/SNS] topics."

**Patterns to note:** Consumer groups, dead letter topics, retry configuration.

---

### GitOps / Infrastructure as Code

**Detection signals:**
- ArgoCD: `argocd-*.yaml`, `Application` CRDs
- Helm: `charts/`, `values.yaml`, `values-<env>.yaml`
- Kustomize: `kustomization.yaml`, `overlays/`
- Pulumi: `Pulumi.yaml`, `index.ts` in `env/`
- Terraform: `*.tf` files, `terraform.tfvars`

**What to say:** "GitOps deployment — infrastructure changes via pull request, not manual CLI commands."

**Critical rule to generate:** "Never run `helm install`, `kubectl apply`, or `pulumi up` directly. All changes via pipeline/PR."

---

## Anti-Patterns Catalog

### Code Anti-Patterns

| Anti-pattern | Detection method | Severity |
|-------------|-----------------|---------|
| Field injection | `@Autowired` on non-constructor fields in Java | HIGH — tight coupling, hard to test |
| God class | Source file >500 lines | MEDIUM — violates SRP |
| God service | Service class >300 lines with 10+ methods | MEDIUM |
| Null returns | Methods returning `null` instead of `Optional` | MEDIUM |
| Exception swallowing | Empty catch blocks or `catch (Exception e) {}` | HIGH |
| Broad exception catching | `catch (Exception e)` that wraps/rethrows instead of catching specific types | MEDIUM |
| Sequential generic catches | 3+ `catch (Exception)` blocks in one method — masks distinct failure modes | HIGH |
| Defensive lambdas | try-catch inside stream/removeIf/forEach lambdas — hides data integrity issues behind silent recovery | MEDIUM |
| Console logging | `System.out.println`, `console.log` in production code (outside tests) | MEDIUM |
| Magic numbers | Unnamed numeric constants inline | LOW |
| Circular imports | Service A imports Service B, B imports A | HIGH |
| Copy-paste duplication | Same ~5-line code pattern (e.g., try-catch block, reflection sequence) appearing 3+ times across different files | MEDIUM |
| Too many parameters | Methods with >7 parameters; >3 is a smell | MEDIUM — hard to read, easy to mix up argument order |
| Boolean flag arguments | `process(data, true, false)` — caller intent invisible at call site | MEDIUM — use enum, separate methods, or config object |
| Log and throw | `log.error(...)` + `throw` in same catch block | MEDIUM — duplicates error reporting up the call stack |
| Long methods | Methods >30 lines | LOW — break into named steps |
| Star imports | `import java.util.*` | LOW — hides dependencies, causes merge conflicts |

### Reflection Anti-Patterns

Reflection is normal in framework/config code (Spring, Jackson). It becomes an anti-pattern when it appears in application-level business logic — the CRUD hot path, service helpers, or read operations.

**Detection:**
Grep production code (exclude tests) for: `ReflectionUtils`, `getDeclaredField`, `setAccessible`, `makeAccessible`, `Field.get`, `Method.invoke`, `ParameterizedType`, `getGenericSuperclass`

**Severity tiers:**

| Location | Count threshold | Severity |
|----------|----------------|---------|
| Config/startup only | any | LOW — normal framework usage |
| CRUD path (service/helper classes) | >5 | HIGH — fragile, no compile-time safety |
| Read path with `invoke()` | any | HIGH — runtime method dispatch, breaks refactoring tools |
| Hardcoded field name strings (e.g., `getDeclaredField("deletedDate")`) | any | MEDIUM — rename breaks silently, no compiler warning |

**What to check after detection:**
- Is reflection in the hot path? (every request vs. one-time startup)
- Are reflected field/method names hardcoded strings? (rename breaks silently)
- Is the same reflection pattern duplicated across parallel class hierarchies?
- Could the reflection be replaced by an interface method, a visitor, or a type-safe callback?

**Reporting guidance:**
When reflection is deeply embedded in the architecture (e.g., cascade callbacks that every CRUD operation flows through), don't just say "don't use reflection" — that's not actionable if the base classes require it. Instead:
- Document it in a separate `tech-debt.md` rule, not in conventions
- Distinguish "don't extend this pattern to new code" from "refactor eventually"
- Note that new entity types must follow existing patterns but shouldn't introduce *additional* reflection beyond what base classes require

### Architecture Anti-Patterns

| Anti-pattern | Detection method | Severity |
|-------------|-----------------|---------|
| Shared database | Multiple services referencing same DB connection string | HIGH |
| Anemic domain model | Domain classes have only getters/setters, no behavior | MEDIUM |
| Missing service boundary | Direct class imports between services in monorepo | HIGH |
| Mixed state managers | Multiple state management libs in same frontend app (e.g., Redux + Zustand) | MEDIUM |
| Hardcoded environment | Environment-specific values in source code (not config/secrets) | HIGH |
| Missing retry logic | External API calls with no retry/circuit breaker | MEDIUM |
| Parallel class hierarchies with duplication | Classes with shared prefix/suffix (Root*/Branch*/Leaf*, *V1/*V2) containing copy-pasted methods | MEDIUM — multiplies maintenance cost, bugs fixed in one hierarchy missed in others |

### Testing Anti-Patterns

| Anti-pattern | Detection method | Severity |
|-------------|-----------------|---------|
| No tests | No test files at all | HIGH |
| Test-only happy path | Test files exist but no failure/edge case tests | MEDIUM |
| Spock stub+verify | In Spock: stubbing in `given:` and verifying same method in `then:` | HIGH — Spock ignores the stub |
| Mocking everything | Over-mocked tests that don't test real behavior | MEDIUM |
| No integration tests | Only unit tests, no integration or contract tests | MEDIUM |
| Missing test for CI | Tests not wired to CI pipeline | HIGH |

### Security Anti-Patterns

| Anti-pattern | Detection method | Severity |
|-------------|-----------------|---------|
| No security framework | No `SecurityFilterChain`, `@EnableMethodSecurity`, or equivalent in production source | HIGH |
| Unprotected REST endpoints | Controller endpoint count > auth-annotated endpoint count | MEDIUM — verify intentional public routes |
| No CORS configuration | REST controllers exist but no `CorsConfigurationSource`, `@CrossOrigin`, or CORS WebMvcConfigurer | INFO — verify if frontend on same origin |
| Method-level auth absent | Security framework present but no `@PreAuthorize`/`@Secured`/custom auth annotations | MEDIUM — class-level or filter-level auth may cover this; verify |

### Infrastructure Anti-Patterns

| Anti-pattern | Detection method | Severity |
|-------------|-----------------|---------|
| Mixed lockfiles | `package-lock.json` + `yarn.lock` present | MEDIUM |
| No .gitignore | Missing `.gitignore` | MEDIUM |
| Hardcoded secrets | Literal passwords/API keys in source code | CRITICAL |
| No CI | No CI configuration file | HIGH |
| Manual deployment | No IaC, no pipeline — manual steps documented | HIGH |

---

## Compound Severity Rules

When two anti-patterns co-occur, their combined risk is greater than the sum of individual severities. Apply these rules during Phase 2 after collecting all Watch findings. Report with `[SEVERITY — compound]` label.

| Finding A | Finding B | Escalated Severity | Risk |
|-----------|-----------|-------------------|------|
| `return null` (INFO) | Reflection in CRUD hot path (HIGH) | HIGH | Null propagates silently through reflection-driven cascade operations — data loss with no compiler warning |
| Broad `catch (Exception)` (MEDIUM) | Cascading deletes (any severity) | HIGH | Swallowed exceptions during cascades leave data in inconsistent state |
| God class (MEDIUM) | No tests covering that class (MEDIUM) | HIGH | Untestable complexity: changes to large class have no safety net |
| No security framework (HIGH) | PII fields in response DTOs (any) | CRITICAL | Personal data exposed with no access control |
| Missing retry logic (MEDIUM) | `@FeignClient` or external HTTP calls (any) | HIGH | Transient failures cascade to user-facing errors in distributed calls |

**Reporting format for compound findings:**
```
- [HIGH — compound] return null × 12 + reflection in CRUD hot path → silent data loss risk in cascade operations
  (individually: null returns = INFO, reflection = HIGH — together they compound)
```

**Adding new compound rules:** Edit this table in `pattern-catalog.md`. Scanner picks them up on next run. No code changes needed.

---

## Tech Debt Indicators

### Version Debt

- Java below 17 (17 = LTS, current LTS is 21)
- Spring Boot below 3.0 (EOL)
- Node.js below LTS (check nodejs.org/en/about/releases)
- React below 18
- Python below 3.10
- Major version pinned at old major (e.g., `"react": "^16.x"`)

**Detection:** Read version fields in build files and dependency lists.

### Structural Debt

- `TODO`, `FIXME`, `HACK`, `XXX` comments — grep source files
- Commented-out code blocks — large blocks of `//` or `/* */`
- Orphaned directories (empty `src/`, unused `lib/`)
- Dead services in monorepo (service dir exists but no CI job references it)
- Duplicate code between services (same class names in multiple services with slight variations)
- Reflection-based workarounds for framework limitations (e.g., `getDeclaredField` to bypass ModelMapper null-skipping) — indicates missing abstraction or wrong tool choice
- Defensive code hiding data integrity issues (e.g., try-catch around `@DBRef` resolution in lambdas, repeated across multiple files)

### Process Debt

- No CI quality gates (lint/test not in pipeline)
- No code coverage tracking
- No automated security scanning
- Mixed commit message formats (no conventional commits enforcement)
- Long-lived feature branches (detectable from git log if available)

---

## Good Patterns Worth Preserving

| Pattern | Signal | What to note in rules |
|---------|--------|----------------------|
| Constructor DI | All `@Autowired` on constructors only | "Constructor-based DI only — preserve this" |
| Optional returns | `Optional<T>` return types on nullable queries | "Never return null — use Optional" |
| Request/response logging filter | Central filter vs per-controller logging | "Use central filter — don't log in controllers" |
| Conventional commits | `git log` shows `feat:`, `fix:`, `chore:` pattern | "Follow conventional commits format" |
| Test coverage gate | JaCoCo/Istanbul thresholds in build config | "Maintain coverage threshold — do not reduce" |
| Interface-first design | Port interfaces before implementations | "Code against interfaces, not implementations" |
| Immutable DTOs | Java records for DTOs | "Use Java records for DTOs — immutable by default" |
| Env-based config | `application-{env}.yml` or Helm `values-{env}.yaml` | "Never hardcode env-specific values in source" |
| Single source of truth | One canonical config file, CI propagates copies | "Edit only the source file — CI handles propagation" |
| Log OR throw | Catch blocks either log or throw, never both | "Either log OR throw — doing both duplicates error reporting" |

### Common Java/General Code Quality Rules

These are universal rules to check for and document when detected (or flag as debt when violated). They apply regardless of framework or architecture:

| Rule | Detection method | What to note |
|------|-----------------|--------------|
| Max method parameters | Methods with >3 args; flag >7 as hard limit | "Max 3 method arguments preferred. Beyond 7, introduce a parameter object or builder" |
| Max constructor parameters | Constructors with >7 params (DI is the common cause) | "Beyond 7 constructor params, consider builder pattern or splitting the class" |
| No boolean flag arguments | Methods like `process(data, true, false)` | "Boolean args hide intent — use enum, separate methods, or a config object" |
| Class organization order | Check if classes follow: static constants → fields → constructors → public methods → private methods → getters/setters | "Consistent class member ordering — statics first, then fields, constructors, public API, internals" |
| Method length | Methods >30 lines | "Long methods should be broken into named steps — each method does one thing" |
| Log OR throw, never both | `log.error(...)` followed by `throw` in same catch block | "Either log the error OR throw it — doing both causes duplicate error reporting up the call stack" |
| Specific exception types | `catch (Exception e)` instead of catching specific types | "Catch the most specific exception type — generic catches mask bugs" |
| Early returns | Deeply nested if/else chains vs. guard clauses | "Prefer early returns (guard clauses) over deep nesting" |
| No star imports | `import java.util.*` instead of specific imports | "Explicit imports — star imports hide dependencies and cause merge conflicts" |

---

## Whole-Repo Grep Patterns for Anti-Pattern Detection

Run these during Wide Scan (Phase 1 step 1c). They cover the entire codebase, not just sampled files. Record counts and file lists for Phase 2 reporting.

### God Class Detection

```bash
# Java — files >300 LOC in production source
find . -name '*.java' -path '*/src/main/*' ! -path '*/test/*' \
  | xargs wc -l 2>/dev/null | sort -rn | head -20
# Flag: >300 LOC = WARNING, >500 LOC = HIGH severity

# TypeScript — same threshold
find . \( -name '*.ts' -o -name '*.tsx' \) ! -path '*/node_modules/*' ! -path '*/dist/*' \
  | xargs wc -l 2>/dev/null | sort -rn | head -20

# Python
find . -name '*.py' ! -path '*/.venv/*' ! -path '*/test*' \
  | xargs wc -l 2>/dev/null | sort -rn | head -20
```

**Reporting:** "CanvasService.java (609 LOC) — God class [HIGH]: manages Canvas, Sketch, Note, PhotoMarkup entities. Hard to test, modify, or reason about."

### Field Injection Detection (Java)

```bash
# Count @Autowired usage (field injection)
FIELD=$(grep -rc '@Autowired' --include='*.java' src/main/ | awk -F: '{s+=$2}END{print s}')
# Count constructor injection indicator
CONST=$(grep -rc 'private final' --include='*.java' src/main/ | awk -F: '{s+=$2}END{print s}')
# Report ratio
echo "Field injection: $FIELD | Constructor injection indicators: $CONST"
```

**Thresholds:** 0 `@Autowired` = constructor-only (GOOD). Any `@Autowired` on fields = flag.

### Reflection in Business Logic

```bash
# Java
grep -rn 'ReflectionUtils\.\|getDeclaredField\|setAccessible(true)\|Method\.invoke\|ParameterizedType\|getGenericSuperclass' \
  --include='*.java' src/main/ | grep -v 'config\|Config\|//.*'
```

**Context matters:** If reflection appears only in `@Configuration` classes or framework init code → acceptable. If in service layer `create()`/`update()`/`delete()` methods → HIGH severity.

**Reporting:** "ReflectionUtils.doWithFields() invoked in LeafCrudService.create(), BranchCrudService.update(), RootCrudService.delete() — reflection in CRUD hot path [HIGH]: performance overhead on every operation, breaks on field renames."

### Parallel Class Hierarchy Detection

```bash
# Naming pattern — classes sharing prefix/suffix
grep -rn 'class Root.*Service\|class Branch.*Service\|class Leaf.*Service' --include='*.java' src/
grep -rn 'class Root.*Controller\|class Branch.*Controller\|class Leaf.*Controller' --include='*.java' src/
# V1/V2 versioned duplication
grep -rn 'class .*V1\b\|class .*V2\b' --include='*.java' --include='*.ts' src/
```

**Follow-up:** If parallel hierarchy detected, diff key methods (e.g., `create()`, `update()`, `delete()`) across the N classes. Identical or near-identical method bodies = structural duplication.

### Dual Cascade / Dual Event Handling

```bash
# Detect MongoEventListener (automatic) AND explicit cascade callbacks (manual)
LISTENERS=$(grep -rl 'AbstractMongoEventListener\|@EventListener.*Before\|onBeforeDelete\|onBeforeSave' \
  --include='*.java' src/main/ | wc -l)
CALLBACKS=$(grep -rl 'ReflectionUtils.*FieldCallback\|CascadeDelete\|CascadeSave' \
  --include='*.java' src/main/ | wc -l)
# If both > 0: investigate for dual cascade path race condition
```

### Exception Handling Anti-Patterns

```bash
# Broad exception catching
grep -rn 'catch (Exception \|catch (Throwable ' --include='*.java' src/main/
# Distinguish: wrap-and-rethrow (acceptable) vs swallow (HIGH severity)
grep -A5 'catch (Exception ' src/main/**/*.java | grep -E '^\s*(//.*|})$'  # empty or comment-only = swallow

# Log-and-throw (duplication)
grep -B2 'throw ' --include='*.java' src/main/ | grep -B1 'log\.error\|logger\.error'

# Python broad except
grep -rn 'except:\|except Exception:' --include='*.py' src/
```

### Convention Conflict Detection

```bash
# Mixed DI styles (field + constructor in same codebase)
HAS_AUTOWIRED=$(grep -rl '@Autowired' --include='*.java' src/main/ | wc -l)
HAS_FINAL=$(grep -rl 'private final' --include='*.java' src/main/ | wc -l)
# If HAS_AUTOWIRED > 0 AND HAS_FINAL > 0: "mixed DI styles [MEDIUM] — standardize on constructor injection"

# Mixed logging (some @Slf4j, some LoggerFactory.getLogger)
ANNOT=$(grep -rl '@Slf4j' --include='*.java' src/ | wc -l)
FACTORY=$(grep -rl 'LoggerFactory.getLogger' --include='*.java' src/ | wc -l)
# If both > 5: "mixed logging style [LOW] — pick one"

# Mixed test framework signals
grep -rl 'import org.junit.jupiter' --include='*.java' src/test/ | wc -l  # JUnit 5
grep -rl 'import org.junit.Test' --include='*.java' src/test/ | wc -l     # JUnit 4
grep -rl 'class.*Specification\b' --include='*.groovy' src/test/ | wc -l  # Spock
# Mixed → document which to use for new tests
```

### Legacy Patterns

```bash
# Legacy java.util.Date (should be java.time.*)
grep -rl 'import java\.util\.Date' --include='*.java' src/main/ | wc -l
# >5 files: document as tech debt "Migrate to java.time.Instant/LocalDate"

# Null returns instead of Optional
grep -rn 'return null;' --include='*.java' src/main/ | wc -l
# In service/repository layer: document as "use Optional<T> for nullable returns"
```

### Reporting Format for Wide Scan Results

In Phase 2 Quality Assessment, report Wide Scan findings with evidence:

```
**Watch:**
- [HIGH] God class: CanvasService.java (609 LOC) — manages 4 entity types; split recommended
- [HIGH] Reflection in CRUD hot path: ReflectionUtils.doWithFields() in LeafCrudService.create() — 
  performance overhead + no compile-time safety (CascadeSaveCallback.java, CascadeDeleteCallback.java)
- [MEDIUM] Dual cascade path: CascadeMongoEventListener + explicit CascadeDeleteCallback both fire 
  on delete — race condition risk (RootCrudService.java:85 acknowledges this)
- [MEDIUM] Legacy java.util.Date in 20+ files — timezone handling implicit; migrate to java.time.*
- [INFO] 18 broad catch(Exception) usages — most wrap-and-rethrow, acceptable; 2 may swallow errors

**Preserve:**
- Constructor-only DI: 0 @Autowired, 45+ private final declarations — excellent discipline
- Custom exception hierarchy: MeasValidationException + ErrorCode enum — clean error mapping
```

