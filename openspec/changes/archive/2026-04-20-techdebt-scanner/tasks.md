# Tasks — Tech Debt Scanner

## Reference Files

- [x] **Task 1: Create `severity-matrix.md`** — Severity rules table, compound severity, effort estimation guide (S/M/L definitions). Pull severity rules from design.md, add compound rules from pattern-catalog.md.

- [x] **Task 2: Create `code-smell-catalog.md`** — Extended Java-focused code smell detection heuristics. Reuse + extend patterns from `../claudboard/references/pattern-catalog.md`. Add: God class responsibility clustering algorithm (group methods by shared field/dependency usage), long method detection, copy-paste detection strategy (pick distinctive 3-line patterns, grep for repeats). Include grep patterns for each smell.

- [x] **Task 3: Create `design-debt-patterns.md`** — Design pattern detection heuristics for Java/Spring. For each pattern: what to grep for (candidates), what to look for when reading the file (confirmation), what to suggest (pattern sketch template). Patterns: Strategy (switch/if-else on type), State (if-else on same field), Builder (>5 sequential setters), Facade (>5 constructor deps), Observer (nested callbacks), Polymorphism (instanceof chains), Rich Domain (anemic model detection), Factory (manual construction with >3 params). Include concrete Java examples.

- [x] **Task 4: Create `perf-debt-patterns.md`** — Performance debt detection heuristics for Java/Spring. Include: redundant DB calls (same findById in one request path — how to trace), N+1 queries (DB call inside loop body), missing @Cacheable (reference/config data queried repeatedly), missing pagination (List return on endpoints), sequential-when-parallel (independent service calls in sequence), eager loading (findAll when filtered subset needed), String concat in loops. For each: grep pattern to find candidates, how to confirm via call-path tracing, fix suggestion template.

- [x] **Task 5: Create `arch-debt-patterns.md`** — Architecture debt detection for Java/Spring. Include: layer violations (controller importing repository — grep for import patterns), circular dependencies (A imports B, B imports A — detection via import graph), God modules (>50 classes in one package), missing abstractions (direct HTTP/DB client usage without interface), dead endpoints (controller methods with no inbound route), wrong-layer responsibility (validation in controller, DB logic in service, business logic in controller). Include detection approach for each.

- [x] **Task 6: Create `report-template.md`** — Output format templates. Include: summary.md template with YAML frontmatter + priority matrix + module table + top 5. Module report template with debt item format. Cross-cutting report template. God class cluster format. Design pattern suggestion format. Performance path format. All with concrete examples.

## Skill File

- [x] **Task 7: Create `SKILL.md`** — Main orchestrator for `skills/claudboard-techdebt/`. Three phases: Discovery (reuse Wide Scan or parse existing analysis), Deep Analysis (4 passes), Report Generation. Reference file loading table. Invocation as `/techdebt [path]`. Load reference files on-demand per phase/pass. Present summary before writing. Constraints section (read-only source, writes only to `.claude/reports/tech-debt/`). Follow structure of `claudboard-analyse/SKILL.md` as template for phase organization. Description field triggers: "tech debt", "technical debt", "refactoring", "code quality report", "debt analysis", "what needs refactoring".
