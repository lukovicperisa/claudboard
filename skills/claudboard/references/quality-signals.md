# Quality Signals Reference

Use during Phase 1 (detection) and Phase 2 (quality assessment). Maps observable signals to quality judgments.

---

## Scoring Dimensions

Rate each dimension during analysis. Use these to determine adaptive rule depth:

| Dimension | Good | Acceptable | Debt |
|-----------|------|-----------|------|
| Testing | Test framework + coverage + CI gate | Tests exist, no coverage threshold | No tests or tests not in CI |
| Architecture | Clear pattern, consistently applied | Pattern visible but inconsistent | No discernible pattern, ad hoc |
| Conventions | Enforced via lint/CI, consistent | Mostly consistent, occasional drift | Inconsistent, no enforcement |
| Dependencies | Pinned versions, no duplicates, current | Minor version debt | Major version debt, duplicates |
| CI/CD | Multi-stage, quality gates, IaC | Basic CI, manual deploy | No CI or no deploy automation |
| Documentation | README + CLAUDE.md + inline where needed | README only | No documentation |

**Adaptive rule depth decision:**
- 4+ dimensions "Good" → **Full rules** (100-120 lines with code examples)
- 2-3 dimensions "Good" → **Medium rules** (60-80 lines) + ask user about unclear areas
- <2 dimensions "Good" → **Skeleton rules** (30-50 lines with TODOs) + note tech debt prominently

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

### Dependencies
- [ ] Version pinning strategy? (exact, patch, minor, major ranges)
- [ ] Mixed lockfiles? (package-lock + yarn.lock)
- [ ] Framework version current? (check against LTS/latest)
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

**Architecture maturity:** [Established / Transitional / Ad-hoc]
Evidence: [1 sentence]

**Testing coverage:** [Comprehensive / Basic / Missing]
Evidence: [test framework, CI gate status, coverage %]

**Convention consistency:** [Enforced / Mostly consistent / Inconsistent]
Evidence: [linting config, sample finding]

**Dependency health:** [Current / Minor debt / Major debt]
Evidence: [versions found, any issues]

**CI/CD maturity:** [Full pipeline / Basic CI / Missing]
Evidence: [pipeline stages found]

**Preserve:**
- [Good pattern 1] — [where found]
- [Good pattern 2] — [where found]

**Watch:**
- [WARN] [Anti-pattern or inconsistency] — [file/location]

**Debt:**
- [INFO] [Tech debt item] — [impact if not addressed]
```

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
