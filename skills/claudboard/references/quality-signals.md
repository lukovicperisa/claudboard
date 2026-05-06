# Quality Signals Reference

Use during Phase 1 (detection) and Phase 2 (quality assessment). Maps observable signals to quality judgments.

---

## Scoring Dimensions

Rate each dimension on a 1-10 scale (whole numbers only). Use these scores to determine adaptive rule depth:

| Dimension | 7-10 (Strong) | 4-6 (Acceptable) | 1-3 (Weak) |
|-----------|---------------|------------------|------------|
| Testing | Test framework + coverage + CI gate | Tests exist, no coverage threshold | No tests or tests not in CI |
| Architecture | Clear pattern, consistently applied | Pattern visible but inconsistent | No discernible pattern, ad hoc |
| Conventions | Enforced via lint/CI, consistent | Mostly consistent, occasional drift | Inconsistent, no enforcement |
| Dependencies | Pinned versions, BOM present, SBOM generated | Minor version debt, no BOM | Major version debt, cross-module mismatches |
| CI/CD | Multi-stage, quality gates, IaC | Basic CI, manual deploy | No CI or no deploy automation |
| Documentation | README + CLAUDE.md + inline where needed | README only | No documentation |
| Security | Security framework + method-level auth | Security framework, no method-level auth | No security framework detected |
| Observability | Actuator + metrics + tracing | Actuator or metrics only | No observability tooling |

**Scoring guidance:**
- 10: Exemplary - exceeds all criteria for that dimension
- 7-9: Strong - meets all criteria in "Strong" column
- 4-6: Acceptable - meets criteria in "Acceptable" column
- 1-3: Weak - meets criteria in "Weak" column or worse

**Adaptive rule depth decision:**
- Average ≥7.0 → **Full rules** (100-120 lines with code examples)
- Average 4.0-6.9 → **Medium rules** (60-80 lines) + ask user about unclear areas
- Average <4.0 → **Skeleton rules** (30-50 lines with TODOs) + note tech debt prominently

---

## Detection Checklist

Run in parallel during Phase 1. Check each item and record finding.

### Testing
- [ ] Test framework present? (JUnit, Spock, Jest, pytest, etc.)
- [ ] Test directories exist? (`src/test/`, `__tests__/`, `test/`, `spec/`)
- [ ] Test files exist? (`*.test.*`, `*.spec.*`, `*Test.java`, `*Spec.groovy`)
- [ ] Coverage tooling configured? (JaCoCo, Istanbul, coverage.py)
- [ ] Coverage threshold set? (in build config or CI)
- [ ] Tests in CI? (test step in pipeline config)
- [ ] Integration tests? (testcontainers, docker-compose.test.yml)
- [ ] E2E tests? (Playwright, Cypress config)

### Architecture
- [ ] Directory structure reveals a pattern? (hexagonal, layered, DDD)
- [ ] Pattern applied consistently across services/modules?
- [ ] Separation of concerns respected? (domain doesn't import infra)
- [ ] Service boundaries clear? (no cross-service direct imports)
- [ ] API surface defined? (OpenAPI spec, gRPC proto files)
- [ ] Domain model richness? (entities have behavior methods vs. only getters/setters — anemic vs. rich)

### Code Conventions
- [ ] Linting configured? (ESLint, Checkstyle, Ruff, golangci-lint)
- [ ] Formatting enforced? (Prettier, spotless, gofmt)
- [ ] Naming conventions consistent? (sample 3-5 files)
- [ ] DI pattern consistent? (constructor vs field injection in Java)
- [ ] Error handling pattern consistent? (Optional, exceptions, Result types)
- [ ] Broad exception catching? (count `catch (Exception e)` in production code — distinguish empty catches from wrap-and-rethrow)
- [ ] Logging framework consistent? (Slf4j, winston, structlog)
- [ ] TODO/FIXME count? (grep source)
- [ ] God classes? (files >500 lines)
- [ ] Long methods? (methods >30 lines — sample largest files)
- [ ] Method parameter count? (methods with >3 args common? any with >7? — see pattern-catalog.md → "Common Java/General Code Quality Rules")
- [ ] Boolean flag arguments? (methods like `process(data, true, false)` — hides intent)
- [ ] Log-and-throw? (`log.error` followed by `throw` in same catch block — duplicates error reporting)
- [ ] Star imports? (`import java.util.*` — hides dependencies)
- [ ] Reflection in business logic? (grep for `ReflectionUtils`, `getDeclaredField`, `setAccessible`, `Method.invoke` in non-config code — see pattern-catalog.md → "Reflection Anti-Patterns")
- [ ] Parallel class hierarchies? (classes with shared prefix/suffix: Root*/Branch*/Leaf*, *V1/*V2 — if found, diff key methods across hierarchies for duplication)
- [ ] Copy-paste duplication? (pick 2-3 distinctive code patterns from sampled files, grep for them — if same ~5-line block appears 3+ times in different files, flag it)

### Security
- [ ] Security framework present? (`SecurityFilterChain`, `@EnableMethodSecurity`, `@EnableWebSecurity`)
- [ ] Method-level auth annotations? (`@PreAuthorize`, `@Secured`, `@RolesAllowed`, or custom auth annotations)
- [ ] Custom auth annotation detected? (check `@interface` declarations with auth/authorize in name + `@Aspect` co-located)
- [ ] Auth coverage gap? (compare total controller endpoints count vs auth-annotated endpoint count — if AUTH < TOTAL: flag unprotected routes)
- [ ] CORS configured? (`CorsConfigurationSource`, `@CrossOrigin`, `addCorsMappings`)
- [ ] Auth filter chain? (`extends OncePerRequestFilter` or `implements Filter` in main source)

### API Surface
- [ ] Endpoint count tallied? (sum of `@GetMapping`, `@PostMapping`, `@PutMapping`, `@DeleteMapping`, `@PatchMapping`)
- [ ] API versioning strategy? (URL-based `/v1/`, `/v2/` in `@RequestMapping` values — or absent)
- [ ] OpenAPI/Swagger tooling? (`springdoc-openapi`, `springfox`, or `swagger` in dependencies)
- [ ] Pagination pattern? (check for `Pageable`, `Page<T>` in controller signatures)

### Observability
- [ ] Spring Actuator present? (`spring-boot-starter-actuator` in dependencies)
- [ ] Actuator endpoints configured? (`management.endpoints` in application properties)
- [ ] Metrics library present? (`micrometer-core` or `@Timed` annotations)
- [ ] Distributed tracing? (`micrometer-tracing`, `spring-cloud-sleuth`, `io.opentelemetry`)
- [ ] Structured logging? (`logstash-logback-encoder` dep or `net.logstash.logback` imports)

### Dependencies
- [ ] Version pinning strategy? (exact, patch, minor, major ranges)
- [ ] BOM (Bill of Materials) used? (`platform(` in Gradle, `<dependencyManagement>` BOM import in Maven)
- [ ] Mixed lockfiles? (package-lock + yarn.lock)
- [ ] Framework version current? (check against LTS/latest)
- [ ] Cross-module version mismatches? (same dep at different versions across modules — MEDIUM severity)
- [ ] Dependency conflict resolution? (`resolutionStrategy`/`force =` in Gradle, `<exclusions>` in Maven)
- [ ] SBOM generation? (`cyclonedx` or `spdx` plugin in build or CI)
- [ ] Security scanning? (Snyk, Dependabot, OWASP dependency-check)
- [ ] No hardcoded secrets? (grep for password=, api_key=, secret=)

### CI/CD
- [ ] CI platform identified?
- [ ] Build step in CI?
- [ ] Test step in CI?
- [ ] Lint/quality gate in CI?
- [ ] Deployment automated?
- [ ] Environment promotion strategy? (dev → staging → prod)
- [ ] Secrets management? (Azure Key Vault, AWS Secrets Manager, GitHub Secrets)

### Documentation
- [ ] README exists and is non-trivial?
- [ ] CLAUDE.md exists? (existing onboarding)
- [ ] Architecture decision records? (ADR/ or docs/adr/)
- [ ] API documentation? (OpenAPI, Javadoc, JSDoc)
- [ ] Deployment runbook?

---

## Quality Report Template

Use this exact structure for the Quality Assessment section in Phase 2:

```
### Quality Assessment

Score each dimension 1-10 (whole numbers only).

**Testing:** [N]/10
Evidence: [test framework, CI gate status, coverage %]

**Architecture:** [N]/10
Evidence: [pattern name, consistency]

**Conventions:** [N]/10
Evidence: [linting enforcement, DI pattern, god classes]

**Dependencies:** [N]/10
Evidence: [versions, BOM status, SBOM, cross-module mismatches]

**CI/CD:** [N]/10
Evidence: [pipeline stages, quality gates]

**Documentation:** [N]/10
Evidence: [README, CLAUDE.md, ADRs]

**Security:** [N]/10
Evidence: [security framework, method-level auth, CORS config, auth coverage]

**Observability:** [N]/10
Evidence: [actuator, metrics, tracing, structured logging]

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

**API Surface:**
- Controllers: N | Endpoints: ~M (GET:X POST:Y PUT:Z DELETE:W)
- Versioning: [URL-based v1/v2 / None detected]
- Documentation: [springdoc-openapi / springfox / None]

**Preserve:**
- [Good pattern 1] — [where found]
- [Good pattern 2] — [where found]

**Watch:**
- [SEVERITY] [Anti-pattern or inconsistency] — [file/location]
- [HIGH — compound] [Finding A] + [Finding B] → [risk description] (individually: [severityA] + [severityB])

**Skill overlap detected (if any):**
- `[skill-a]` and `[skill-b]` overlap — both target [shared files/triggers]. Merge into one or keep separate with distinct scopes?

**Debt:**
- [INFO] [Tech debt item] — [impact if not addressed]
```

---

## Token Estimation Guide

Use these heuristics to estimate persistent context overhead for the Phase 2 report.

**Rough token estimates per artifact type:**
- CLAUDE.md: ~1.2 tokens per line (mostly prose, tables)
- Rule files: ~1.3 tokens per line (prose + code examples)
- SKILL.md files: ~1.4 tokens per line (prose + code blocks + YAML frontmatter)
- Reference files in skills: not loaded by default (on-demand when skill triggers) — exclude from persistent count

**What counts as persistent context:**
- `CLAUDE.md`: always loaded on every prompt
- `.claude/rules/*.md`: loaded when the user's query touches files matching the `paths:` globs
- `.claude/skills/*/SKILL.md`: loaded when the skill description matches user intent (not always)

**Reporting format for Phase 2:**
- Sum estimated lines across all proposed artifacts
- Multiply by ~1.3 (blended rate) for token estimate
- Report as "~X tokens persistent context" in the Context Overhead Estimate table
- If total exceeds 5,000 tokens: note "substantial context overhead — consider whether all proposed artifacts are needed"

---

## Rule Depth Decision Guide

After scoring, decide rule depth per language/concern:

### Full rules (write 80-120 lines with real code examples from repo)

When you find:
- Consistent naming convention across 3+ sampled files
- Clear DI/error handling/logging pattern applied uniformly
- Linting/formatting config that can inform the rules
- The pattern is sophisticated enough that a developer could violate it without guidance

Example trigger: Java codebase with consistent `@Slf4j`, constructor DI, `Optional` returns, Lombok — write full `java-conventions.md` with code examples from actual service files.

### Medium rules (write 50-70 lines, fewer code examples)

When you find:
- Pattern mostly consistent but 1-2 exceptions seen
- Linting exists but rules are basic
- Conventions are simple enough to state without extensive examples

### Skeleton rules (write 30-50 lines with TODOs)

When you find:
- Inconsistent patterns — different files use different approaches
- No linting enforcement — conventions are ad hoc
- Messy or legacy code where extracting "the pattern" would be misleading

Write skeleton with TODOs like:
```markdown
## Naming Conventions
<!-- TODO: Identify consistent naming pattern — currently inconsistent across the codebase -->
- [Document your team's actual conventions here]
```

In Phase 2 report, ask user: "Naming conventions appear inconsistent — should I document the predominant pattern or leave this section as TODO for you to fill in?"

---

## Skill Generation Triggers

Use these to decide which skills to generate. Triggers are detected during Wide Scan (step 1c) via grep across the entire repo.

### Standard Triggers

| Codebase signal | Grep pattern | Generate skill | Priority |
|-----------------|-------------|---------------|---------|
| Spring `@RestController` | `@RestController` | `rest-controller` | HIGH |
| Spring `@Repository` + MongoDB | `@Document` + `@Repository` | `mongodb-persistence` | HIGH |
| Spring `@Service` + use-case | service class extending base | `use-case` or `domain-service` | HIGH |
| `@KafkaListener` | `@KafkaListener\|@KafkaHandler` | `kafka-consumer` | HIGH |
| `@RabbitListener` | `@RabbitListener` | `rabbitmq-consumer` | HIGH |
| `@FeignClient` | `@FeignClient` | `feign-client` | HIGH |
| `@Aspect` + `@Around`/`@Before` | `@Aspect` | `aop-aspect` | MEDIUM |
| `@Scheduled` + `@EnableScheduling` | `@Scheduled` | `scheduled-task` | MEDIUM |
| `@Async` + `@EnableAsync` | `@Async\|@EnableAsync` | `async-task` | MEDIUM |
| `@EventListener` | `@EventListener\|ApplicationEvent` | `event-handler` | MEDIUM |
| `@MessageMapping` | `@MessageMapping\|WebSocketHandler` | `websocket-handler` | MEDIUM |
| GraphQL resolvers | `@GraphQlController\|@QueryMapping\|@MutationMapping` | `graphql-resolver` | MEDIUM |
| Spring CLI | `@ShellComponent\|@ShellMethod` | `cli-command` | MEDIUM |
| Custom validators | `implements ConstraintValidator\|implements Validator` | `validator` | MEDIUM |
| Spring Security config | `SecurityFilterChain\|@EnableMethodSecurity` | `security-config` | MEDIUM |
| React components (consistent) | `.tsx` files with consistent structure | `component` | HIGH |
| React Query | `useQuery\|useMutation` | `api-hook` | MEDIUM |
| react-hook-form | `react-hook-form\|useForm` | `form` | MEDIUM |
| Zustand stores | `zustand\|create(` | `zustand-store` | MEDIUM |
| Redux Toolkit | `createSlice\|createAsyncThunk` | `redux-slice` | MEDIUM |
| Module Federation | `ModuleFederationPlugin` | `mfe-remote` | HIGH |
| Helm charts | `charts/` dir with `Chart.yaml` | `helm-update` | MEDIUM |
| DB migrations (Flyway/Liquibase) | `V\d+__.*\.sql\|R__.*\.sql` | `db-migration` | MEDIUM |
| DB migrations (Alembic/Prisma) | `alembic/\|*.migration.ts` | `db-migration` | MEDIUM |
| gRPC proto files | `*.proto` | `grpc-service` | HIGH |
| MCP server handlers | `@modelcontextprotocol/sdk\|mcp-tool\|@tool` | `mcp-tool` | HIGH |
| FastAPI routes | `@router.get\|@router.post\|@app.route` | `api-endpoint` | HIGH |
| Django models | `models.Model\|django.db` | `django-model` | HIGH |
| Dockerfiles | `Dockerfile` | `dockerfile` | LOW |
| Azure/GitHub pipelines | `azure-pipelines.yml\|.github/workflows` | `pipeline` | LOW |

### Custom Pattern Triggers (from Wide Scan)

These triggers are discovered dynamically from the repo's own code, not pre-defined:

| Wide Scan finding | Condition | Generate skill | Priority |
|-------------------|-----------|---------------|---------|
| Abstract base class | 5+ concrete subclasses extend it | skill named after base class pattern | HIGH |
| Custom annotation | 5+ classes annotated with it | include annotation usage in relevant skill | MEDIUM |
| Custom annotation | defines a workflow (e.g., `@Authorize`, `@Cascade`) | generate dedicated skill for that workflow | HIGH |
| Parallel hierarchy | Root*/Branch*/Leaf* naming with 3+ per level | skill for "adding a new entity to the hierarchy" | HIGH |

**Example:** If Wide Scan finds `LeafCrudService` has 5 subclasses, generate a `leaf-crud-entity` skill that shows the full pattern of adding a new leaf entity — even though `@LeafCrudService` isn't in the standard trigger catalog.

### Skill Count and Prioritization

**Maximum 8 skills per run** — avoid overwhelming. When more than 8 triggers fire:
1. Rank by usage count (more files using the pattern = higher priority)
2. Prefer HIGH priority standard triggers over MEDIUM
3. Prefer custom pattern triggers (unique to this project) over generic standard triggers
4. Keep at least 1 custom pattern skill if any were found

**Minimum:** Generate at least 1 skill if any signal is found. A project with zero skills is under-served.

### Skill Deduplication (run after trigger collection, before Phase 2 report)

After all skill triggers are collected, check each pair of proposed skills for overlap:

**Overlap criteria (either condition triggers dedup check):**
1. **File glob intersection >50%** — e.g., both `mongodb-entity` and `leaf-entity` target `**/model/*.java`
2. **Same trigger annotation in both scopes** — e.g., `@Document` fires for both mongodb-persistence and a custom hierarchy skill

**Action:**
- Flag overlapping pairs in the Phase 2 report under "Skill overlap detected"
- Ask user: "These skills overlap — merge into one or keep separate with distinct scopes?"
- If merge: generate one combined skill in Phase 3 covering both concerns
- If keep separate: add explicit scope distinction to each SKILL.md description field
- **Never auto-merge without user confirmation**

**Common overlaps to watch for:**

| Pair | Why they overlap | Resolution guidance |
|------|-----------------|-------------------|
| `mongodb-entity` + custom hierarchy skill | MongoDB entities ARE the hierarchy entities | Merge; hierarchy skill covers entity creation end-to-end |
| `rest-controller` + `leaf-entity` | Leaf entity skill creates controllers too | Keep separate; leaf-entity is end-to-end, rest-controller is controller-only |
| `use-case` + `domain-service` | Same concept, different names | Merge; pick name matching codebase vocabulary |
