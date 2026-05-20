# Report Templates

Use during Phase 3 to generate output files.

---

## summary.md Template

```markdown
---
generated_at: {ISO 8601 timestamp}
repo: {absolute path}
version: "1.0.0"
modules_scanned: {N}
total_items: {N}
---

# Tech Debt Report — {project-name}

## Overview

| Metric | Count |
|--------|-------|
| Total items | {N} |
| Critical | {N} |
| High | {N} |
| Medium | {N} |
| Low | {N} |
| Quick wins (HIGH + S effort) | {N} |

**By category:**
- Code Smells: {N}
- Design Debt: {N}
- Performance Debt: {N}
- Architecture Debt: {N}

## Priority Matrix

```
              LOW effort    MED effort    HIGH effort
            ┌─────────────┬─────────────┬─────────────┐
  CRITICAL  │ DO NOW      │ PLAN SPRINT │ PLAN EPIC   │
            │ {TD-IDs}    │ {TD-IDs}    │ {TD-IDs}    │
            ├─────────────┼─────────────┼─────────────┤
  HIGH      │ QUICK WIN   │ PLAN SPRINT │ BACKLOG     │
            │ {TD-IDs}    │ {TD-IDs}    │ {TD-IDs}    │
            ├─────────────┼─────────────┼─────────────┤
  MEDIUM    │ QUICK WIN   │ BACKLOG     │ CONSIDER    │
            │ {TD-IDs}    │ {TD-IDs}    │ {TD-IDs}    │
            ├─────────────┼─────────────┼─────────────┤
  LOW       │ OPPORTUNIST │ BACKLOG     │ SKIP        │
            │ {TD-IDs}    │ {TD-IDs}    │ {TD-IDs}    │
            └─────────────┴─────────────┴─────────────┘
```

## Module Summary

| Module | Items | Critical | High | Medium | Low | Top Issue |
|--------|-------|----------|------|--------|-----|-----------|
| {module} | {N} | {N} | {N} | {N} | {N} | {TD-NNN: one-liner} |
| ... | | | | | | |
| _cross-cutting_ | {N} | {N} | {N} | {N} | {N} | {TD-NNN: one-liner} |

## Top 5 Items

1. **[TD-{NNN}] {Title}** — {Category} / {Severity} / Effort: {S|M|L}
   {One-line description of impact}

2. ...

## Dependency Chains

Items that block or enable other items:

- TD-{A} → enables TD-{B}, TD-{C} ({reason})
- TD-{D} → blocks TD-{E} ({reason})

## Files

- [Summary](summary.md) — this file
- [Cross-cutting debt](cross-cutting.md)
{for each module:}
- [{module-name}](modules/{module-name}.md) — {N} items
```

---

## Module Report Template (modules/{name}.md)

```markdown
---
module: {module-name}
source_path: {path to module root}
items: {N}
critical: {N}
high: {N}
---

# Tech Debt — {Module Name}

{One sentence describing what this module does.}

## Items

### [TD-{NNN}] {Descriptive Title}

| Field | Value |
|-------|-------|
| Category | {Code Smell / Design / Performance / Architecture} |
| Severity | {CRITICAL / HIGH / MEDIUM / LOW} |
| Location | `{file:line}` |
| Effort | {S / M / L} |
| Depends on | {TD-XXX or "—"} |

**What:** {Description of the problem — 1-3 sentences}

**Why it matters:** {Impact — performance, maintainability, risk. Include numbers if available.}

**Fix:** {Suggested approach with concrete names from the codebase}

---

{Repeat for each item in this module}

## Architectural Pattern Gaps

{Only include this section if Pass 4b detected one or more gaps. Omit entirely if no gaps found.}

### [TD-{NNN}] {Gap title — from arch-pattern-gaps.md template}

**Severity:** {MEDIUM | HIGH}
**Effort:** {M | L}
**Category:** Architectural Pattern Gap

**Issue:** {From the gap template — describe the missing pattern and the risk it creates}

**Evidence:** {file:line references from the analysis report's cross_service_edges or grep confirmation output}

**Fix:**
{Numbered fix steps from arch-pattern-gaps.md}

**References:** {From arch-pattern-gaps.md}

**Depends on:** —

---
```

---

## God Class Item Format (extended)

When a debt item is a God class, add responsibility cluster breakdown:

```markdown
### [TD-{NNN}] God Class: {ClassName} ({N} LOC, {M} dependencies)

| Field | Value |
|-------|-------|
| Category | Code Smell |
| Severity | {based on LOC + test coverage} |
| Location | `{file path}` |
| Effort | L |
| Depends on | — |

**What:** {ClassName} handles {N} distinct responsibilities across {LOC} lines
with {M} injected dependencies.

**Why it matters:** Changes to any responsibility risk breaking others.
{M} dependencies = {M} reasons to change. {test coverage status}.

**Responsibility clusters:**

```
{ClassName}.java ({LOC} LOC)
├── {Cluster1 name}    (lines {X}-{Y})    → {SuggestedClass1}
│     Uses: {dep1}, {dep2}
│     Methods: {method1}(), {method2}()
├── {Cluster2 name}    (lines {A}-{B})    → {SuggestedClass2}
│     Uses: {dep3}
│     Methods: {method3}(), {method4}()
└── {Cluster3 name}    (lines {C}-{D})    → {SuggestedClass3}
      Uses: {dep4}, {dep5}
      Methods: {method5}(), {method6}(), {method7}()
```

**Split order:** {Least coupled cluster} first (fewest inbound deps from
other clusters) → ... → {Most entangled cluster} last.

**Fix:** Extract each cluster into its own class. Start with
{SuggestedClass1} (only depends on {dep1}, {dep2} — cleanest boundary).
```

---

## Design Pattern Item Format (extended)

When a debt item suggests a design pattern:

```markdown
### [TD-{NNN}] Missing {Pattern}: {context description}

| Field | Value |
|-------|-------|
| Category | Design |
| Severity | {from severity-matrix} |
| Location | `{file:line}` |
| Effort | M |
| Depends on | {TD-XXX or "—"} |

**What:** {Description of current code structure}

**Why it matters:** {OCP violation / type-unsafe / hard to extend / etc.}
Adding new {thing} requires modifying {ClassName}.{method}().

**Pattern:** {Strategy / State / Builder / etc.}

**Current:** {what exists — e.g., switch on type in method()}

**Suggested:**
```
{Pattern sketch — interface + concrete classes}
```

**Fix:** {Step-by-step approach}
```

---

## Performance Item Format (extended)

When a debt item is performance-related:

```markdown
### [TD-{NNN}] {Performance issue title}

| Field | Value |
|-------|-------|
| Category | Performance |
| Severity | {from severity-matrix} |
| Location | `{file:line}` |
| Effort | {S / M} |
| Depends on | — |

**What:** {Description with call path}

**Call path:**
```
{Controller}.{method}()
  → {Service}.{method1}()  — calls {repo}.findById(id)  ← fetch 1
  → {Service}.{method2}()  — calls {repo}.findById(id)  ← fetch 2 (redundant)
  → {Service}.{method3}()  — calls {repo}.findById(id)  ← fetch 3 (redundant)
```

**Why it matters:** {N} unnecessary DB roundtrips per {operation}.
At {traffic estimate}: {impact estimate}.

**Fix:** {Specific fix with code sketch}
```

---

## cross-cutting.md Template

```markdown
---
items: {N}
critical: {N}
high: {N}
---

# Cross-Cutting Tech Debt

Items that span multiple modules or affect the overall architecture.

## Items

{Same item format as module reports}

## Architecture Overview

{Optional: ASCII diagram showing the problematic cross-cutting concerns,
e.g., circular dependencies, layer violations across modules}
```
