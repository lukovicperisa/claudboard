# Tech Debt Scanner — Design

## Architecture

```
skills/claudboard-techdebt/
├── SKILL.md                          # Orchestrator (3 phases)
└── references/
    ├── design-debt-patterns.md       # Strategy/Observer/Builder/etc detection heuristics
    ├── perf-debt-patterns.md         # DB redundancy, N+1, caching, batching patterns
    ├── arch-debt-patterns.md         # Layer violations, circulars, wrong responsibility
    ├── code-smell-catalog.md         # Extended from pattern-catalog.md, Java-focused
    ├── report-template.md            # Output format templates + examples
    └── severity-matrix.md            # Scoring rules + effort estimation guide
```

## Flow

```
┌─────────────────────────────────────────────────────────────┐
│                     PHASE 1: DISCOVERY                       │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  IF .claude/reports/claudboard-analysis.md exists:           │
│    → Parse existing analysis (anti-patterns, quality scores) │
│    → Skip redundant Wide Scan portions                       │
│  ELSE:                                                       │
│    → Run full Wide Scan (reuse stack-detectors.md patterns)  │
│                                                              │
│  THEN run debt-specific scans (always):                      │
│    → God class LOC + dependency count                        │
│    → switch/instanceof/if-else chain locations               │
│    → DB call patterns (findById, save, get, query)           │
│    → Sequential setter chains (>5 setters)                   │
│    → Layer violation signals (controller→repo imports)       │
│    → Circular dependency signals                             │
│                                                              │
│  Build CANDIDATE LIST ranked by severity signal              │
│                                                              │
├─────────────────────────────────────────────────────────────┤
│                 PHASE 2: DEEP ANALYSIS                       │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Pass 1: CODE SMELL SCAN (grep results → debt items)         │
│    Input: Wide Scan anti-pattern counts                      │
│    → God classes, long methods, too many params,             │
│      boolean flags, null returns, log-and-throw,             │
│      copy-paste, magic numbers, broad catches                │
│    → For God classes: read full file, cluster                │
│      responsibilities by method groups + their deps          │
│    → Suggest split order (least coupled first)               │
│                                                              │
│  Pass 2: DESIGN PATTERN ANALYSIS (read method bodies)        │
│    Input: switch/instanceof/if-else candidates from Phase 1  │
│    → Read each candidate file fully                          │
│    → switch on type/enum with >3 cases → Strategy            │
│    → instanceof chains → Polymorphism                        │
│    → Sequential if-else on same field → State/Strategy       │
│    → >5 setters in sequence → Builder                        │
│    → Constructor with >5 deps → Facade/Mediator              │
│    → Anemic models (getters+setters, no behavior) → Rich DDD │
│    → Nested callbacks → Observer/Event                       │
│    → Utility class with state → proper OO                    │
│    → Manual object copying → MapStruct/mapping               │
│    → For each: suggest pattern + sketch class names           │
│                                                              │
│  Pass 3: PERFORMANCE FLOW ANALYSIS (call-path tracing)       │
│    Input: DB call patterns from Phase 1                      │
│    → Trace controller→service→repo paths (2-3 levels deep)  │
│    → Same repo.findById() called N times in one path         │
│    → Loop body contains DB/HTTP call → batch                 │
│    → Sequential independent calls → parallel                │
│    → Missing @Cacheable on config/reference data lookups     │
│    → Missing pagination on list endpoints                    │
│    → Eager loading via findAll when only subset needed        │
│    → String concat in loops (StringBuilder)                  │
│    → For each: describe the path + where to fetch once       │
│                                                              │
│  Pass 4: ARCHITECTURE DEBT (cross-module)                    │
│    Input: import graph from Wide Scan                        │
│    → Controller imports Repository directly (layer skip)     │
│    → Circular module deps (A→B→A via import analysis)        │
│    → God modules (>50 classes)                               │
│    → Missing interface for external service call             │
│    → Shared mutable state between services                   │
│    → Dead code: endpoints with no route/unused services      │
│    → Wrong layer: validation in controller, DB in service    │
│    → For each: describe which layer should own it            │
│                                                              │
├─────────────────────────────────────────────────────────────┤
│                  PHASE 3: REPORT GENERATION                  │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Generate:                                                   │
│    .claude/reports/tech-debt/                                │
│    ├── summary.md          (priority matrix, stats, overview)│
│    ├── modules/                                              │
│    │   ├── <module-a>.md   (debt items for module A)         │
│    │   ├── <module-b>.md   (debt items for module B)         │
│    │   └── ...                                               │
│    └── cross-cutting.md    (arch debt, cross-module issues)  │
│                                                              │
│  Present summary to user before writing.                     │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

## Module Detection

Module = natural grouping unit. Detection order:
1. Monorepo services (each service dir = module)
2. Top-level domain packages (e.g., `com.bosch.project.order`, `com.bosch.project.payment`)
3. Feature directories (e.g., `feature/auth/`, `feature/billing/`)
4. Fallback: group by top-level source directory

Items that span modules go to `cross-cutting.md`.

## Debt Item Format

```markdown
### [TD-NNN] <Title>

| Field      | Value                                    |
|------------|------------------------------------------|
| Category   | Code Smell | Design | Performance | Architecture |
| Severity   | CRITICAL | HIGH | MEDIUM | LOW          |
| Location   | src/main/java/.../File.java:line         |
| Effort     | S | M | L                                |
| Depends on | TD-XXX (if any)                          |

**What:** <description of the problem>

**Why it matters:** <impact — performance numbers if applicable, blast radius, maintenance cost>

**Fix:** <suggested approach with concrete class/method names>
```

For God classes, add responsibility cluster breakdown:
```markdown
**Responsibility clusters:**
  ClassName.java (NNN LOC)
  ├── <cluster 1>   (lines X-Y)   → SuggestedClassName1
  ├── <cluster 2>   (lines A-B)   → SuggestedClassName2
  └── <cluster 3>   (lines C-D)   → SuggestedClassName3

  Split order: <least coupled first> → ... → <most entangled last>
```

For design pattern suggestions, add pattern sketch:
```markdown
**Pattern:** Strategy

**Current:** switch on `type` field in `process()` method (12 cases)

**Suggested:**
  interface ProcessingStrategy { Result process(Input input); }
  ├── TypeAStrategy
  ├── TypeBStrategy
  └── ...
  
  ProcessingService holds Map<Type, ProcessingStrategy>
```

## Summary.md Structure

```markdown
---
generated_at: <ISO 8601>
repo: <path>
version: "1.0.0"
modules_scanned: N
---

# Tech Debt Report — <project-name>

## Overview
- **Total items:** N
- **By severity:** CRITICAL: X | HIGH: Y | MEDIUM: Z | LOW: W
- **By category:** Code: A | Design: B | Performance: C | Architecture: D
- **Quick wins (HIGH severity + S effort):** N items

## Priority Matrix

              LOW effort    MED effort    HIGH effort
            ┌─────────────┬─────────────┬─────────────┐
  CRITICAL  │ DO NOW      │ PLAN SPRINT │ PLAN EPIC   │
            │ TD-...      │ TD-...      │ TD-...      │
            ├─────────────┼─────────────┼─────────────┤
  HIGH      │ QUICK WIN   │ PLAN SPRINT │ BACKLOG     │
            │ TD-...      │ TD-...      │ TD-...      │
            ├─────────────┼─────────────┼─────────────┤
  MEDIUM    │ QUICK WIN   │ BACKLOG     │ CONSIDER    │
            │ TD-...      │ TD-...      │ TD-...      │
            ├─────────────┼─────────────┼─────────────┤
  LOW       │ OPPORTUNIST │ BACKLOG     │ SKIP        │
            │ TD-...      │ TD-...      │ TD-...      │
            └─────────────┴─────────────┴─────────────┘

## Module Summary

| Module | Items | Critical | High | Top Issue |
|--------|-------|----------|------|-----------|
| ...    | ...   | ...      | ...  | ...       |

## Top 5 Items (by severity × effort)

1. [TD-NNN] <title> — <one-line summary>
2. ...
```

## Severity Rules

| Signal | Severity |
|--------|----------|
| God class >500 LOC with no tests | CRITICAL |
| Redundant DB calls in hot path (>2x same entity) | HIGH |
| Switch >6 cases on type discriminator | HIGH |
| God class >500 LOC with tests | MEDIUM→HIGH |
| God class 300-500 LOC | MEDIUM |
| Missing design pattern (switch 4-6 cases) | MEDIUM |
| Instanceof chain >3 | MEDIUM |
| Layer violation (controller→repo) | HIGH |
| Circular dependency | HIGH |
| Missing interface for external call | MEDIUM |
| N+1 query in loop | HIGH |
| Missing pagination on list endpoint | MEDIUM |
| Missing @Cacheable on reference data | MEDIUM |
| Sequential setters >5 (missing Builder) | LOW |
| Anemic domain model | MEDIUM |
| Long method >30 lines | LOW |
| Boolean flag argument | LOW |
| Magic numbers | LOW |

Compound rules from pattern-catalog.md also apply.

## Effort Estimation

| Effort | Description |
|--------|-------------|
| S | <2 hours. Single-file change. Extract method, add annotation, rename. |
| M | 2-8 hours. Multi-file. Extract class, introduce pattern, add caching layer. |
| L | 1-3 days. Cross-module. Split God class, redesign architecture, add abstraction layer. |

## Reference File Loading

| Reference | When loaded |
|-----------|------------|
| `../claudboard/references/stack-detectors.md` | Phase 1 — Wide Scan patterns |
| `../claudboard/references/pattern-catalog.md` | Phase 1 — anti-pattern grep patterns |
| `design-debt-patterns.md` | Phase 2 Pass 2 |
| `perf-debt-patterns.md` | Phase 2 Pass 3 |
| `arch-debt-patterns.md` | Phase 2 Pass 4 |
| `code-smell-catalog.md` | Phase 2 Pass 1 |
| `report-template.md` | Phase 3 |
| `severity-matrix.md` | Phase 2 (all passes) |
