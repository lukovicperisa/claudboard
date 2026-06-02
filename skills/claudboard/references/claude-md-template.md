# CLAUDE.md Generation Template

Use this template when generating or updating CLAUDE.md. Follow the craftsphere gold standard format. Target: 60-120 lines. Keep it lean — detailed conventions go in `.claude/rules/`, not here.

---

## Template

Replace `[...]` placeholders with detected values. Remove sections that don't apply. Add sections if the project has unique concerns not covered here.

```markdown
# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

[1-2 sentences: what does this project do, what's the tech stack, how does it deploy]

Example: "Acme is a B2B SaaS monorepo: backend microservices (Java 21/Spring Boot 3.4/Gradle), frontend (React 18/TypeScript), deploys via GitOps to Kubernetes on AWS EKS."
Example: "azure-devops-mcp is a Node.js MCP server that exposes Azure DevOps APIs as tools for Claude Code. TypeScript, built with tsc, tested with Jest."

## Commands

[Group commands by domain if multi-stack. Use exact detected commands from build configs and CI.]

### [Backend / API / Server] (from `[relative path]`)
- Build: `[command]`
- Test: `[command]`
- [Single test]: `[command pattern]`
- Lint: `[command]`
[Add: Start, Watch, Migration, Codegen if detected]

### [Frontend] (from `[relative path]`)
- Dev: `[command]` | Build: `[command]` | Test: `[command]`

### [Infrastructure / DevOps] (from `[relative path]`)
[Only include if IaC or deployment commands detected]

### Git (always from repo root)
- Branch: `[detected branch naming convention or standard feature/bugfix/hotfix pattern]`
- Commit: `[detected commit format or conventional commits]`
[Add PR/sync commands if detected]

## Key Architecture

[3-6 bullet points. Be specific — reference actual directory names and detected patterns. Do not be generic.]

- **[Structural pattern]:** [monorepo layout with dir names, or single-service structure]
- **[Backend/API pattern]:** [architecture pattern, key frameworks, reference service/dir]
- **[Frontend pattern]:** [if frontend exists, framework, state management, reference dir]
- **[Data pattern]:** [database, ORM, event streaming if applicable]
- **[DevOps/Deploy]:** [IaC tool, CI platform, deployment model, environment structure]

[For monorepos, add a service map table:]

| Service | Stack | Purpose |
|---------|-------|---------|
| `[service-name]` | [stack] | [1-phrase purpose] |

## Coding Rules & Skills

[Only include this section if rules and/or skills were generated]

### Auto-loaded Rules (`.claude/rules/`)

| Rule file | Auto-loads when touching |
|-----------|------------------------|
| `[rule-filename].md` | `[paths glob]` |

### Skills (`.claude/skills/`)

| Scope | Skill |
|-------|-------|
| [what it does] | `[skill-name]` |

## [Team Memory / Context]

[Only include if memories/ were generated or if there's important shared context to reference]
Shared context in `.claude/memories/` — [brief description of what's there].

[Include only if the project has .claudboard/:]
Build state from `/analyse` lives in `.claudboard/` (not loaded by Claude Code at runtime). Re-run `/analyse` to refresh; run `/analyse --audit` for per-service detail.

## Critical Rules (always apply)

[5-7 rules maximum. These are the most important conventions, the ones that would cause real problems if violated. Extract from detected patterns — do NOT list generic best practices.]

- [Rule 1] — [brief reason why it matters]
- [Rule 2]
...
```

---

## Section-by-Section Guidance

### Project Overview
- Pull from: README first paragraph, package `description` field, service names, domain vocabulary in code
- One sentence on purpose ("what it does"), one sentence on stack + deployment
- Do NOT: generic statements like "this is a web application"

### Commands
- Extract ONLY from: `package.json` scripts, `Makefile` targets, `build.gradle` tasks, CI pipeline steps, README
- Use exact commands — no approximations
- Group by where to run them (which directory)
- Omit commands that are irrelevant to daily dev work (e.g., CI-only scripts)

### Key Architecture
- Be specific: name the actual dirs, frameworks, patterns found
- Reference a "gold standard" service/component where applicable
- DevOps critical rules (never run X) go here if they're architectural constraints
- Keep each bullet to 1 line

### Coding Rules & Skills
- List only what was actually generated, not aspirational
- Rules table: exact filename, exact glob pattern
- Skills table: exact skill name, precise scope description

### Critical Rules
- These come from detected patterns, not from a generic list
- Each rule should be something Claude might violate without explicit guidance
- Format: actionable imperative + brief reason
- Max 7 — if you have more, put extras in rules/ files

---

---

## Monorepo Variant Template

Use this template instead of the standard one when the project is a monorepo (N+1 analysis reports detected). Target: 80-150 lines. Keeps repo-level concerns separate from per-service concerns.

```markdown
# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

[1-2 sentences: what does this monorepo do, how many services, overall tech stack, deployment model]

Example: "craftsphere is a B2B SaaS monorepo with 3 backend microservices (Java 21/Spring Boot 3.4/Gradle), 1 React/TypeScript frontend, and 1 shared Java library. Deploys via GitOps to Kubernetes using Pulumi + ArgoCD."

## Services

| Service | Stack | Directory | Purpose |
|---------|-------|-----------|---------|
| `[service-name]` | [stack] | `[dir/]` | [1-phrase purpose] |
| `[service-name]` | [stack] | `[dir/]` | [1-phrase purpose] |

## Shared Libraries

| Library | Directory | Consumed by |
|---------|-----------|-------------|
| `[library-name]` | `[dir/]` | [service-a, service-b] |

## Commands

[Group by service. Use exact detected commands from build configs and CI.]

### [service-a] (from `[dir/]`)
- Build: `[command]`
- Test: `[command]`
- [Single test]: `[command pattern]`

### [service-b] (from `[dir/]`)
- Build: `[command]`
- Test: `[command]`

### [frontend] (from `[dir/]`)
- Dev: `[command]` | Build: `[command]` | Test: `[command]`

### [shared-library] (from `[dir/]`)
- Build: `[command]` | Publish: `[command]`

### Infrastructure / DevOps
[Only include if IaC or deployment commands detected]

### Git (always from repo root)
- Branch: `[detected naming convention]`
- Commit: `[detected commit format]`

## Key Architecture

- **Repo structure:** Monorepo — [N services + M libraries], each independently buildable/deployable
- **Backend pattern:** [architecture pattern] — reference: `[reference-service/]` is the gold standard
- **Frontend:** [framework, state management] — `[dir/]`
- **Shared library:** `[lib-name]` — [what it provides, how consumed]
- **Data:** [databases per service, event bus if applicable]
- **DevOps:** [IaC tool, CI platform, deployment model]

## Coding Rules & Skills

### Auto-loaded Rules (`.claude/rules/`)

| Rule file | Auto-loads when touching |
|-----------|------------------------|
| `[service-name]-conventions.md` | `[service-dir]/**` |
| `[other-service]-conventions.md` | `[other-dir]/**` |
| `ci-cd.md` | `.github/workflows/**`, `azure-pipelines.yml` |

### Skills (`.claude/skills/`)

| Scope | Skill |
|-------|-------|
| [what it does] | `[skill-name]` |

## Critical Rules (always apply)

[5-7 rules covering cross-service concerns: deployment, commit format, shared library usage, infra constraints]

- [Rule 1] — [brief reason]
- [Rule 2]
...
```

---

## Merge Strategy (when CLAUDE.md already exists)

1. Read existing CLAUDE.md fully
2. Compare against detected project state:
   - Commands: update if commands have changed (new scripts, renamed tasks)
   - Architecture: add new services/modules not yet documented
   - Rules & Skills tables: add new generated rules/skills
   - Critical Rules: add detected patterns not yet listed (don't remove existing)
3. In Phase 2 report, list specific changes you intend to make
4. In Phase 3, apply only the additions/updates — do not rewrite from scratch

**Preserve user customization:** If existing CLAUDE.md has custom sections or wording that looks intentional, keep it. Only add/update, don't delete unless clearly obsolete.
