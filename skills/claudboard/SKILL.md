---
name: claudboard
description: >
  Deep-analyzes an existing project or repository and bootstraps Claude Code's understanding
  by generating production-ready .claude/ artifacts: CLAUDE.md, rules with paths: frontmatter,
  full-scope skills (with references/ and scripts/), and memories. Goes beyond surface scanning
  to detect architecture patterns, coding conventions, testing strategies, CI/CD pipelines,
  infrastructure, good patterns, anti-patterns, and tech debt.
  Use this skill whenever the user says /claudboard, "onboard this project", "bootstrap Claude
  for this repo", "set up Claude Code for this project", "analyze this codebase", "generate
  rules for this project", "create CLAUDE.md", "scan this repo", "understand this project",
  "help me onboard to this codebase", or asks for a project health check, architecture audit,
  or code quality review. Also triggers on "what patterns does this repo use", "generate coding
  rules from this codebase", or when starting work on an unfamiliar or brownfield project.
---

# Claudboard — Project Onboarding Agent

Analyzes a repository and generates Claude Code artifacts that let you work on it immediately: CLAUDE.md, rules, and full-scope skills tailored to the project's actual patterns.

**Read-only during Phases 1 and 2.** Writes only to `.claude/` in Phase 3, after user confirms.

## Invocation

```
/claudboard [path]
```

Path defaults to the current working directory. Works on any language/framework.

---

## Phase 1: Discovery

Load `references/stack-detectors.md` first — it lists which files to check and what to extract per language.

### 1a. Parallel file detection

In a single pass, check for all of the following in parallel:

**Build & dependency files:** `package.json`, `tsconfig.json`, `pom.xml`, `build.gradle`, `build.gradle.kts`, `settings.gradle`, `go.mod`, `pyproject.toml`, `requirements.txt`, `Cargo.toml`, `*.csproj`, `*.sln`, `Makefile`, `Taskfile.yml`, `gradle/libs.versions.toml`

**Container & infra:** `Dockerfile`, `docker-compose.yml`, `docker-compose.test.yml`, any `charts/` or `helm/` directory, `kustomization.yaml`, `Pulumi.yaml`, `terraform/`

**CI/CD:** `.github/workflows/*.yml`, `azure-pipelines.yml`, `Jenkinsfile`, `.gitlab-ci.yml`, `.circleci/config.yml`

**Existing Claude config:** `CLAUDE.md`, `.claude/rules/*.md`, `.claude/skills/*/SKILL.md`, `.claude/memories/*.md`, `.claude/settings.json`, `.mcp.json`

**Documentation:** `README.md`, `README`, `docs/adr/`, `ADR/`

### 1b. Structure mapping

List top-level directories (annotate each). Detect monorepo: look for multiple independent build files at depth 1-2, or `services/`, `packages/`, `apps/` containing sub-projects with their own build configs. See `references/stack-detectors.md` → "Monorepo Boundary Detection".

Skip: `node_modules/`, `.git/`, `dist/`, `build/`, `target/`, `__pycache__/`, `.venv/`, `vendor/`, `.gradle/`, `.idea/`

### 1c. Wide Scan (pattern inventory)

**Skip if repo has <50 source files** — read all source files directly in step 1d instead.

Before reading any source file fully, run grep-based scans across the entire repo. This is fast, reads zero full files, and gives you a complete inventory to make strategic sampling decisions.

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
# Same for .ts, .py as needed

# Field injection (Java)
grep -rc '@Autowired' --include='*.java' src/main/

# Broad exception catching
grep -rn 'catch (Exception\|catch (Throwable' --include='*.java' src/main/

# Null returns (signal for Optional improvement)
grep -rn 'return null;' --include='*.java' src/main/

# Legacy date usage (Java)
grep -rl 'import java.util.Date' --include='*.java' src/

# Console logging in production
grep -rn 'System\.out\.print\|System\.err\.print' --include='*.java' src/main/
grep -rn '\bconsole\.log\b' --include='*.ts' src/ --exclude-dir=test

# Star imports
grep -rn 'import .*\.\*;' --include='*.java' src/

# Reflection in business logic
grep -rn 'ReflectionUtils\|getDeclaredField\|setAccessible\|Method\.invoke\|ParameterizedType' \
  --include='*.java' src/main/

# TODO/FIXME/HACK density
grep -rc 'TODO\|FIXME\|HACK' --include='*.java' --include='*.ts' --include='*.py' src/ \
  | grep -v ':0$'

# TypeScript `any` usage
grep -rn '\bany\b\|// @ts-ignore\| as any\b' --include='*.ts' src/

# Python broad except
grep -rn 'except Exception\|except:\|bare except' --include='*.py' src/
```

**Convention frequency** (DI style, logging, naming consistency):
```
# Java DI ratio
FIELD_INJ=$(grep -rc '@Autowired' --include='*.java' src/main/ | awk -F: '{s+=$2}END{print s}')
CONST_DI=$(grep -rc 'private final' --include='*.java' src/main/ | awk -F: '{s+=$2}END{print s}')
# Report: "constructor-only (0 @Autowired, 45+ private final)" or "mixed (N field vs M constructor)"

# Logging style (Java)
grep -rl '@Slf4j' --include='*.java' src/ | wc -l
grep -rl 'LoggerFactory.getLogger' --include='*.java' src/ | wc -l

# Test naming patterns
ls src/test/**/*Test.java src/test/**/*Spec.groovy 2>/dev/null | head -5
```

**Output: Pattern Inventory** (internal — use it to drive step 1d decisions):
```
inheritance_map: [base class → subclass count + sample files]
custom_annotations: [annotation name → usage count + files]
skill_triggers: [trigger → count + best_example file]
anti_patterns: [type → severity + count + files]
god_class_candidates: [file → LOC]
conventions: {di_style, logging, test_naming}
```

### 1d. Strategic sampling (replaces random file selection)

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

Check for test framework, test directories, coverage tooling, and whether tests appear in CI pipeline. See `references/quality-signals.md` → "Testing" checklist.

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
- **Reflection:** any `ReflectionUtils`, `getDeclaredField`, `setAccessible` in the hot path (see `references/pattern-catalog.md` → "Reflection Anti-Patterns")
- **Duplicated logic:** same method body across parallel hierarchies (Root*, Branch*, Leaf*)
- **Defensive code:** try-catch inside lambdas, silent null guards repeated everywhere

### 1g. Duplication detection

After sampling source files, pick 2-3 distinctive code patterns seen in the first files (e.g., a try-catch inside a lambda, a reflection call sequence, a validation block). Grep for them across the codebase. If the same ~5-line pattern appears 3+ times in different files, flag as "copy-paste duplication" in the anti-patterns section.

Also check for parallel class hierarchies: classes with shared naming patterns (e.g., `Root*Service`, `Branch*Service`, `Leaf*Service`). If found, diff key methods across hierarchies — identical or near-identical method bodies indicate structural duplication.

### 1h. Existing `.claude/` inventory

If `.claude/` exists:
- List all existing rules (filenames + `paths:` globs)
- List all existing skills (names)
- Note what's covered — Phase 3 will only fill gaps, never overwrite

---

## Phase 2: Analysis Report

Present findings before generating anything. Use **WHAT / HOW / WHY / CONCERNS** structure.

Load `references/pattern-catalog.md` to identify architecture patterns and anti-patterns. Load `references/quality-signals.md` to score quality dimensions and decide rule depth.

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
**Testing coverage:** [Comprehensive / Basic / Missing]
**Convention consistency:** [Enforced / Mostly consistent / Inconsistent]

**Reflection usage:** [None / Config-only / Business-logic (flag)] — from Phase 1e grep
**Code duplication:** [None detected / Minor / Structural (parallel hierarchies)] — from Phase 1f

**Preserve:**
- <good pattern> — <where found>

**Watch:**
- [WARN] <anti-pattern> — <file/location>
Include findings from Phase 1e (call-path tracing) and Phase 1f (duplication detection).
For reflection or deeply-embedded anti-patterns: note whether they belong
in conventions rules (actionable today) or tech-debt rules (document but
can't avoid in current architecture). See pattern-catalog.md →
"Reflection Anti-Patterns" → "Reporting guidance".

**Debt:**
- [INFO] <tech debt> — <impact>

### Proposed Artifacts

**CLAUDE.md** — [outline: commands table, architecture bullets, rules/skills index, critical rules count]
[If existing: "Will add [X] to existing CLAUDE.md — preserving current content"]

**Rules (N files):**
- `<filename>.md` (paths: `<glob>`) — <what it covers, adaptive depth: full/medium/skeleton>

**Skills (M to generate):**
- `<skill-name>/` — <what triggers it, what it creates, full scope: SKILL.md + references/ + scripts/>

[If existing .claude/ found:]
**Already covered (no action):**
- `<existing rule>` — <covers X, no gaps detected>
- `<existing skill>` — already defined

---
Generate these artifacts? [y/n]
If n: which parts should I skip or change?
```

**Pause here.** Wait for user confirmation before Phase 3.

If patterns are ambiguous or inconsistent, ask the user now — e.g.:
- "Found both field injection and constructor injection — which should be the standard?"
- "Naming conventions vary between modules — document the predominant pattern or leave as TODO?"

---

## Phase 3: Artifact Generation

Write files to `.claude/` in the target project. Never write outside `.claude/`. Never modify existing source files.

Load these references as needed:
- `references/claude-md-template.md` → for CLAUDE.md structure
- `references/rule-templates.md` → for rule file templates
- `references/skill-generation.md` → for full-scope skill generation

### 3a. Generate or update CLAUDE.md

Follow `references/claude-md-template.md` exactly. Target 60-120 lines.

**If CLAUDE.md exists:** Read it, add only gaps — new commands, new architecture notes, new rules/skills table entries, new critical rules. Do not rewrite.

**If new:** Generate from scratch using detected values for every field.

Write to: `<project>/CLAUDE.md` (project root, not inside `.claude/`)

### 3b. Generate rules

For each rule to generate, follow `references/rule-templates.md` → appropriate template. Fill all placeholders with values from actual source code — never use generic examples.

**Adaptive depth** (from quality-signals.md scoring):
- 4+ dimensions "Good" → full rules (80-120 lines) with real code examples from sampled files
- 2-3 "Good" → medium rules (50-70 lines)
- <2 "Good" → skeleton rules (30-50 lines) with TODO markers

Write to: `<project>/.claude/rules/<name>.md`

**If rule file exists:** Read it, add only what's missing. Append new sections. Never overwrite.

**Tech debt rule (`tech-debt.md`):** When Phase 1e/1f reveal anti-patterns that are deeply embedded in the current architecture (e.g., reflection in base classes that all services must extend), do NOT put them in conventions rules. Conventions rules should contain patterns developers can and should follow today. Instead, generate a separate `tech-debt.md` rule that:
- Names each embedded anti-pattern with file locations
- Explains why it's problematic (fragility, duplication, no compile-time safety)
- Distinguishes "don't extend this pattern to new code" from "refactor eventually"
- Gives actionable guidance: "when adding a new entity type, follow existing hierarchy but don't introduce additional [reflection/duplication/etc.] beyond what base classes require"

This separation prevents rules that say "don't do X" when the codebase requires X — developers ignore rules they can't follow.

### 3c. Generate full-scope skills

For each skill, follow `references/skill-generation.md` → full-scope skill structure.

**Every generated skill includes:**
- `SKILL.md` (100-250 lines): architecture diagram specific to this project, step-by-step workflow, real code examples extracted from actual codebase files
- `references/` dir: at minimum one template file matching detected conventions; add annotated example from real code
- `scripts/scaffold.sh` if the skill creates 3+ boilerplate files with predictable naming

**Adaptive depth:** Full for clean codebases, skeleton+ask for inconsistent patterns.

Write to: `<project>/.claude/skills/<name>/`

**If skill exists:** Add only missing components. If same domain, extend. If naming collision, warn user.

### 3d. Completion report

```
## Claudboard Complete

Generated:
- CLAUDE.md [created/updated — N lines]
- Rules: [list with adaptive depth used]
- Skills: [list, each with: SKILL.md ✓, references/ ✓/✗, scripts/ ✓/✗]

Next steps:
- Review generated artifacts and adjust to team preferences
- Run `/claudboard` again as the project evolves
- Flesh out any TODO sections in skeleton rules or skills
```

---

## Constraints

- **Read-only in Phases 1 and 2.** No writes to the target repo.
- **Write only to `.claude/` and project-root CLAUDE.md** in Phase 3.
- **Never modify source code, tests, or any existing file outside `.claude/`.**
- **Merge, don't replace** — when `.claude/` exists, fill gaps only.
- **Max ~50 source files read** for large repos — sampling strategy.
- **Secrets found during scan:** Report file:line only, never print the value.
- **If path doesn't exist:** State clearly and stop.

## Reference Files

| File | When to load |
|------|-------------|
| `references/stack-detectors.md` | Start of Phase 1 |
| `references/pattern-catalog.md` | Phase 2 — pattern/anti-pattern identification |
| `references/quality-signals.md` | Phase 2 — quality scoring, rule depth, skill triggers |
| `references/claude-md-template.md` | Phase 3 — CLAUDE.md generation |
| `references/rule-templates.md` | Phase 3 — rule file generation |
| `references/skill-generation.md` | Phase 3 — full-scope skill generation |
