# Rule File Templates

Templates for generating `.claude/rules/*.md` files. Each rule file must have `paths:` YAML frontmatter. Fill in the placeholders with patterns detected from actual source files — not generic advice.

---

## Java Conventions Template

**Filename:** `java-conventions.md`

```markdown
---
paths:
  - "**/*.java"
---

# Java Conventions — [Project Name]

Cross-cutting rules for all Java code in this project.

## Package Structure

[List actual packages found in the repo. Example:]
- `model` — domain models
- `repository` — repository interfaces
- `dto` — data transfer objects ([records / POJOs / Lombok] — detected)
- `service` — service interfaces
- `controller` — REST controllers
[Add actual packages found — remove packages not present]

## Naming Conventions

[Extract from sampled source files:]
- Interfaces: [detected pattern, e.g., "noun only, no 'Interface' suffix — `UserRepository` not `UserRepositoryInterface`"]
- Implementations: [detected pattern, e.g., "`Default<Name>` or `<Qualifier><Name>`"]
- Methods: [detected convention, e.g., "verbs — `findById`, `createUser`, `processPayment`"]
- Constants: [`UPPER_SNAKE_CASE` — verify from samples]

## Dependency Injection

[Choose one based on detection:]
- Constructor-based DI only — MUST NOT use `@Autowired` on fields
[OR if field injection found:]
- Currently uses field `@Autowired` — [note as tech debt if anti-pattern detected]

## Error Handling

[Extract from sampled catch blocks:]
- [Detected exception strategy — e.g., "unchecked exceptions only, no checked exceptions in application layer"]
- Catch specific exception types — MUST NOT catch `Exception` or `Throwable`
- [Log OR throw] — detected pattern from samples

## Logging

[Extract from sampled source files:]
- Logger: [`@Slf4j` / `LoggerFactory.getLogger` / other] — detected
- Format: [detected log format from samples, e.g., `log.info("{} - action completed", entityId)`]
- [Any detected prohibitions, e.g., "do not log in controllers — centralized filter handles it"]

| Level | When |
|-------|------|
| `INFO` | [detected use cases] |
| `DEBUG` | [detected use cases] |
| `WARN` | [detected use cases] |
| `ERROR` | [detected use cases] |

## Key Patterns

[Add patterns detected from source samples — e.g.:]
- [DI pattern with example if found]
- [Optional/null handling pattern]
- [Any framework-specific patterns detected]
```

---

## TypeScript / React Conventions Template

**Filename:** `typescript-conventions.md` (general TS) or `react-conventions.md` (React-specific)

```markdown
---
paths:
  - "**/*.ts"
  - "**/*.tsx"
[Scope to specific dirs if monorepo: "services/frontend/**/*.{ts,tsx}"]
---

# TypeScript/React Conventions — [Project Name]

## Imports

[Detect from sampled files — note any import sorting, grouping, or aliasing:]
- [Detected import order: e.g., "external → internal → relative"]
- [Path aliases if tsconfig has `paths`: e.g., "`@/components` → `src/components`"]
- [Any detected prohibitions]

## Naming

[Extract from sampled component/hook/util files:]
- Components: [e.g., PascalCase — `UserCard`, `PaymentForm`]
- Hooks: [e.g., `use` prefix — `useUserData`, `usePayment`]
- Types/Interfaces: [e.g., PascalCase, no `I` prefix]
- Files: [e.g., kebab-case or PascalCase — detect from actual filenames]
- [Constants: UPPER_SNAKE_CASE if detected]

## Component Structure

[Extract from sampled React component files:]
[Document the ordering/structure detected, e.g.:]
1. [Imports]
2. [Type definitions]
3. [Component function / default export]
4. [Helper functions if colocated]

[Note styling approach: CSS Modules / styled-components / Tailwind / etc.]

## State Management

[Detect from dependencies and usage:]
- [e.g., "Zustand for [scope] — stores in `stores/`"]
- [e.g., "Redux Toolkit for [scope] — slices in `store/`"]
- [React Query for server state — hooks in `hooks/`]

## Async / Data Fetching

[Detect pattern from samples:]
- [e.g., "React Query (`useQuery`/`useMutation`) for all API calls — no raw `useEffect` for data fetching"]
- [OR: custom hooks wrapping fetch/axios]
- [Error handling approach detected]

## Testing

[Detect from test files and config:]
- Framework: [Jest / Vitest] + [React Testing Library / Enzyme]
- Test location: [colocated `*.test.ts` / `__tests__/` directory]
- [Any detected testing patterns or prohibitions]
```

---

## Python Conventions Template

**Filename:** `python-conventions.md`

```markdown
---
paths:
  - "**/*.py"
---

# Python Conventions — [Project Name]

## Style

[Detect from pyproject.toml, ruff config, or sampled files:]
- Formatter: [black / ruff-format / autopep8] — [configured max line length]
- Linter: [ruff / flake8 / pylint]
- Type hints: [required/encouraged/optional — detect from samples]

## Naming

[Extract from sampled files:]
- Functions/variables: `snake_case`
- Classes: `PascalCase`
- Constants: `UPPER_SNAKE_CASE`
- Private: `_prefix` convention [if detected]
- [Module naming pattern if distinctive]

## Imports

[Detect from sampled files:]
- [Import sort order: stdlib → third-party → local]
- [Any `__future__` imports if Python 3.9 compat]
- [Detected import patterns — absolute vs relative]

## Error Handling

[Extract from sampled files:]
- [Detected exception hierarchy if custom exceptions defined]
- [Error propagation pattern]
- [Logging approach]

## [Framework-specific if detected]

[FastAPI / Django / Flask specific patterns detected from route handlers, models, etc.]
```

---

## Infrastructure / DevOps Rules Template

**Filename:** `infrastructure-context.md`

```markdown
---
paths:
  [Adjust globs to match detected infra files:]
  - "**/charts/**/*.yaml"
  - "**/Dockerfile*"
  - "env/**/*.ts"
  - "cicd/**/*.yaml"
  - ".github/workflows/**/*.yaml"
---

# Infrastructure Context — [Project Name]

## Deployment Model

[Describe detected deployment stack — e.g.:]
- **Platform:** [Kubernetes on AKS / EKS / GKE / bare Docker / etc.]
- **IaC:** [Helm + ArgoCD / Pulumi / Terraform / etc.]
- **CI/CD:** [Azure DevOps / GitHub Actions / Jenkins]
- **Environments:** [list detected environments: dev / staging / prod / etc.]

## Critical Rules

[Extract from detected patterns — these are the most important:]
- [e.g., "GitOps only — NEVER run `helm install`, `kubectl apply`, or `pulumi up` directly"]
- [e.g., "Secrets via [vault/secrets manager] — NEVER hardcode credentials"]
- [e.g., "Two Dockerfiles per service — [describe why if detectable]"]
- [Any detected must-follow patterns]

## Dockerfile Patterns

[If Dockerfiles detected, describe the pattern found:]
- Base image: [`eclipse-temurin:21-jre` / `node:20-alpine` / etc.]
- [Multi-stage build pattern if present]
- [Any project-specific conventions]

## Helm / K8s Patterns

[If Helm detected:]
- Values files: [e.g., `values.yaml` (defaults) + `values-<env>.yaml` (env overrides)]
- [Detected chart structure]
- [Any naming conventions for K8s resources]

## CI/CD Pipeline Structure

[Extract from pipeline config:]
- Stages: [list detected stages/jobs]
- Quality gates: [lint, test, coverage, security scan — which are present]
- [Any detected restrictions or conventions]
```

---

## Testing Rules Template

**Filename:** `testing-rules.md` (or `spock-testing-rules.md` for Groovy/Spock)

```markdown
---
paths:
  [Adjust to detected test file patterns:]
  - "**/*.test.ts"
  - "**/*.spec.ts"
  - "src/test/**/*.java"
  - "**/*Spec.groovy"
  - "**/*_test.py"
  - "tests/**/*.py"
---

# Testing Conventions — [Project Name]

## Framework & Setup

- Framework: [detected test framework]
- [Test runner configuration file location]
- [Coverage tooling and threshold if configured]

## Test Structure

[Extract from sampled test files:]
- [File/class naming convention: e.g., "`*Test.java` alongside main class", "`*.spec.ts` colocated"]
- [Test method/function naming: e.g., "snake_case describing behavior", "given_when_then"]
- [Setup/teardown patterns detected]

## Patterns

[Document detected testing patterns — e.g. for Spock:]
- `given:` — setup test data and stubs
- `when:` — execute the action
- `then:` — verify assertions

[Critical Spock-specific gotcha if detected:]
- NEVER stub in `given:` AND verify the same method in `then:` — Spock ignores the stub when mocking is set up that way
  ```groovy
  // WRONG — Spock ignores the stub:
  given: service.findById(id) >> Optional.of(entity)
  then: 1 * service.findById(id)  // verification ignores the stub above
  
  // CORRECT — stub in given, verify separately:
  given: service.findById(id) >> Optional.of(entity)
  then: result == expected  // don't re-verify stub calls
  ```

## What to Test

[Extract from detected test patterns:]
- [Unit test scope — what's mocked, what's real]
- [Integration test strategy if testcontainers/docker-compose detected]
- [Any detected test coverage requirements]
```

---

## Merge Strategy for Existing Rules

When a rule file already exists at `.claude/rules/<name>.md`:

1. Read the existing file
2. Identify what it already covers (sections present)
3. Check if detected patterns add new information not yet in the file
4. In Phase 2, report: "Existing `<name>.md` covers [X, Y]. Will add [Z] based on detected patterns."
5. In Phase 3, append new sections to the end, or update specific sections that are now outdated
6. Preserve all existing content that is still accurate — do NOT rewrite from scratch
