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
- **Inheritance & abstraction map**: custom `@interface` declarations, abstract base classes, who extends what
- **Skill trigger signals**: full trigger catalog from `../claudboard/references/quality-signals.md` → "Skill Generation Triggers"
- **Anti-pattern signals**: God class candidates (file size), field injection count, reflection in business logic, broad catches, null returns, legacy date usage, console logging, star imports, TODO/FIXME count
- **Convention frequency**: DI ratio (field vs constructor), logging style, test naming pattern

Tally results into a Pattern Inventory: base classes with subclass counts, custom annotations with usage counts, skill triggers with file counts and best examples, anti-pattern counts with file lists.

### 1d. Strategic sampling

**For repos <50 source files:** Read all source files.

**For repos ≥50 source files:** Use Pattern Inventory from step 1c to select files purposefully (see `../claudboard/references/stack-detectors.md` → "Size Thresholds"):

Priority order until file budget exhausted:
1. All abstract base classes with 3+ subclasses
2. All custom `@interface` declarations
3. Top 3 God class candidates (largest LOC)
4. Best example per detected skill trigger (smallest/cleanest file)
5. Top 3 git hotspots (most recently changed)
6. 1 representative test file per framework

Record reason for each file selected. From each file, detect naming conventions, DI pattern, error handling, logging, architecture layering, TODO comments.

### 1e. Test strategy detection

Check for test framework, test directories, coverage tooling, and whether tests appear in CI pipeline. See `../claudboard/references/quality-signals.md` → "Testing" checklist.

### 1f. Existing `.claude/` inventory

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
**Testing coverage:** [Comprehensive / Basic / Missing]
**Convention consistency:** [Enforced / Mostly consistent / Inconsistent]

**Preserve:**
- <good pattern> — <where found>

**Watch:**
- [WARN] <anti-pattern> — <file/location>

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
- `<skill-name>/` — <what triggers it, what it creates, full scope: SKILL.md + references/ + scripts/>

[If existing .claude/ found:]
**Already covered (no action):**
- `<existing rule>` — no gaps detected
- `<existing skill>` — already defined
```

Present this report to the user.

---

## Phase 3: Save Report

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

**This skill ends here.** To generate artifacts from this report, run `/generate`.

---

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
| `../claudboard/references/quality-signals.md` | Phase 2 — quality scoring, rule depth decisions |
