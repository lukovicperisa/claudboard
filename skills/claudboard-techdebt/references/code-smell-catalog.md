# Code Smell Catalog — Java/Spring Focus

Use during Phase 2 Pass 1. Extends `../claudboard/references/pattern-catalog.md` with deeper analysis heuristics.

**Severity source of truth:** Use `severity-matrix.md` for final severity assignment. Severity hints in this file are approximate guides — the matrix takes precedence.

---

## God Class Analysis

### Detection (Wide Scan)

```bash
# Files >300 LOC in production source
find . -name '*.java' -path '*/src/main/*' ! -path '*/test/*' \
  | xargs wc -l 2>/dev/null | sort -rn | head -20
```

Thresholds: >300 LOC = candidate, >500 LOC = strong candidate.

### Deep Analysis (read full file)

For each God class candidate, perform **responsibility clustering**:

1. **List all methods** with their line ranges
2. **For each method, note which fields/dependencies it uses** (which `this.xxxService` or `this.xxxRepository` calls)
3. **Group methods that share the same dependencies** — these form a responsibility cluster
4. **Name each cluster** based on the dominant concept (e.g., methods using `emailService` + `templateEngine` → "Notification")

**Cluster output format:**
```
ClassName.java (NNN LOC)
├── <cluster-name>    (lines X-Y, Z-W)  → SuggestedNewClass
│     Uses: dep1, dep2
│     Methods: method1(), method2(), method3()
├── <cluster-name>    (lines A-B)       → SuggestedNewClass
│     Uses: dep3
│     Methods: method4(), method5()
└── <cluster-name>    (lines C-D)       → SuggestedNewClass
      Uses: dep4, dep5, dep6
      Methods: method6(), method7(), method8(), method9()
```

### Naming Extracted Classes

When extracting a cluster from a God class:
- Name by `{CoreResponsibility}{Capability}` — e.g., methods using `emailService` + `templateEngine` → `NotificationService`
- If original class is `{Domain}Manager`, extracted class should be `{Domain}{Capability}Service`
- Avoid: `Helper`, `Util`, `Manager` (ambiguous and non-discoverable)

### Split Order

Suggest split order based on coupling:
1. **First to extract**: cluster with fewest inbound dependencies from other clusters (least entangled)
2. **Last to extract**: cluster that other clusters call into (most entangled, usually the "core" responsibility that should stay)

Note: if two clusters share a dependency, they may need to share an injected service — flag this as a consideration.

---

## Long Methods

### Detection

```bash
# Rough detection: count lines between method signature and closing brace
# More reliable: read sampled files and count method lengths manually
```

During strategic sampling, when reading a file:
- Count lines per method (signature to closing brace)
- Flag >30 lines as candidate, >50 as strong

### Analysis

For long methods, identify **natural break points**:
- Comment blocks that separate logical sections ("// validate input", "// process", "// save")
- Blank lines separating groups of statements
- Variable declarations that start a new "mini-scope"

Suggest extract-method targets: each break point → named method.

---

## Too Many Parameters

### Detection

```bash
# Methods with many params (rough)
grep -rn 'public.*(.*, .*, .*, .*, ' --include='*.java' src/main/
# Constructors with many params
grep -rn 'public.*Constructor\|public .*(.*@Autowired' --include='*.java' src/main/
```

### Analysis

- 4-7 params: suggest parameter object or builder
- >7 params: strong signal — likely a God class or wrong abstraction
- Constructor >7 params in `@Service`/`@Component`: class has too many responsibilities

---

## Boolean Flag Arguments

### Detection

```bash
# Method calls with literal true/false
grep -rn '(.*true.*,\|, true)\|(.*false.*,\|, false)' --include='*.java' src/main/ | head -20
# Method declarations with boolean params
grep -rn 'public.*boolean [a-z].*,' --include='*.java' src/main/
```

### Analysis

- Public API method with boolean param → suggest: separate methods or enum
- Internal method with boolean → lower severity, but still flag if meaning is unclear at call site

---

## Null Returns

### Detection

```bash
grep -rn 'return null;' --include='*.java' src/main/ | grep -v 'test'
```

### Analysis

- In service/repository layer → MEDIUM: should return `Optional<T>`
- In controller layer → check if intentional (204 No Content)
- Count total: if >10 null returns and zero Optional usage → systemic issue (HIGH compound)

---

## Log-and-Throw

### Detection

```bash
# log.error followed by throw within 3 lines
grep -B1 -A1 'throw ' --include='*.java' src/main/ | grep -B2 'log\.error\|logger\.error'
```

### Analysis

- Causes duplicate error reporting up the call stack
- Fix: either log (terminal handler) OR throw (let caller decide) — never both

---

## Copy-Paste Duplication

### Detection Strategy

1. During strategic sampling, identify distinctive code patterns (3-5 lines)
2. Grep for those patterns across the repo
3. If same pattern appears in 3+ files → copy-paste debt

**Common duplicate patterns in Spring:**
```bash
# Try-catch blocks with same structure
grep -A5 'try {' --include='*.java' src/main/ | head -50
# Similar CRUD methods across services
grep -rn 'public.*create\|public.*update\|public.*delete' --include='*.java' src/main/
```

### Analysis

- 3 occurrences: MEDIUM — extract to shared method/utility
- 5+ occurrences: HIGH — missing abstraction (base class, template method, or strategy)
- If duplication is across parallel class hierarchies: flag as "parallel hierarchy duplication"

---

## Broad Exception Catching

### Detection

```bash
# Broad catches
grep -rn 'catch (Exception \|catch (Throwable ' --include='*.java' src/main/
# Check if empty (swallow) or wrap-and-rethrow
grep -A3 'catch (Exception ' --include='*.java' src/main/ | grep -E '^\s*(//.*|})$'
```

### Analysis

- Empty catch (swallow): HIGH — bugs disappear silently
- Wrap-and-rethrow with generic RuntimeException: LOW — acceptable but could be more specific
- Catch-log-continue: MEDIUM — error state may propagate

---

## Magic Numbers

### Detection

```bash
# Numeric literals in business logic (exclude obvious 0, 1, -1)
grep -rn '[^0-9][2-9][0-9]*[^0-9]\|[^0-9][0-9][0-9][0-9]' --include='*.java' src/main/ | \
  grep -v 'import\|package\|//\|HttpStatus\|@' | head -20
```

### Analysis

- In business logic (service/domain layer): flag as constant extraction candidate
- In config/properties: acceptable
- Named constant nearby but not used: flag inconsistency
