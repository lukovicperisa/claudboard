# Tech Debt Scanner — Spec

## Capability

A claudboard skill that performs a thorough, one-shot tech debt analysis of a Java/Spring codebase and produces a module-grouped, ticket-ready report.

## Requirements

### Functional

1. **Hybrid discovery**: If `.claude/reports/claudboard-analysis.md` exists, parse and reuse anti-pattern findings. Otherwise, run full Wide Scan using existing `stack-detectors.md` patterns.

2. **Four analysis passes**:
   - **Code smells**: God classes (with responsibility clustering + split suggestion), long methods, too many params, boolean flags, null returns, log-and-throw, copy-paste, magic numbers, broad catches
   - **Design patterns**: switch/instanceof → Strategy, sequential setters → Builder, >5 constructor deps → Facade, anemic models → rich DDD, nested callbacks → Observer, utility-with-state → OO
   - **Performance flows**: redundant DB calls in same request path, N+1 in loops, missing @Cacheable, missing pagination, sequential-when-parallel-possible, eager-when-lazy-needed
   - **Architecture debt**: layer violations, circular deps, God modules, missing interfaces for externals, dead code, wrong-layer responsibility

3. **God class deep analysis**: Read full file, cluster methods by responsibility (shared dependencies = same cluster), suggest target class names, suggest split order (least coupled first).

4. **Design pattern suggestions**: For each candidate, sketch the pattern — interface name, concrete class names, where the dispatch lives.

5. **Performance path tracing**: Trace controller→service→repo (2-3 levels), detect same `findById()`/`get()` called multiple times, detect DB calls inside loops.

6. **Debt item format**: Each item has ID (TD-NNN), category, severity, location (file:line), effort (S/M/L), dependencies (other TD items), description, impact, fix suggestion.

7. **Module grouping**: Items grouped by detected module (service dir, domain package, or feature dir). Cross-module items in separate file.

8. **Priority matrix**: summary.md with severity × effort matrix, module summary table, top 5 items.

9. **Output**: `.claude/reports/tech-debt/summary.md`, `modules/<name>.md`, `cross-cutting.md`

10. **Present before writing**: Show summary to user, write files after confirmation.

### Non-functional

- Mid-exhaustive: grep to find candidates, deep-read all strong candidates (no hard limit on file reads for a run-once tool)
- Java/Spring primary, structured for future language extension
- Reuses existing claudboard reference files where applicable (stack-detectors.md, pattern-catalog.md)
- Read-only for source code — only writes to `.claude/reports/tech-debt/`

## Acceptance Criteria

- [ ] Running `/techdebt` on a Spring Boot monorepo produces reports in `.claude/reports/tech-debt/`
- [ ] God classes include responsibility clusters with suggested split
- [ ] Design pattern candidates include pattern sketch (interface + concrete classes)
- [ ] Performance debt items include the call path showing redundancy
- [ ] Summary includes priority matrix with all items placed
- [ ] Can consume existing claudboard analysis report to avoid redundant scanning
- [ ] Each debt item has all required fields (ID, category, severity, location, effort, fix)
