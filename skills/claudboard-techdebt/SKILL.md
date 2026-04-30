---
name: claudboard-techdebt
description: >
  Deep tech debt analysis of a codebase. Produces a module-grouped, ticket-ready
  report with severity, effort estimates, and fix suggestions for every item.
  Detects code smells, missing design patterns, performance debt, and architecture
  flaws. Use when: /techdebt, "tech debt", "technical debt analysis", "what needs
  refactoring", "code quality report", "debt scan", "refactoring candidates",
  "find tech debt", "architecture debt", "performance issues in code",
  "generate refactoring tickets".
---

# Tech Debt Scanner

Performs a thorough, one-shot tech debt analysis. Produces `.claude/reports/tech-debt/` with module-grouped debt items ready for conversion into refactoring tickets.

**Java/Spring primary.** Extensible to other stacks in future.

## Invocation

```
/techdebt [path]
```

Path defaults to current working directory.

---

## Phase 1: Discovery

### 1a. Check for Existing Analysis

Check if `.claude/reports/claudboard-analysis.md` exists.

**If exists:** Read it. Extract:
- Anti-pattern findings (Watch section)
- Quality scores
- Architecture pattern
- God class candidates
- Tech debt indicators

Skip overlapping Wide Scan portions — go directly to debt-specific scans (step 1c).

**If not exists:** Run full Wide Scan (step 1b).

### 1b. Wide Scan (if no existing analysis)

Load `../claudboard/references/stack-detectors.md` for grep patterns per language.
Load `../claudboard/references/pattern-catalog.md` for anti-pattern patterns.

Run in parallel:
- Build file detection (identify project type, modules, dependencies)
- Structure mapping (monorepo detection, module boundaries)
- Anti-pattern grep inventory (God classes, field injection, reflection, broad catches, null returns, etc.)

### 1c. Debt-Specific Scans (always run)

These scans go beyond standard claudboard analysis. Run in parallel:

**God class deep scan:**
```bash
# Files >300 LOC in production source (Java)
find . -name '*.java' -path '*/src/main/*' ! -path '*/test/*' \
  | xargs wc -l 2>/dev/null | sort -rn | head -20

# Dependency count per class (injected fields)
grep -rn 'private final' --include='*.java' src/main/ | \
  awk -F: '{print $1}' | sort | uniq -c | sort -rn | head -15
```

**Design pattern candidates:**
```bash
# Switch statements in service/domain layer
grep -rn 'switch\s*(' --include='*.java' src/main/ | grep -v 'test\|config\|Config'

# Instanceof chains
grep -rn 'instanceof' --include='*.java' src/main/ | grep -v test

# Long if-else chains
find src/main -name '*.java' | xargs grep -c 'else if' 2>/dev/null | \
  grep -v ':0$' | sort -t: -k2 -rn | head -10

# Sequential setters (>5 on same object)
grep -rn '\.set[A-Z]' --include='*.java' src/main/ | \
  awk -F: '{print $1}' | sort | uniq -c | sort -rn | head -10

# Anemic model check: entity/model classes with only getters/setters
grep -rl '@Entity\|@Document' --include='*.java' src/main/
```

**Performance candidates:**
```bash
# DB call frequency per file (findById, save, etc.)
grep -rn 'findById\|getById\|findOne\|findAll\|save(' \
  --include='*.java' src/main/ | \
  awk -F: '{print $1}' | sort | uniq -c | sort -rn | head -15

# Loop + DB call proximity
grep -B5 'findById\|findBy\|repository\.' --include='*.java' src/main/ | \
  grep 'for\s*(\|\.forEach\|\.stream()\|\.map(' | head -10

# Missing pagination: List returns on controllers
grep -rn 'public.*List<' --include='*.java' src/main/ | \
  grep -i 'controller' | head -10

# Missing @Cacheable on reference data lookups
grep -rn 'findBy\|getBy\|findAll' --include='*.java' src/main/ | \
  grep -i 'config\|setting\|reference\|lookup\|parameter\|catalog' | \
  grep -v '@Cacheable'
```

**Architecture candidates:**
```bash
# Layer violations: controller importing repository
grep -rn 'import.*repository\.\|import.*Repository;' --include='*.java' src/main/ | \
  grep -i 'controller'

# Circular deps: service-to-service imports (build graph)
for f in $(find src/main -name '*Service.java' -o -name '*ServiceImpl.java' 2>/dev/null); do
  class=$(basename $f .java)
  grep 'import ' $f | grep -i 'service' | head -5
done

# God modules: classes per package
find src/main -name '*.java' | xargs grep -h 'package ' 2>/dev/null | \
  sed 's/package //;s/;.*//' | sort | uniq -c | sort -rn | head -10

# Direct HTTP/DB client in service layer
grep -rn 'RestTemplate\|WebClient\|HttpClient\|MongoTemplate\|JdbcTemplate' \
  --include='*.java' src/main/ | grep -i 'service'
```

### 1d. Build Candidate List

From scan results, build ranked candidate list:
1. **Read-now**: God classes >500 LOC, switch >6 cases, instanceof >3, files with >3 findById calls
2. **Read-if-budget**: God classes 300-500 LOC, switch 4-6 cases, sequential setters >5
3. **Note-only**: long methods, boolean flags, magic numbers (capture from grep, no deep read needed)

Typical counts: 5-15 read-now files, 10-25 read-if-budget files per project.

### 1e. Strategic File Reading

Read all "read-now" candidates fully. Then read "read-if-budget" candidates until analysis is thorough. No hard file limit — this is a run-once tool, not a sampling exercise.

For each file read:
- Count methods and their line ranges
- Note dependencies (injected fields, imported services)
- Identify responsibility clusters (for God classes)
- Check for design pattern candidates (switch/instanceof bodies)
- Trace call paths for DB operations (2-3 levels deep)

---

## Phase 2: Deep Analysis

Passes 1-4 can run in any order but all must complete before assigning IDs and detecting dependencies. Load reference files on-demand per pass:

| Pass | Reference file |
|------|---------------|
| Pass 1 | `references/code-smell-catalog.md` |
| Pass 2 | `references/design-debt-patterns.md` |
| Pass 3 | `references/perf-debt-patterns.md` |
| Pass 4 | `references/arch-debt-patterns.md` |
| All | `references/severity-matrix.md` |

### Pass 1: Code Smells

Load `references/code-smell-catalog.md`.

For each code smell type, create debt items from scan results:

**God classes** (deep analysis):
- Read full file
- Cluster methods by shared dependencies (see code-smell-catalog.md → "God Class Analysis")
- Name each cluster, suggest target class names
- Determine split order (least coupled first)
- Create debt item with full cluster breakdown

**Other smells** (from grep counts + sampled files):
- Long methods: note method name + line count, suggest extract-method targets
- Too many params: note method signature, suggest parameter object
- Boolean flags: note call sites, suggest enum or separate methods
- Null returns: count, note if Optional is used anywhere (compound risk if not)
- Log-and-throw: note occurrences, suggest "log OR throw"
- Copy-paste: identify repeated patterns, suggest extraction target
- Broad catches: distinguish swallow vs wrap-rethrow

Assign severity + effort from `references/severity-matrix.md`. Apply compound severity rules: when two findings co-occur (e.g., God class + no tests), escalate severity per the compound table in severity-matrix.md. See that file for the application algorithm.

### Pass 2: Design Pattern Analysis

Load `references/design-debt-patterns.md`.

For each candidate from Phase 1 scans:

**Switch/if-else → Strategy/State:**
- Read method body
- Count cases and their complexity
- Determine if switching on type discriminator (Strategy) or state field (State)
- Sketch: interface name, concrete class names, dispatch mechanism
- Only flag if cases contain significant logic (>5 lines each)

**Instanceof → Polymorphism:**
- Read method body
- List types being checked
- Suggest method to add to base type/interface
- Sketch: interface addition + implementation per subtype

**Sequential setters → Builder:**
- Count setters on same object
- Check if pattern repeats across files
- Suggest @Builder (Lombok) or manual builder

**Constructor >5 deps → Facade or Split:**
- List all dependencies
- Group by which methods use them
- If deps cluster → suggest class split
- If all deps used together → suggest Facade

**Anemic models → Rich Domain:**
- Read entity class (only getters/setters?)
- Read corresponding service class (business methods operating on entity fields?)
- Suggest which methods to move to entity

**Other patterns:** Factory (repeated `new` with many args), Observer (nested callbacks)

Create debt item per finding with pattern sketch. Sketches should be pseudo-code outlines (5-10 lines) + file-to-modify list — this is a ticket spec, not the solution code.

### Pass 3: Performance Flow Analysis

Load `references/perf-debt-patterns.md`.

For each performance candidate:

**Redundant entity fetching:**
- For files with >1 findById call for same repository: trace the call path
- Controller → service method → helper methods
- Map where same entity is fetched multiple times
- Create debt item with full call path diagram

**N+1 queries:**
- For each loop-near-DB-call finding: read method body
- Confirm DB call is inside loop (not before/after)
- Suggest batch alternative (findAllById, @Query with IN clause)

**Missing @Cacheable:**
- For reference/config data lookups without caching
- Check if caching infrastructure exists in project
- Suggest @Cacheable annotation + cache eviction point

**Missing pagination:**
- For controllers returning unbounded List
- Check if Pageable is used elsewhere in project
- Suggest Page return type + default page size config

**Sequential independent calls:**
- Read method bodies with >3 service calls
- Check if calls have data dependencies between them
- If independent: suggest CompletableFuture parallelization

**Eager loading:**
- findAll() followed by stream().filter()
- Suggest pushing filter to query

Create debt item per finding with call path and fix suggestion.

### Pass 4: Architecture Debt

Load `references/arch-debt-patterns.md`.

**Layer violations:**
- From grep results: controller→repository imports, service→controller imports
- Read import sections of flagged files
- Confirm violation (not just a shared DTO or utility)

**Circular dependencies:**
- From import graph: find A→B→A pairs at service level
- Suggest extraction point (interface, shared service, or event)

**God modules:**
- From class-per-package counts
- For packages >50 classes: categorize classes by concern
- Suggest sub-package structure

**Missing abstractions:**
- From direct HTTP/DB client usage in service layer
- Suggest gateway/adapter interface

**Dead code:**
- Endpoint methods with no callers (verify not reflection/scheduled)

**Wrong-layer responsibility:**
- Business logic in controller, DB logic in service
- Validation duplicated across layers

Create debt items. These go to `cross-cutting.md` unless they affect only one module.

### Assign IDs

After all passes, assign sequential IDs: TD-001, TD-002, ...
Order by: severity (CRITICAL first), then category (Architecture → Performance → Design → Code Smell).

### Detect Dependencies

Scan items for dependencies:
- God class split enables unit testing → TD-X depends on TD-Y
- Interface extraction enables mocking → testing debt depends on abstraction debt
- Layer fix requires service creation → layer violation fix may depend on God class split
- Note dependencies on each item.

---

## Phase 3: Report Generation

Load `references/report-template.md`.

### 3a. Determine Modules

Assign each debt item to a module:
1. If monorepo with service dirs → service name
2. If single app with domain packages → top-level domain package name
3. If no clear structure → group by top-level source directory
4. Items spanning modules → cross-cutting

### 3b. Present Summary

Before writing files, present summary to user:

```
## Tech Debt Analysis Complete

**Items found:** {N}
**By severity:** CRITICAL: {X} | HIGH: {Y} | MEDIUM: {Z} | LOW: {W}
**By category:** Code: {A} | Design: {B} | Performance: {C} | Architecture: {D}
**Quick wins:** {N} items (HIGH severity + S effort)

**Modules:** {list}

**Top 3 items:**
1. [TD-{NNN}] {title} — {severity} / {effort}
2. [TD-{NNN}] {title} — {severity} / {effort}
3. [TD-{NNN}] {title} — {severity} / {effort}

Ready to write report to .claude/reports/tech-debt/? (summary.md + modules/ + cross-cutting.md)
```

### 3c. Write Files

After user confirms, create:

```
.claude/reports/tech-debt/
├── summary.md              # Priority matrix, module table, top 5, dep chains
├── modules/
│   ├── {module-a}.md       # Debt items for module A
│   ├── {module-b}.md       # Debt items for module B
│   └── ...
└── cross-cutting.md        # Architecture-level, cross-module items
```

Use templates from `references/report-template.md`. Include YAML frontmatter on summary.md with `generated_at`, `repo`, `version`, `modules_scanned`, `total_items`.

---

## Error Handling

| Condition | Behavior |
|-----------|----------|
| Target path doesn't exist | Report error with path and stop |
| No source files found (wrong directory) | Report "no source files found", suggest correct path, stop |
| Grep command returns no results for a category | Continue with 0 candidates for that category — report "none detected" |
| Existing analysis report is malformed/unreadable | Ignore it, run full Wide Scan (step 1b) as if no report exists |
| User cancels during Phase 3 confirmation | Discard, exit cleanly — no files written |

## Output Validation

Before presenting the Phase 3 summary, verify:
- All debt items have sequential IDs (TD-001, TD-002, ...)
- No orphaned dependencies (if TD-X depends on TD-Y, TD-Y must exist)
- Total items = sum across all categories
- No duplicate items (same file + same pattern = one item, not two)

## Constraints

- **Read-only for source code.** Only writes to `.claude/reports/tech-debt/`.
- **Never modify source code, tests, or existing project files.**
- **Secrets found during scan:** Report file:line only, never print the value.
- **If path doesn't exist:** State clearly and stop.
- **Present summary before writing** — user confirms before files are created.
- **No hard limit on file reads** — thoroughness over speed for this run-once tool.

## Reference Files

| File | When to load |
|------|-------------|
| `../claudboard/references/stack-detectors.md` | Phase 1b — Wide Scan patterns (if no existing analysis) |
| `../claudboard/references/pattern-catalog.md` | Phase 1b — anti-pattern grep patterns (if no existing analysis) |
| `references/code-smell-catalog.md` | Phase 2 Pass 1 |
| `references/design-debt-patterns.md` | Phase 2 Pass 2 |
| `references/perf-debt-patterns.md` | Phase 2 Pass 3 |
| `references/arch-debt-patterns.md` | Phase 2 Pass 4 |
| `references/severity-matrix.md` | Phase 2 — all passes |
| `references/report-template.md` | Phase 3 |
