# Stack Detectors: Java / Kotlin

Use during Phase 1 detection to identify Java/Kotlin projects and extract framework/dependency information.

## Detection Heuristics

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

## Wide Scan Grep Patterns

Run during Phase 1 step 1c. All greps exclude build output dirs. Run in parallel.

### 1. Custom Patterns (Inheritance & Annotations)

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

### 2. Anti-Pattern Signals

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

### 3. Convention Frequency

```bash
# Logging style: @Slf4j vs LoggerFactory
SLF4J_ANNOT=$(grep -rl '@Slf4j' --include='*.java' src/ | wc -l)
SLF4J_FACTORY=$(grep -rl 'LoggerFactory.getLogger' --include='*.java' src/ | wc -l)
# Report: "@Slf4j (N files) vs LoggerFactory (M files)"

# Test naming pattern
find src/test -name '*Test.java' -o -name '*Spec.groovy' -o -name '*IT.java' 2>/dev/null | head -5
```

### 4. Security Posture Signals

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

### 5. API Surface Signals

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

### 6. Observability Signals

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

### 7. Dependency Deep-Scan Signals

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
