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

Load `../claudboard/references/stack-detectors.md` first — it lists which files to check and what to extract per language.

### 1a. Parallel file detection

In a single pass, check for all of the following in parallel:

**Build & dependency files:** `package.json`, `tsconfig.json`, `pom.xml`, `build.gradle`, `build.gradle.kts`, `settings.gradle`, `go.mod`, `pyproject.toml`, `requirements.txt`, `Cargo.toml`, `*.csproj`, `*.sln`, `Makefile`, `Taskfile.yml`, `gradle/libs.versions.toml`

**Container & infra:** `Dockerfile`, `docker-compose.yml`, `docker-compose.test.yml`, any `charts/` or `helm/` directory, `kustomization.yaml`, `Pulumi.yaml`, `terraform/`

**CI/CD:** `.github/workflows/*.yml`, `azure-pipelines.yml`, `Jenkinsfile`, `.gitlab-ci.yml`, `.circleci/config.yml`

**Existing Claude config:** `CLAUDE.md`, `.claude/rules/*.md`, `.claude/skills/*/SKILL.md`, `.claude/memories/*.md`, `.claude/settings.json`, `.mcp.json`

**Documentation:** `README.md`, `README`, `docs/adr/`, `ADR/`

### 1b. Structure mapping

List top-level directories (annotate each). Detect monorepo: look for multiple independent build files at depth 1-2, or `services/`, `packages/`, `apps/` containing sub-projects with their own build configs. See `../claudboard/references/stack-detectors.md` → "Monorepo Boundary Detection".

Skip: `node_modules/`, `.git/`, `dist/`, `build/`, `target/`, `__pycache__/`, `.venv/`, `vendor/`, `.gradle/`, `.idea/`

### 1c. Wide Scan (pattern inventory)

**Skip if repo has <50 source files** — read all source files directly in step 1d instead.

Run grep-based scans across the entire repo before reading any source file fully. See `../claudboard/references/stack-detectors.md` → "Wide Scan Grep Patterns" for exact commands per language.

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

Also run security, API surface, and observability scans **in the same parallel pass** — see `../claudboard/references/stack-detectors.md` → "Security posture signals", "API surface signals", "Observability signals". Record findings alongside anti-patterns.

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

## Phase 2: Analysis Report

Present findings to the user. Use **WHAT / HOW / WHY / CONCERNS** structure.

Load `../claudboard/references/pattern-catalog.md` to identify architecture patterns and anti-patterns. Load `../claudboard/references/quality-signals.md` to score quality dimensions and decide rule depth.

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

[For monorepos: include service map table]

### Why (reasoning behind decisions)
- <detected constraint → inferred decision>
  e.g., "Azure Pipelines → team is on Azure; Pulumi TypeScript → IaC in same language as app code"

### Quality Assessment

**Architecture maturity:** [Established / Transitional / Ad-hoc]
Evidence: [1 sentence]

**Testing coverage:** [Comprehensive / Basic / Missing]
Evidence: [framework, CI gate, coverage %]

**Convention consistency:** [Enforced / Mostly consistent / Inconsistent]
Evidence: [linting, sample finding]

**Dependency health:** [Current / Minor debt / Major debt]
Evidence: [versions, BOM status, SBOM, cross-module mismatches]

**CI/CD maturity:** [Full pipeline / Basic CI / Missing]
Evidence: [pipeline stages]

**Security:** [Enforced / Basic / Missing]
Evidence: [framework, method-level auth, CORS, auth coverage gap]

**Observability:** [Good / Acceptable / Debt]
Evidence: [actuator, metrics, tracing, structured logging]

**API Surface:**
- Controllers: N | Endpoints: ~M (GET:X POST:Y PUT:Z DELETE:W)
- Versioning: [URL-based v1/v2 / None detected]
- Documentation: [springdoc-openapi / springfox / None]

**Reflection usage:** [None / Config-only / Business-logic (flag)] — from Phase 1c grep
**Code duplication:** [None detected / Minor / Structural (parallel hierarchies)] — from Phase 1g

**Preserve:**
- <good pattern> — <where found>

**Watch:**
- [SEVERITY] <anti-pattern> — <file/location>
Include findings from Phase 1f (call-path tracing) and Phase 1g (duplication detection).
For reflection or deeply-embedded anti-patterns: note whether they belong
in conventions rules (actionable today) or tech-debt rules (document but
can't avoid in current architecture). See pattern-catalog.md →
"Reflection Anti-Patterns" → "Reporting guidance".

After listing all Watch findings, **apply compound severity rules** from `../claudboard/references/pattern-catalog.md` → "Compound Severity Rules":
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

### Proposed Artifacts

**CLAUDE.md** — [outline: commands table, architecture bullets, rules/skills index, critical rules count]
[If existing: "Will add [X] to existing CLAUDE.md — preserving current content"]

**Rules (N files):**
- `<filename>.md` (paths: `<glob>`) — <what it covers, adaptive depth: full/medium/skeleton>

**Skills (M to generate):**

Before listing skills, **run skill dedup check** (see `../claudboard/references/quality-signals.md` → "Skill Deduplication"):
- Compare each pair of proposed skills for file glob overlap >50% or shared trigger annotations
- If overlap found: list the pair and ask user to merge or keep separate before proceeding
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

Present this report to the user.

If patterns are ambiguous or inconsistent, ask the user now — e.g.:
- "Found both field injection and constructor injection — which should be the standard?"
- "Naming conventions vary between modules — document the predominant pattern or leave as TODO?"
- "Skills X and Y overlap — merge into one or keep separate?"

---

## Phase 3: Save Report & Next Steps

After presenting the analysis, save the full report to `.claude/reports/claudboard-analysis.md`.

Create the `.claude/reports/` directory if it doesn't exist.

The saved file must include YAML frontmatter:

```yaml
---
generated_at: <ISO 8601 timestamp>
repo: <absolute path to project root>
version: "2.0.0"
---
```

Followed by the full analysis report content (same WHAT/HOW/WHY/CONCERNS structure shown to the user).

After saving, ask the user:

> Should I continue with artifact generation? (Recommended: run `/generate` in a fresh session for best results — the analysis phase fills context with discovery data that isn't needed during generation.)

- If yes: proceed with generation by following `../claudboard-generate/SKILL.md` steps
- If no: end with "Analysis saved to `.claude/reports/claudboard-analysis.md`. Run `/generate` in a fresh session when ready."

---

## Error Handling

| Condition | Behavior |
|-----------|----------|
| Target path doesn't exist | Report error with path and stop |
| No source files found | Report "no source files found at [path]", suggest checking the path, stop |
| Grep command returns no results | Continue — report "none detected" for that category |
| Build file not recognized | Note "unrecognized project type" and proceed with structure-based analysis |

## Constraints

- **Read-only for source code.** The only file written is `.claude/reports/claudboard-analysis.md`.
- **Never modify source code, tests, or existing files.**
- **Max ~50 source files read** for large repos — note sampling in report.
- **Secrets found during scan:** Report file:line only, never print the value.
- **If path doesn't exist:** State clearly and stop.

## Reference Files

| File | When to load |
|------|-------------|
| `../claudboard/references/stack-detectors.md` | Start of Phase 1 |
| `../claudboard/references/pattern-catalog.md` | Phase 2 — pattern/anti-pattern identification |
| `../claudboard/references/quality-signals.md` | Phase 2 — quality scoring, rule depth, skill triggers |
