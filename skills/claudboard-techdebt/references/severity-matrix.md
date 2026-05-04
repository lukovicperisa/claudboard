# Severity Matrix & Effort Estimation

Use during Phase 2 to assign severity and effort to each debt item.

This is the **single source of truth** for severity assignment. The `Overview` column applies during broad project analysis (`/analyse`), while the `Debt` column applies during deep tech debt analysis (`/techdebt`).

For findings not listed in this matrix, use **MEDIUM** as the default severity.

---

## Severity Rules

### Code Smells

| Signal | Overview (analyse) | Debt (techdebt) |
|--------|-------------------|-----------------|
| God class >500 LOC, no tests covering it | HIGH | CRITICAL |
| God class >500 LOC, tests exist | MEDIUM | HIGH |
| God class 300-500 LOC | MEDIUM | MEDIUM |
| Long method >50 lines | LOW | MEDIUM |
| Long method 30-50 lines | LOW | LOW |
| Too many parameters >7 | MEDIUM | MEDIUM |
| Too many parameters 4-7 | LOW | LOW |
| Boolean flag argument on public API | MEDIUM | MEDIUM |
| Boolean flag on internal method | LOW | LOW |
| `return null` in service/repository layer | MEDIUM | MEDIUM |
| Log-and-throw in same catch block | MEDIUM | LOW |
| Copy-paste: same 5+ line block 3+ times | MEDIUM | MEDIUM |
| Copy-paste: same block 5+ times | MEDIUM | HIGH |
| Broad `catch(Exception)` that swallows | HIGH | HIGH |
| Broad `catch(Exception)` that wraps/rethrows | MEDIUM | LOW |
| Magic numbers in business logic | LOW | LOW |
| Star imports | LOW | LOW |

### Design Debt

| Signal | Overview (analyse) | Debt (techdebt) |
|--------|-------------------|-----------------|
| Switch >6 cases on type discriminator | HIGH | HIGH |
| Switch 4-6 cases on type discriminator | MEDIUM | MEDIUM |
| Instanceof chain >3 types | MEDIUM | MEDIUM |
| Instanceof chain >6 types | HIGH | HIGH |
| Sequential setters >8 (missing Builder) | MEDIUM | MEDIUM |
| Sequential setters 5-8 | LOW | LOW |
| Constructor with >7 dependencies | MEDIUM | MEDIUM |
| Anemic domain model (entity package, only getters/setters) | MEDIUM | MEDIUM |
| Utility class with mutable state | MEDIUM | MEDIUM |
| Manual object copy (field-by-field) >5 fields | MEDIUM | MEDIUM |
| Nested callbacks >3 levels | MEDIUM | MEDIUM |

### Performance Debt

| Signal | Overview (analyse) | Debt (techdebt) |
|--------|-------------------|-----------------|
| Same entity fetched >2x in one request path | HIGH | HIGH |
| DB call inside loop body (N+1) | HIGH | HIGH |
| Missing pagination on list endpoint returning unbounded results | HIGH | HIGH |
| Missing @Cacheable on reference/config data queried per request | MEDIUM | MEDIUM |
| Sequential independent service calls (parallelizable) | MEDIUM | MEDIUM |
| String concatenation in loop (should be StringBuilder) | LOW | LOW |
| findAll() when filtered subset needed | MEDIUM | MEDIUM |
| Eager loading of unused relations | MEDIUM | MEDIUM |

### Architecture Debt

| Signal | Overview (analyse) | Debt (techdebt) |
|--------|-------------------|-----------------|
| Controller imports Repository directly (layer skip) | HIGH | HIGH |
| Circular module dependency (A→B→A) | HIGH | HIGH |
| God module >50 classes in one package | MEDIUM | MEDIUM |
| Missing interface for external service call | MEDIUM | MEDIUM |
| Dead endpoint (no route, no caller) | LOW | LOW |
| Business logic in controller | MEDIUM | MEDIUM |
| DB/persistence logic in service (not repository) | MEDIUM | MEDIUM |
| Validation logic in controller (should be service/domain) | LOW | LOW |
| Shared mutable state between services | HIGH | HIGH |

---

## Compound Severity Rules

**These compound rules apply during deep tech debt analysis (`/techdebt`).** For compound rules used during project analysis (`/analyse`), see `../claudboard/references/pattern-catalog.md`.

When two findings co-occur, escalate. Apply after individual scoring.

**Application algorithm:**
1. Score each finding individually using the primary rules above
2. Check each *pair* of findings against the compound table below
3. If a finding participates in multiple compound rules, take the **highest** escalation
4. Compound severity cannot exceed CRITICAL
5. Report format: `[ESCALATED — compound] Finding A + Finding B → risk (individually: sevA + sevB)`

| Finding A | Finding B | Escalated | Risk |
|-----------|-----------|-----------|------|
| God class >500 LOC | No tests | CRITICAL | Untestable complexity, any change = risk |
| God class | Circular dependency involving that class | CRITICAL | Can't split without breaking circular chain |
| N+1 query | High-traffic endpoint (>10 callers or public API) | CRITICAL | Performance degradation at scale |
| Anemic domain model | Switch on type in service | HIGH | Behavior belongs on entity, switch = missing polymorphism |
| Layer violation | No interface on that dependency | HIGH | Tight coupling + wrong layer = unmockable + untestable |
| `return null` | No Optional usage in codebase | HIGH | Systemic NPE risk, no safety net |
| Redundant DB calls | Inside loop | CRITICAL | N×M DB calls per request |
| Missing pagination | No query limit in repository | CRITICAL | OOM risk on large datasets |

---

## Effort Estimation

| Effort | Time | Scope | Examples |
|--------|------|-------|----------|
| **S** | <2 hours | Single file, mechanical change | Add @Cacheable, extract method, replace null with Optional, add pagination param, fix log-and-throw |
| **M** | 2-8 hours | Multi-file, requires design thought | Extract class from God class cluster, introduce Strategy pattern (interface + 2-3 impls), add Builder, batch DB calls, add missing interface |
| **L** | 1-3 days | Cross-module, requires coordination | Split God class fully (5+ clusters), redesign layer structure, break circular dependency, convert anemic to rich domain model |

### Effort Modifiers

Increase effort by one level when any of these conditions apply. Modifiers stack — if 2+ conditions match, increase by 2 levels (capped at L):
- No test coverage exists for affected code
- Change touches >3 modules
- Debt item has >2 dependencies on other items
- Code is in a shared library used by other teams

### Category Assignment

Each debt item has ONE primary category. When a finding could belong to multiple categories, assign by this priority:
1. Architecture (layer violations, circular deps, god modules, shared mutable state)
2. Performance (N+1, redundant fetching, missing pagination, missing caching)
3. Design (missing patterns: Strategy, Builder, Facade, Rich Domain)
4. Code Smell (God class, long methods, boolean flags, null returns, copy-paste)

Secondary impacts go in the item's "Why it matters" description, not as a separate category.
