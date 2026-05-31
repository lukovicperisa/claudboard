# Analysis Report Templates

Load this file during Phase 2 of `/analyse`. It defines the exact format for single-project, monorepo, and per-service analysis reports.

---

## Single-Project Report Template

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

### Why (reasoning behind decisions)
- <detected constraint → inferred decision>
  e.g., "Azure Pipelines → team is on Azure; Pulumi TypeScript → IaC in same language as app code"

### Quality Assessment

Score each dimension 1-10 (whole numbers only) using criteria from quality-signals.md.

**Testing:** [N]/10 — Evidence: [framework, CI gate, coverage %]
**Architecture:** [N]/10 — Evidence: [pattern name, consistency]
**Conventions:** [N]/10 — Evidence: [linting enforcement, DI pattern, god classes, anti-patterns]
**Dependencies:** [N]/10 — Evidence: [versions, BOM status, SBOM, cross-module mismatches]
**CI/CD:** [N]/10 — Evidence: [pipeline stages, quality gates, deploy automation]
**Documentation:** [N]/10 — Evidence: [README, CLAUDE.md, ADRs, inline docs]
**Security:** [N]/10 — Evidence: [framework, method-level auth coverage, CORS, secrets]
**Observability:** [N]/10 — Evidence: [actuator, metrics, tracing, structured logging]

**API Surface:**
- Controllers: N | Endpoints: ~M (GET:X POST:Y PUT:Z DELETE:W)
- Versioning: [URL-based v1/v2 / None detected]
- Documentation: [springdoc-openapi / springfox / None]

**Reflection usage:** [None / Config-only / Business-logic (flag)] — from Phase 1c grep
**Code duplication:** [None detected / Minor / Structural (parallel hierarchies)] — from `duplication.candidates` in discovery JSON; "None detected" when `repo.source_file_count < 30` (1g skipped)

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

**Preserve:**
- <good pattern> — <where found>

**Watch:**
- [SEVERITY] <anti-pattern> — <file/location>

Include findings from Phase 1f (call-path tracing) and Phase 1g (duplication detection).
For severity assignment, use the **Overview** column from `../claudboard-techdebt/references/severity-matrix.md`.
For reflection or deeply-embedded anti-patterns: note whether they belong in conventions rules (actionable today) or tech-debt rules (document but can't avoid in current architecture). See pattern-catalog.md →
"Reflection Anti-Patterns" → "Reporting guidance".

After listing all Watch findings, **apply compound severity rules** from `pattern-catalog.md` → "Compound Severity Rules" (analyse-scoped rules):
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

### Workflow Signals

```yaml
workflow_signals:
  cross_service_edges:
    - {family: sync-rpc, protocol: feign, type: feign, direction: outbound, target: "<service-name>", schema_ref: null}
    - {family: sync-rpc, protocol: http,  type: http,  direction: outbound, target: "<url-or-unknown>", schema_ref: null}
    - {family: messaging, protocol: kafka, type: kafka, direction: outbound, target: "<topic-name>", schema_ref: null}
    - {family: sync-rpc, protocol: grpc,  type: grpc,  direction: inbound,  target: "<service-name-or-unknown>", schema_ref: "path/to/file.proto"}
  shared_libraries:
    - {name: "<artifactId-or-package>", consumer_count: <N>}
  auth_perimeter: "gateway|in-service-jwt|none|unknown"
  ticket_prefix: "PROJ|null"
```

[Emit this block even if all signals are empty/unknown — the subsection must always be present]

### Architectural Patterns

```yaml
architectural_patterns:
  - {type: saga, style: orchestration, evidence: ["path/to/orchestrator.java:42"]}
  - {type: circuit-breaker, library: resilience4j, evidence: ["path/with/@CircuitBreaker:88"]}
  - {type: schema-registry, vendor: confluent, evidence: ["application.yml:schema.registry.url"]}
```

[Emit `architectural_patterns: []` when no patterns are detected. Omit any entry whose minimum-signal threshold is not met (empty evidence → no entry). BFF detection is workspace-only.]

### Proposed Artifacts

**CLAUDE.md** — [outline: commands table, architecture bullets, rules/skills index, critical rules count]
[If existing: "Will add [X] to existing CLAUDE.md — preserving current content"]

**Rules (N files):**
- `<filename>.md` (paths: `<glob>`) — <what it covers, adaptive depth: full/medium/skeleton>

**Skills (M to generate):**

Before listing skills, **run skill dedup check** (see quality-signals.md → "Skill Deduplication"):
- Compare each pair of proposed skills for file glob overlap >50% or shared trigger annotations
- If overlap found, present it explicitly and wait for user decision

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
See quality-signals.md → "Token Estimation Guide" for heuristics.)
```

---

## Monorepo Report Structure

Produce **two levels** of report content.

### Global report (whole repo — CI/CD, shared libs, cross-service patterns)

```
## Project Analysis: <repo-name> (Monorepo)

### What (purpose & value)
<repo-level purpose>

### Monorepo Topology
| Service | Stack | Directory | Purpose |
|---------|-------|-----------|---------|
| <name> | <stack> | `<dir>/` | <1-phrase> |

| Library | Directory | Consumed by |
|---------|-----------|-------------|
| <name> | `<dir>/` | [services] |

### How (global — applies to all services)
- CI/CD: <platform> — <stages/jobs>
- Deploy: <model> — <IaC tool>
- Branch strategy: <detected pattern>
- Commit conventions: <detected format>
- Cross-service communication: <event bus / REST contracts if detected>

### Per-Service Summary
| Service | Testing | Architecture | Conventions | Avg Score |
|---------|---------|--------------|-------------|-----------|
| <name> | [N]/10 | [N]/10 | [N]/10 | [X.X]/10 |

**Quality variance:** [e.g., "Testing: 2/3 services scored 7+, 1/3 scored 4-6 — variance noted"]

### Global Watch
- [SEVERITY] <cross-service anti-pattern> — <evidence>

### Proposed Global Artifacts
**CLAUDE.md** — monorepo variant
**Rules (global, no paths:):**
- `ci-cd.md` — CI/CD and deployment conventions
- `gitops.md` — IaC and GitOps constraints [if detected]
```

### Per-service report (one per detected service)

```
## Service Analysis: <service-name>

### Stack & Versions
<stack, key dependencies, detected versions>

### Quality Assessment
[Same 1-10 scoring as single-project, scoped to this service]

**Average:** [X.X]/10
**Adaptive Depth Decision:** [≥7.0] → Full | [4.0-6.9] → Medium | [<4.0] → Skeleton

### Preserve / Watch
[Same format as single-project, scoped to this service]

### Workflow Signals
[Same yaml block format as single-project — always emit, even if empty]

### Architectural Patterns
[Same yaml block format as single-project]

### Proposed Artifacts (scoped to this service)
**Rules:**
- `<service-name>-conventions.md` (paths: `<service-dir>/**`) — <conventions>
**Skills:**
- `<skill-name>/` — scoped to <service-dir>/
```
