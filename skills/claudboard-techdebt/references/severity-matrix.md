# Severity Matrix & Effort Estimation

Use during Phase 2 to assign severity and effort to each debt item.

---

## Severity Rules

### Code Smells

| Signal | Severity |
|--------|----------|
| God class >500 LOC, no tests covering it | CRITICAL |
| God class >500 LOC, tests exist | HIGH |
| God class 300-500 LOC | MEDIUM |
| Long method >50 lines | MEDIUM |
| Long method 30-50 lines | LOW |
| Too many parameters >7 | MEDIUM |
| Too many parameters 4-7 | LOW |
| Boolean flag argument on public API | MEDIUM |
| Boolean flag on internal method | LOW |
| `return null` in service/repository layer | MEDIUM |
| Log-and-throw in same catch block | LOW |
| Copy-paste: same 5+ line block 3+ times | MEDIUM |
| Copy-paste: same block 5+ times | HIGH |
| Broad `catch(Exception)` that swallows | HIGH |
| Broad `catch(Exception)` that wraps/rethrows | LOW |
| Magic numbers in business logic | LOW |
| Star imports | LOW |

### Design Debt

| Signal | Severity |
|--------|----------|
| Switch >6 cases on type discriminator | HIGH |
| Switch 4-6 cases on type discriminator | MEDIUM |
| Instanceof chain >3 types | MEDIUM |
| Instanceof chain >6 types | HIGH |
| Sequential setters >8 (missing Builder) | MEDIUM |
| Sequential setters 5-8 | LOW |
| Constructor with >7 dependencies | MEDIUM |
| Anemic domain model (entity package, only getters/setters) | MEDIUM |
| Utility class with mutable state | MEDIUM |
| Manual object copy (field-by-field) >5 fields | MEDIUM |
| Nested callbacks >3 levels | MEDIUM |

### Performance Debt

| Signal | Severity |
|--------|----------|
| Same entity fetched >2x in one request path | HIGH |
| DB call inside loop body (N+1) | HIGH |
| Missing pagination on list endpoint returning unbounded results | HIGH |
| Missing @Cacheable on reference/config data queried per request | MEDIUM |
| Sequential independent service calls (parallelizable) | MEDIUM |
| String concatenation in loop (should be StringBuilder) | LOW |
| findAll() when filtered subset needed | MEDIUM |
| Eager loading of unused relations | MEDIUM |

### Architecture Debt

| Signal | Severity |
|--------|----------|
| Controller imports Repository directly (layer skip) | HIGH |
| Circular module dependency (A→B→A) | HIGH |
| God module >50 classes in one package | MEDIUM |
| Missing interface for external service call | MEDIUM |
| Dead endpoint (no route, no caller) | LOW |
| Business logic in controller | MEDIUM |
| DB/persistence logic in service (not repository) | MEDIUM |
| Validation logic in controller (should be service/domain) | LOW |
| Shared mutable state between services | HIGH |

---

## Compound Severity Rules

When two findings co-occur, escalate. Apply after individual scoring.

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

Increase effort by one level when:
- No test coverage exists for affected code
- Change touches >3 modules
- Debt item has >2 dependencies on other items
- Code is in a shared library used by other teams
