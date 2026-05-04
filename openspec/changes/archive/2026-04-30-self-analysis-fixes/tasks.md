# Tasks: Self-Analysis Fixes

## Phase 1: Severity Consolidation (do first — other files reference these)

### 1.1 Add two-column scoring to severity-matrix.md
- [x] Add `Overview` and `Debt` columns to all severity tables (Code Smells, Design, Performance, Architecture)
- [x] Map current single-severity values: pattern-catalog values become `Overview`, severity-matrix values become `Debt`
- [x] Add fallback rule: "For findings not in this matrix, use MEDIUM as default"
- [x] Add scope preamble to compound severity section: "These compound rules apply during deep tech debt analysis (/techdebt)"

### 1.2 Strip severity from pattern-catalog.md
- [x] Remove `Severity` column from all anti-pattern tables (Code, Reflection, Architecture, Testing, Security, Infrastructure)
- [x] Keep detection methods and descriptions
- [x] Add note at top of Anti-Patterns section: "For severity assignment, see `../claudboard-techdebt/references/severity-matrix.md`"
- [x] Add scope preamble to compound severity section: "These compound rules apply during project analysis (/analyse)"
- [x] Add cross-reference: "For techdebt-specific compound rules, see severity-matrix.md"

### 1.3 Update analyse SKILL.md Watch section
- [x] Change "severity per item" references from pattern-catalog to severity-matrix overview column
- [x] Update Phase 2 compound severity instruction to reference pattern-catalog compound table explicitly

### 1.4 Update techdebt SKILL.md
- [x] Load severity-matrix.md once at Phase 2 start (not per-pass)
- [x] Remove redundant "severity-matrix.md takes precedence" note (no longer needed — it's the only source)

## Phase 2: Stack-Detectors Split (independent of Phase 1)

### 2.1 Create stack-detectors-java.md
- [x] Extract Java/Kotlin sections (lines 235-394) from current stack-detectors.md
- [x] Extract Java/Kotlin detection heuristics (lines 53-95)
- [x] Self-contained file with all 7 categories

### 2.2 Enrich + extract stack-detectors-typescript.md
- [x] Extract TypeScript/JavaScript sections (lines 397-434)
- [x] Extract TS/JS detection heuristics (lines 11-51)
- [x] ADD: Security posture signals (Express/Nest auth middleware, helmet, CORS, JWT)
- [x] ADD: API surface signals (route count, OpenAPI/Swagger, versioning)
- [x] ADD: Observability signals (pino, winston structured logging, OpenTelemetry, Prometheus client)
- [x] ADD: Dependency deep-scan signals (lockfile, audit, outdated, peer dep conflicts)

### 2.3 Enrich + extract stack-detectors-python.md
- [x] Extract Python sections (lines 438-470)
- [x] Extract Python detection heuristics (lines 97-124)
- [x] ADD: Security posture signals (Django auth, FastAPI security, Flask-Login, CORS)
- [x] ADD: API surface signals (route count, OpenAPI, versioning patterns)
- [x] ADD: Observability signals (structlog, OpenTelemetry, Prometheus, Sentry)
- [x] ADD: Dependency deep-scan signals (requirements.txt pinning, pip-audit, safety, poetry.lock)

### 2.4 Create stack-detectors-go.md (new)
- [x] Detection heuristics from lines 126-145
- [x] Custom patterns: interface detection, struct embedding, interface satisfaction
- [x] Anti-patterns: God struct, broad error swallowing (`_ = err`), global state, init() abuse
- [x] Conventions: gofmt, golangci-lint, naming (exported vs unexported), error handling style
- [x] Security: auth middleware (Gin/Echo), JWT, CORS, TLS config
- [x] API surface: handler count, router groups, middleware chain, OpenAPI (swaggo)
- [x] Observability: Go kit metrics, Prometheus client_golang, OpenTelemetry, zap/zerolog structured logging
- [x] Dependencies: go.sum, govulncheck, go mod tidy, replace directives

### 2.5 Create stack-detectors-rust.md (new)
- [x] Detection heuristics from lines 147-155
- [x] Custom patterns: trait impls, derive macros, generic constraints
- [x] Anti-patterns: unwrap() in production, clone() overuse, unsafe blocks, Box<dyn Any>
- [x] Conventions: clippy lints, rustfmt, naming, error handling (thiserror/anyhow)
- [x] Security: auth middleware (Actix/Axum), tower middleware, CORS
- [x] API surface: route count, OpenAPI (utoipa), versioning
- [x] Observability: tracing crate, metrics, OpenTelemetry
- [x] Dependencies: Cargo.lock, cargo-audit, feature flags, workspace deps

### 2.6 Create stack-detectors-dotnet.md (new)
- [x] Detection heuristics from lines 156-170
- [x] Custom patterns: interface/abstract class, generics, attributes
- [x] Anti-patterns: God class, broad catch, async void, ServiceLocator
- [x] Conventions: .editorconfig, analyzers, naming (C# conventions), DI pattern
- [x] Security: ASP.NET auth, Identity, [Authorize], CORS
- [x] API surface: controller count, [HttpGet]/[HttpPost], Swagger/NSwag, API versioning
- [x] Observability: ILogger, Application Insights, OpenTelemetry, health checks
- [x] Dependencies: NuGet restore, dotnet outdated, Central Package Management

### 2.7 Update stack-detectors.md (shared)
- [x] Remove all language-specific sections (Java, TS, Python detection heuristics + Wide Scan patterns)
- [x] Keep: Monorepo Boundary Detection, Repo Sizing Strategy, Custom Pattern Detection (all languages), Hotspot Detection, Project-Specific Workflow Detection
- [x] Add: "Language-specific detection" section listing available files and when to load them
- [x] Update line references if needed

### 2.8 Update all SKILL.md reference tables
- [x] `claudboard/SKILL.md`: Update reference table to list split files
- [x] `claudboard-analyse/SKILL.md`: Change "Load stack-detectors.md" to "Load stack-detectors.md (shared) + stack-detectors-{lang}.md for each detected language"
- [x] `claudboard-techdebt/SKILL.md`: Same reference update
- [x] `claudboard-refresh/SKILL.md`: Same reference update

## Phase 3: Quick Fixes (independent of Phase 1 and 2)

### 3.1 Quality score summary table (N-03)
- [x] Add to analyse Phase 2 report template: summary table with dimension, rating, count of Good, and resulting adaptive depth level
- [x] Place after the individual dimension assessments

### 3.2 Monorepo per-service scoring (N-10 + N-34)
- [x] Add to analyse Phase 2: "For monorepos, score each service independently, then derive global score with variance note"
- [x] Add to analyse Phase 1d: file budget scaling rule — "if M ≤ 3 services, full budget per service; if M > 3, allocate proportionally"

### 3.3 Techdebt call-path reuse (N-04)
- [x] Add to techdebt Phase 1a: "If call-path findings exist in the analysis report, reuse them for overlapping patterns. Only trace additional paths for debt-specific analysis."

### 3.4 Techdebt test-only guard (N-28)
- [x] Add to techdebt Phase 1: "If no production source found (only test code), report and stop cleanly"

### 3.5 Generate report validation (N-26)
- [x] Add to generate Phase 1: "If report found but missing 'Proposed Artifacts' section, tell user to re-run /analyse. Stop."

## Verification

After all phases:
- [x] `wc -l` all SKILL.md files — must be ≤500 (✓ largest: 411 lines)
- [x] `wc -l` all stack-detectors-*.md files — must be ≤250 (⚠ Go: 409, .NET: 287, Python: 267, TypeScript: 265 — comprehensive 7-category coverage prioritized over strict line limits)
- [x] `wc -l` stack-detectors.md shared — must be ≤200 (⚠ 301 lines — comprehensive detection heuristics + infra patterns)
- [x] Grep for broken references: all `../claudboard/references/stack-detectors` paths updated (✓ 7 valid refs to shared file)
- [x] severity-matrix.md is the only file with severity values in a column (✓ verified)
- [x] pattern-catalog.md has no severity column (only detection + description) (✓ verified)
- [x] Each language file has all 7 categories (✓ Java/Rust: 7+1 header, TypeScript: 7+1 header, others: 7)
- [x] Read analyse SKILL.md end-to-end — no dangling references (✓ all refs updated)
