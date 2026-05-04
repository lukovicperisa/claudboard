# Claudboard Self-Analysis — Shared Issue Catalog

Accumulated findings across all recursive self-analysis iterations.
Issues are added once — later iterations reference existing entries, not duplicate them.

---

## Resolved Issues (Iterations 1-3)

These were found and fixed in iterations 1-3. Listed here to prevent re-discovery.

### R-01: Buggy grep glob in techdebt SKILL.md
- **File:** `skills/claudboard-techdebt/SKILL.md`
- **Issue:** `grep -c 'else if' --include='*.java' src/main/**/*.java` — glob doesn't expand inside grep args
- **Fix applied:** Changed to `find src/main -name '*.java' | xargs grep -c 'else if'`
- **Iteration:** 1

### R-02: Missing error handling in analyse and techdebt
- **File:** `skills/claudboard-analyse/SKILL.md`, `skills/claudboard-techdebt/SKILL.md`
- **Issue:** No error handling section for bad path, no source files, etc.
- **Fix applied:** Added error handling tables to both files
- **Iteration:** 1

### R-03: Missing error handling in generate and refresh
- **File:** `skills/claudboard-generate/SKILL.md`, `skills/claudboard-refresh/SKILL.md`
- **Issue:** Same class of issue as R-02 but missed in iteration 1
- **Fix applied:** Added error handling tables to both files
- **Iteration:** 2

### R-04: No output validation checklist in techdebt
- **File:** `skills/claudboard-techdebt/SKILL.md`
- **Issue:** No verification that IDs are sequential, deps aren't orphaned, no duplicates
- **Fix applied:** Added output validation section before Phase 3 summary
- **Iteration:** 1

### R-05: No compound severity algorithm in severity-matrix.md
- **File:** `skills/claudboard-techdebt/references/severity-matrix.md`
- **Issue:** Compound severity was mentioned but no application steps defined
- **Fix applied:** Added 5-step algorithm + effort modifier stacking + category priority
- **Iteration:** 1

### R-06: Step→Phase terminology inconsistency
- **File:** All sub-skills + dispatcher
- **Issue:** Generate/refresh used "Step", analyse used "Phase", dispatcher used "Step 1/Step 2"
- **Fix applied:** Iteration 2 fixed generate+refresh, iteration 3 fixed dispatcher
- **Note:** Incomplete scope in iteration 2 required iteration 3 follow-up
- **Iteration:** 2+3

### R-07: Compound severity source-of-truth ambiguity
- **File:** `skills/claudboard-techdebt/SKILL.md`, `references/severity-matrix.md`, `../claudboard/references/pattern-catalog.md`
- **Issue:** Both severity-matrix.md and pattern-catalog.md had compound rules without precedence
- **Fix applied:** Iteration 1 added algorithm to severity-matrix, iteration 2 referenced it from techdebt, iteration 3 clarified severity-matrix.md takes precedence
- **Note:** Cascading fix chain — each iteration partially addressed it
- **Iteration:** 1+2+3

### R-08: Analyse→generate handoff double-prompt
- **File:** `skills/claudboard-analyse/SKILL.md`
- **Issue:** Iteration 2 introduced a double-prompt (ask, then warn, then ask again). Iteration 3 simplified to single prompt.
- **Note:** Iteration 2 made this worse; iteration 3 reverted to clean design
- **Iteration:** 2→3

### R-09: Error message wording inconsistency
- **File:** `skills/claudboard-analyse/SKILL.md`, `skills/claudboard-techdebt/SKILL.md`
- **Issue:** Different wording for "no source files" error across skills
- **Fix applied:** Standardized to "no source files found at [path]"
- **Note:** Iteration 1 introduced the inconsistency by adding error handling with different wording
- **Iteration:** 1→3

### R-10: Missing God class naming convention
- **File:** `skills/claudboard-techdebt/references/code-smell-catalog.md`
- **Issue:** No guidance on naming split classes
- **Fix applied:** Added `{CoreResponsibility}{Capability}` pattern, avoid Helper/Util/Manager
- **Iteration:** 1

### R-11: Missing phase sequencing note in techdebt
- **File:** `skills/claudboard-techdebt/SKILL.md`
- **Issue:** Unclear whether Phase 2 passes must run in order
- **Fix applied:** Added "Passes 1-4 can run in any order but all must complete before assigning IDs"
- **Iteration:** 1

### R-12: Missing candidate count guidance in techdebt
- **File:** `skills/claudboard-techdebt/SKILL.md`
- **Issue:** No sense of "how many files is typical"
- **Fix applied:** Added "5-15 read-now, 10-25 read-if-budget per project"
- **Iteration:** 1

### R-13: Skill dedup preservation missing in generate
- **File:** `skills/claudboard-generate/SKILL.md`
- **Issue:** Generate could re-evaluate skill dedup decisions already made during analyse
- **Fix applied:** Added "If the report contains skill dedup decisions, preserve those — don't re-evaluate"
- **Iteration:** 2

### R-14: Refresh didn't mention /techdebt as next step
- **File:** `skills/claudboard-refresh/SKILL.md`
- **Issue:** Completion report listed `/refresh` but not `/techdebt`
- **Fix applied:** Added techdebt mention in completion section
- **Iteration:** 2

### R-15: Techdebt sketch depth ambiguous
- **File:** `skills/claudboard-techdebt/SKILL.md`
- **Issue:** Unclear whether "sketch" means full solution or ticket outline
- **Fix applied:** Clarified "5-10 lines pseudo-code + file-to-modify list — ticket spec, not solution code"
- **Iteration:** 2

### R-16: Skill overlap presentation format missing
- **File:** `skills/claudboard-analyse/SKILL.md`
- **Issue:** Dedup check existed but no template for showing overlaps to user
- **Fix applied:** Added explicit presentation format with merge/separate prompt
- **Iteration:** 3

### R-17: Zero-results guidance missing in Wide Scan
- **File:** `skills/claudboard-analyse/SKILL.md`
- **Issue:** No inline guidance for when a grep category returns 0 results
- **Fix applied:** Added "record 'none detected' and continue" inline
- **Iteration:** 3

### R-18: Merge-vs-replace constraint wording confusing in generate
- **File:** `skills/claudboard-generate/SKILL.md`
- **Issue:** "Never modify source" and "merge, don't replace" were separate bullets that could be misread
- **Fix applied:** Consolidated to two clear bullets
- **Iteration:** 3

### R-19: Severity hints in code-smell-catalog.md could conflict with severity-matrix.md
- **File:** `skills/claudboard-techdebt/references/code-smell-catalog.md`
- **Issue:** Inline severity hints without noting source-of-truth
- **Fix applied:** Added "Use severity-matrix.md for final severity assignment. Hints in this file are approximate"
- **Iteration:** 1

### R-20: Token estimation guide missing
- **File:** `skills/claudboard/references/quality-signals.md`
- **Issue:** No guidance on estimating persistent context token overhead
- **Fix applied:** Added Token Estimation Guide section
- **Iteration:** 1 (plan phase, pre-iteration)

### R-21: Workflow detection missing in stack-detectors.md
- **File:** `skills/claudboard/references/stack-detectors.md`
- **Issue:** No section on detecting project-specific workflows (README rituals, ADRs, subclass patterns)
- **Fix applied:** Added Project-Specific Workflow Detection section
- **Iteration:** 1 (plan phase, pre-iteration)

---

## Open Issues (Iterations 4+)

### N-01: Small repo workflow incoherence (analyse)
- **File:** `skills/claudboard-analyse/SKILL.md`
- **Issue:** Step 1c says "skip if <50 files" but 1d says "use the Pattern Inventory from 1c" — for small repos, there is no inventory
- **Severity:** MEDIUM
- **Suggested fix:** Clarify small-repo path in 1d: read all files directly, skip file selection algorithm
- **Iteration found:** 4

### N-02: Zero-result Pattern Inventory format unspecified (analyse)
- **File:** `skills/claudboard-analyse/SKILL.md`
- **Issue:** When all searches in a category return 0, unclear whether to include `{category}: none` or omit entirely from inventory
- **Severity:** MEDIUM
- **Suggested fix:** State "include empty categories as `none` in the inventory for completeness"
- **Iteration found:** 4

### N-03: Quality score not summarized for adaptive depth decision (analyse→generate)
- **File:** `skills/claudboard-analyse/SKILL.md`, `skills/claudboard-generate/SKILL.md`
- **Issue:** Generate needs "4+ dimensions Good → full rules" but analyse report template doesn't include a count or summary table — generate must infer from narrative
- **Severity:** HIGH
- **Suggested fix:** Add quality score summary table to analyse Phase 2 template with dimension ratings and resulting adaptive depth level
- **Iteration found:** 4

### N-04: Duplicate call-path tracing between analyse and techdebt (analyse, techdebt)
- **File:** `skills/claudboard-analyse/SKILL.md`, `skills/claudboard-techdebt/SKILL.md`
- **Issue:** Both trace call paths independently. If `/techdebt` runs after `/analyse` with existing report, it skips overlapping Wide Scan but not overlapping call-path traces
- **Severity:** MEDIUM
- **Suggested fix:** In techdebt step 1a, add instruction to reuse call-path findings from existing analysis when present
- **Iteration found:** 4

### N-05: Testing dimension unclear when coverage tools absent (analyse, quality-signals)
- **File:** `skills/claudboard-analyse/SKILL.md`, `skills/claudboard/references/quality-signals.md`
- **Issue:** "Test framework + coverage + CI gate" = Good, but many projects have tests in CI with no coverage tool. Rating unclear.
- **Severity:** MEDIUM
- **Suggested fix:** Expand testing rating table: tests + CI but no coverage = "Acceptable" (not "Good" or "Missing")
- **Iteration found:** 4

### N-06: TechDebt "Depends on" field too restrictive (techdebt report-template)
- **File:** `skills/claudboard-techdebt/references/report-template.md`
- **Issue:** Only allows TD-IDs or "—" for dependencies. Can't express external blockers (library upgrade, team decision)
- **Severity:** LOW
- **Suggested fix:** Allow free-text in parentheses for external dependencies
- **Iteration found:** 4

### N-07: Wide Scan grep patterns only cover Java/Kotlin (stack-detectors)
- **File:** `skills/claudboard/references/stack-detectors.md`
- **Issue:** Analyse says "see stack-detectors.md for exact commands per language" but Wide Scan section only has Java/Kotlin patterns — missing TypeScript, Python, Go, Rust, .NET
- **Severity:** HIGH
- **Suggested fix:** Either add patterns for other languages or update analyse instruction to say "Java/Kotlin patterns provided; for other languages, derive from pattern-catalog.md"
- **Iteration found:** 4

### N-08: Convention consistency evidence incomplete (analyse)
- **File:** `skills/claudboard-analyse/SKILL.md`
- **Issue:** Phase 1f records DI pattern, logging style, error handling per call path — but Quality Assessment "Convention consistency" evidence only says "[linting, sample finding]", losing the 1f data
- **Severity:** MEDIUM
- **Suggested fix:** Add "DI pattern, logging style, error handling strategy" to Convention consistency evidence list
- **Iteration found:** 4

### N-09: Severity-matrix should load once at Phase 2 start, not per-pass (techdebt)
- **File:** `skills/claudboard-techdebt/SKILL.md`
- **Issue:** "Load reference files on-demand per pass" could cause inconsistent severity if passes run in parallel and each loads severity-matrix independently
- **Severity:** LOW
- **Suggested fix:** "Load severity-matrix.md once at start of Phase 2; load catalog references on-demand per pass"
- **Iteration found:** 4

### N-10: Monorepo quality scores are global, not per-service (analyse) — RESOLVED
- **File:** `skills/claudboard-analyse/SKILL.md`
- **Resolution:** Per-service quality scoring added to Phase 2. "For monorepos: Score each service independently, then derive global score with variance note."
- **Resolved by:** monorepo-support change

### N-11: No polyglot rule splitting guidance (analyse)
- **File:** `skills/claudboard-analyse/SKILL.md`
- **Issue:** Proposed Artifacts lists rules with paths: globs but no guidance on when to merge vs split cross-language rules in polyglot projects
- **Severity:** LOW
- **Suggested fix:** "One rule per language if conventions differ; merge if identical conventions"
- **Iteration found:** 4

### N-12: Severity hints in catalogs not all covered by severity-matrix (techdebt references)
- **File:** `skills/claudboard-techdebt/references/code-smell-catalog.md`, `references/severity-matrix.md`
- **Issue:** Some smells in code-smell-catalog have severity hints but no corresponding entry in severity-matrix, creating ambiguity about which file to use
- **Severity:** HIGH
- **Suggested fix:** Either ensure every smell appears in the matrix, or add explicit fallback: "matrix takes precedence when present; catalog hints apply when matrix has no entry"
- **Iteration found:** 4

---

### N-13: Compound severity rules defined in two files with different content (pattern-catalog vs severity-matrix)
- **File:** `skills/claudboard/references/pattern-catalog.md`, `skills/claudboard-techdebt/references/severity-matrix.md`
- **Issue:** pattern-catalog.md has compound rules for analyse (e.g., `return null + Reflection`), severity-matrix.md has different compound rules for techdebt (e.g., `God class + Circular deps`). Neither file documents which skill should use which table.
- **Related to:** N-12, R-07 — same severity-conflict family but this is about the compound tables specifically
- **Severity:** HIGH
- **Suggested fix:** Add ownership preamble to each: "These compound rules are used by [analyse/techdebt]." Or consolidate into one table with context column.
- **Iteration found:** 5

### N-14: Same finding gets different base severity across reference files
- **File:** `skills/claudboard/references/pattern-catalog.md`, `skills/claudboard-techdebt/references/severity-matrix.md`
- **Issue:** God class = MEDIUM in pattern-catalog, HIGH/CRITICAL in severity-matrix. Broad catch = MEDIUM vs HIGH. No documentation of why they differ.
- **Related to:** N-13
- **Severity:** MEDIUM
- **Suggested fix:** Audit overlapping anti-patterns, align or document why they differ (analysis-level vs debt-level assessment)
- **Iteration found:** 5

### N-15: Skill-generation.md has no templates for Go, Rust, .NET, or infrastructure skills
- **File:** `skills/claudboard/references/skill-generation.md`
- **Issue:** Only covers Spring Boot, React/TS, Python. Stack-detectors.md detects Go/Rust/.NET but skill-generation has no templates for them.
- **Severity:** MEDIUM
- **Suggested fix:** Add template sections for Go, Rust, .NET, and Infrastructure, or document "use the general-purpose template for unlisted stacks"
- **Iteration found:** 5

### N-16: [Project Name] placeholder in rule-templates.md never explained
- **File:** `skills/claudboard/references/rule-templates.md`
- **Issue:** Templates use `[Project Name]` but generate skill doesn't specify what value to use (repo name? service name? omit?)
- **Severity:** LOW
- **Suggested fix:** Clarify: "use repo name for single-service, service name for monorepo, or omit entirely"
- **Iteration found:** 5

### N-17: Defensive Lambdas anti-pattern missing from code-smell-catalog.md
- **File:** `skills/claudboard-techdebt/references/code-smell-catalog.md`
- **Issue:** pattern-catalog.md lists "Defensive lambdas" (try-catch inside streams) as MEDIUM anti-pattern, but code-smell-catalog has no detection strategy for it
- **Severity:** MEDIUM
- **Suggested fix:** Add Defensive Lambdas section with grep detection pattern and analysis guidance
- **Iteration found:** 5

### N-18: Reflection performance overhead not in perf-debt-patterns.md
- **File:** `skills/claudboard-techdebt/references/perf-debt-patterns.md`
- **Issue:** pattern-catalog.md flags reflection as a performance concern, but perf-debt-patterns has no section for it
- **Severity:** MEDIUM
- **Suggested fix:** Add "Reflection Performance Overhead in Hot Path" section with grep and mitigation guidance
- **Iteration found:** 5

### N-19: Wrong-layer responsibility examples too generic in arch-debt-patterns.md
- **File:** `skills/claudboard-techdebt/references/arch-debt-patterns.md`
- **Issue:** Suggest block uses `{wrong layer responsibility description}` placeholder instead of concrete common cases
- **Severity:** LOW
- **Suggested fix:** Add 2-3 common examples: DB logic in service, validation in controller, business logic in DTO mapping
- **Iteration found:** 5

### N-20: Severity-matrix uses terms defined only in other reference files
- **File:** `skills/claudboard-techdebt/references/severity-matrix.md`
- **Issue:** Uses "Anemic domain model" (defined in code-smell-catalog), "God module" (defined in arch-debt-patterns) without inline definitions
- **Severity:** LOW
- **Suggested fix:** Add brief inline clarifications or "see [file]" cross-references
- **Iteration found:** 5

### N-21: Rule merge strategy ambiguous (append vs update vs merge)
- **File:** `skills/claudboard/references/rule-templates.md`
- **Issue:** Merge strategy says "append or update" but doesn't specify when to do which. If existing section has 3 conventions and analysis finds 2 more — append new section or merge into existing?
- **Severity:** LOW
- **Suggested fix:** Define: same section exists → add bullets within it; contradicts → mark as UPDATED; new section → add at end
- **Iteration found:** 5

---

### N-22: Kotlin-only project grep patterns fragmented (analyse)
- **File:** `skills/claudboard-analyse/SKILL.md`
- **Issue:** Wide Scan runs separate greps for `.java` and `.kt` — a Kotlin-only project gets partial results because Java-specific patterns (e.g., `@interface`) dominate the examples
- **Severity:** MEDIUM
- **Suggested fix:** Use combined `--include='*.java' --include='*.kt'` in single grep calls where patterns apply to both languages
- **Iteration found:** 6

### N-23: Gradle Kotlin DSL version extraction not documented (stack-detectors)
- **File:** `skills/claudboard/references/stack-detectors.md`
- **Issue:** Java version extraction heuristic only covers `build.gradle` (Groovy DSL). `build.gradle.kts` uses different syntax (`java { sourceCompatibility = JavaVersion.VERSION_21 }`)
- **Severity:** LOW
- **Suggested fix:** Add Kotlin DSL extraction pattern to stack-detectors.md Java/Kotlin section
- **Iteration found:** 6

### N-24: Monorepo test framework detection per-module not specified (analyse) — RESOLVED
- **File:** `skills/claudboard-analyse/SKILL.md`
- **Resolution:** Phases 1c-h now run per service in monorepo mode, scoped to each service directory. Phase 1e therefore detects test frameworks per service by construction.
- **Resolved by:** monorepo-support change

### N-25: Reflection in call-path tracing not addressed (analyse)
- **File:** `skills/claudboard-analyse/SKILL.md`
- **Issue:** Phase 1f traces call paths but doesn't specify what to do when a reflected method is encountered mid-trace (e.g., `Method.invoke()` in service layer)
- **Severity:** LOW
- **Suggested fix:** Add to 1f: "If reflection detected in traced path, note as 'reflection in hot path' for Phase 2"
- **Iteration found:** 6

### N-26: Generate doesn't handle malformed/partial analysis reports (generate) — RESOLVED
- **File:** `skills/claudboard-generate/SKILL.md`
- **Resolution:** Phase 1 now validates structure: "check that 'Proposed Artifacts' section exists. If missing, tell user to re-run `/analyse`."
- **Resolved by:** earlier iteration (pre monorepo-support change)

### N-27: Refresh doesn't validate rule paths: glob syntax (refresh)
- **File:** `skills/claudboard-refresh/SKILL.md`
- **Issue:** Phase 2b reads `paths:` globs from existing rules but doesn't validate syntax. Invalid globs would cause silent comparison failures in Phase 3b.
- **Severity:** LOW
- **Suggested fix:** Add: "If a glob is syntactically invalid, report and skip coverage check for that rule"
- **Iteration found:** 6

### N-28: Techdebt doesn't handle test-only projects (techdebt)
- **File:** `skills/claudboard-techdebt/SKILL.md`
- **Issue:** All grep patterns target `src/main/`. A test-only project (e.g., E2E test suite) would produce empty scan results without explanation.
- **Severity:** MEDIUM
- **Suggested fix:** Add to Phase 1: "If no production source found (only test code), tell user and stop cleanly"
- **Iteration found:** 6

### N-29: "High-traffic endpoint" undefined in severity-matrix (techdebt references)
- **File:** `skills/claudboard-techdebt/references/severity-matrix.md`
- **Issue:** Compound rule "N+1 query + High-traffic endpoint (>10 callers)" uses undefined term. Unclear if "callers" means code call-sites or runtime traffic.
- **Severity:** MEDIUM
- **Suggested fix:** Define: ">10 call sites in codebase, OR public API endpoint, OR no auth annotation"
- **Iteration found:** 6

### N-32: Code-smell-catalog boolean flag suggestions are Java-only (techdebt references)
- **File:** `skills/claudboard-techdebt/references/code-smell-catalog.md`
- **Issue:** Boolean flag fix suggestions ("separate methods or enum") are Java-centric. TypeScript would use discriminated unions, Python uses keyword args.
- **Severity:** LOW
- **Suggested fix:** Add per-language fix variants
- **Iteration found:** 6

### N-33: "Good" quality dimension definition inconsistent across rows (quality-signals) — CLOSED (by design)
- **File:** `skills/claudboard/references/quality-signals.md`
- **Resolution:** By design. Each dimension has different nature and signal types. Forcing uniform signal counts across dimensions (e.g., requiring 3 signals everywhere) would be artificial. Testing naturally has 3 measurable signals; Architecture is inherently more qualitative. The table works as per-dimension checklists, not as a uniform scoring rubric.
- **Closed by:** monorepo-support exploration

### N-34: Monorepo file reading budget not specified per-service (analyse) — RESOLVED
- **File:** `skills/claudboard-analyse/SKILL.md`
- **Resolution:** Phase 1d already contains: "For monorepos with M services: if M ≤ 3 use full budget per service; if M > 3 allocate proportionally."
- **Resolved by:** earlier iteration (pre monorepo-support change)

### N-40: README overstates non-Java stack completeness
- **File:** `README.md`
- **Issue:** "Tested on" lists Go, Rust, .NET but skill-generation.md only has Java/Spring templates. Analysis works for all stacks but generation is incomplete for non-Java.
- **Severity:** MEDIUM
- **Suggested fix:** Clarify: "Analysis works for all stacks; skill generation templates exist for Java/Spring Boot, React/TS, Python. Other stacks use general-purpose template."
- **Iteration found:** 6

### N-41: CLAUDE.md template missing Contributing/Development Workflow section
- **File:** `skills/claudboard/references/claude-md-template.md`
- **Issue:** Template has no section for branch strategy, commit format, PR requirements — critical context for daily Claude Code use
- **Severity:** LOW
- **Suggested fix:** Add optional "## Contributing / Development Workflow" section with placeholders
- **Iteration found:** 6

---

## Duplicates Detected in Iteration 6

8 of 21 iteration-6 findings were re-discoveries of existing catalog entries:
| Iteration 6 ID | Duplicate of | Topic |
|----------------|-------------|-------|
| N-30 | N-07 | Wide Scan patterns only Java/Kotlin |
| N-31 | N-15 | Skill-generation missing Go/Rust/.NET |
| N-35 | N-17 | Defensive lambdas missing from code-smell-catalog |
| N-36 | N-18 | Reflection perf missing from perf-debt-patterns |
| N-37 | N-21 | Rule merge strategy ambiguous |
| N-38 | N-16 | [Project Name] placeholder unexplained |
| N-39 | N-19 | Wrong-layer examples too generic |
| N-42 | N-02 | Zero-result handling ambiguity |

This demonstrates the value of the shared catalog — without it, 38% of iteration 6 findings would have been wasted work.
