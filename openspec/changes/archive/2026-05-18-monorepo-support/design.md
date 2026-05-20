## Context

Claudboard's analyse, generate, techdebt, and refresh skills assume a single-project repository. All scanning, scoring, and artifact generation treats the repo as one unit. This works for single-service repos but produces misleading results for monorepos where services have different stacks, conventions, test strategies, and quality levels.

The current flow: analyse (one scan → one report) → generate (one report → one CLAUDE.md + rules) → techdebt (one scan → one debt report). Each step is single-pass, single-output.

Key files affected:
- `skills/claudboard-analyse/SKILL.md` — main analysis workflow
- `skills/claudboard-generate/SKILL.md` — artifact generation from report
- `skills/claudboard-techdebt/SKILL.md` — tech debt scanning
- `skills/claudboard-refresh/SKILL.md` — delta updates
- `skills/claudboard/references/stack-detectors.md` — detection heuristics
- `skills/claudboard/references/claude-md-template.md` — CLAUDE.md template

## Goals / Non-Goals

**Goals:**
- Auto-detect monorepo structure without user configuration
- Produce per-service analysis with service-scoped reports, quality scores, and artifact proposals
- Produce global analysis for repo-level concerns (CI/CD, GitOps, cross-service communication)
- Generate CLAUDE.md with monorepo topology, per-service build/test commands
- Generate rules with `paths:` frontmatter scoped to service directories
- Namespace techdebt IDs per service with cross-report dependency support
- Handle service additions/removals in refresh

**Non-Goals:**
- Multi-repo federation (analysing interconnected repos across separate git clones) — future work
- User-declared service boundaries — always auto-detect
- "Light mode" or partial analysis — always full depth per service
- Techdebt cross-service architectural debt analysis (e.g., missing contract tests) — can be added later without structural changes

## Decisions

### 1. Monorepo detection: independent build roots + classification

**Decision:** Detect monorepos by finding multiple independent build root directories. Classify each as service or library.

**Service signals** (any of):
- Has Dockerfile
- Has main entry point (`@SpringBootApplication`, `public static void main`, `package main`, `"start"` script, `__main__.py`)
- Has runtime config (`application.yml`, `.env`)

**Library signals** (all of):
- Has publish tasks (`maven-publish`, `"publishConfig"`, `[build-system]`)
- No main entry point
- No Dockerfile

**Alternative considered:** User-declared service list via config file. Rejected — adds friction to a one-time process and violates the "auto-detect everything" philosophy.

**Edge case:** Gradle/Maven multi-module with shared build root. Treat as single project unless per-module Dockerfiles exist. If ambiguous (Dockerfiles but shared build root), present findings and ask user to confirm: "This looks like a multi-module project with per-module deployments. Treat as monorepo with N services?"

### 2. Phase restructuring in analyse

**Decision:** Split Phase 1 into global-once and per-service passes.

```
Phase 1a: Structure detection (NEW)
  → Find build roots, classify service/library
  → Present: "Found N services + M libraries: [list]"

Phase 1b: Global scan (MODIFIED — runs once)
  → CI/CD pipeline structure
  → GitOps / IaC
  → Cross-service communication (event topics, API contracts)
  → Shared library inventory
  → Branch strategy, commit conventions

Phase 1c: Wide Scan (MODIFIED — scoped per service)
  → Same grep patterns, but rooted at service directory
  → Results attributed to specific service

Phase 1d-f: Per service (MODIFIED — full depth each)
  → File budget applied per service independently
  → File selection, reading, call-path tracing per service
  → Each service gets its own convention profile
```

**Alternative considered:** Run Phase 1 once globally, then split at Phase 2. Rejected — Phase 1c-f results are meaningless when mixed across services with different stacks.

### 3. N+1 report structure

**Decision:** Always produce one global report + one report per service.

```
.claude/reports/
├── claudboard-analysis.md                    (global)
├── claudboard-analysis-order-service.md      (per-service)
├── claudboard-analysis-user-service.md       (per-service)
└── claudboard-analysis-frontend.md           (per-service)
```

Global report contains:
- Repo topology (services + libraries with paths)
- CI/CD, GitOps, cross-service communication
- Branch/commit conventions
- Per-service summary table with links to service reports
- Overall quality variance note

Per-service report contains:
- Stack & versions
- DI style, logging, error handling conventions
- Test framework & coverage
- Architecture pattern
- Quality score (6 dimensions)
- Watch/Preserve findings
- Proposed scoped artifacts

**Report naming:** `claudboard-analysis-{directory-name}.md` — use directory name as-is, don't try to be clever.

### 4. Techdebt ID namespacing

**Decision:** Prefix TD-IDs with a short service code derived from the directory name.

Derivation rules:
- Use directory name initials if unique (e.g., `order-service` → `OS`, `frontend` → `FE`)
- If initials collide, use first 3 chars (e.g., `order-api` → `ORA`, `order-worker` → `ORW`)
- Global findings use `GL` prefix

Cross-report dependencies expressed as: `Depends on: GL-01` in a per-service report.

**Alternative considered:** Global sequential IDs partitioned by service. Rejected — adding findings to one service shifts IDs in others, and you can't tell which service a finding belongs to from the ID alone.

### 5. Generate multi-report consumption

**Decision:** Generate detects monorepo by checking for `claudboard-analysis-*.md` files alongside the global report. If found, reads all and produces:

- **CLAUDE.md**: Monorepo variant with services table, per-service build/test commands, shared library notes
- **Global rules**: `rules/ci-cd.md`, `rules/gitops.md` etc. (no `paths:` — applies everywhere)
- **Per-service rules**: `rules/{service-name}-conventions.md` with `paths: ["{service-dir}/**"]`
- **Per-service skills**: if warranted, scoped to service directory

### 6. Refresh service delta detection

**Decision:** Refresh compares current build roots against service reports from last analysis.

- New build root with no matching report → flag as "new service detected, re-run /analyse"
- Report exists but directory removed → flag as "service removed, stale report"
- Existing service with changes → normal delta refresh scoped to that service

## Risks / Trade-offs

- **[Context window pressure]** Full Phase 1 per service on a 10-service monorepo is expensive. → Mitigation: This is a one-time process; quality over cost. Document that very large monorepos (>10 services) may require multiple sessions.
- **[Service boundary misdetection]** Shared libraries, example projects, or tooling directories could be misclassified as services. → Mitigation: Present detected topology to user before proceeding. They can correct.
- **[Cross-service debt blind spots]** Per-service techdebt won't catch inter-service issues (missing contract tests, inconsistent API versions). → Mitigation: Explicitly out of scope. Global techdebt report covers CI/infra debt. Cross-service analysis is future work.
- **[Report sprawl]** A 5-service monorepo produces 6 analysis + 6 techdebt reports. → Mitigation: Clear naming convention, summary table in global report with links.
