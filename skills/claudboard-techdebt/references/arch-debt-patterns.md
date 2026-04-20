# Architecture Debt Patterns — Java/Spring

Use during Phase 2 Pass 4. Cross-module and cross-layer analysis.

---

## Layer Violations

### Detection

```bash
# Controller importing Repository directly (skipping service layer)
grep -rn 'import.*repository\.\|import.*Repository;' --include='*.java' src/main/ | \
  grep -i 'controller\|Controller' | head -10

# Controller importing entity/model directly (should use DTO)
grep -rn 'import.*model\.\|import.*entity\.' --include='*.java' src/main/ | \
  grep -i 'controller\|Controller' | head -10

# Service importing controller (reverse dependency)
grep -rn 'import.*controller\.\|import.*Controller;' --include='*.java' src/main/ | \
  grep -i 'service\|Service' | head -10
```

### Expected Layer Order

```
Controller → Service → Repository
     ↓           ↓          ↓
    DTO      Domain     Entity/DB

Violations:
  Controller → Repository  (skips service)
  Service → Controller     (reverse)
  Repository → Service     (reverse)
  Controller uses Entity   (should use DTO)
```

### Confirm

Read the import section of flagged files. Check if:
- Controller directly calls repository methods (not through a service)
- Controller returns domain entities instead of DTOs
- Any upward dependency (lower layer importing higher)

### Suggest

```
**Current:** `{Controller}` imports `{Repository}` directly.
  Methods affected: {list methods using repository}

**Fix:** Introduce/use service layer:
  {Controller}.{method}() → {Service}.{method}() → {Repository}.{method}()

  Create `{ServiceClass}` if it doesn't exist, or move logic to existing service.

**Why:** Testability (mock service, not repository), reusability
  (other callers can use same service), separation of concerns.

**Effort:** M
```

---

## Circular Dependencies

### Detection

```bash
# Build import graph: for each Java file, list what it imports from src/main
# Step 1: list all packages
find src/main -name '*.java' -exec grep -l 'package ' {} \; | \
  xargs grep 'package ' | sed 's/.*package //;s/;.*//' | sort -u

# Step 2: for each package, what other packages does it import?
for pkg in $(find src/main -name '*.java' -exec grep -h 'package ' {} \; | \
  sed 's/package //;s/;.*//' | sort -u); do
  dir=$(echo $pkg | tr '.' '/')
  imports=$(grep -rh 'import ' src/main/java/$dir/ 2>/dev/null | \
    sed 's/import //;s/;.*//' | grep -v 'java\.\|javax\.\|org\.\|com\.fasterxml\|lombok' | \
    sed 's/\.[A-Z][^.]*$//' | sort -u)
  for imp in $imports; do
    echo "$pkg → $imp"
  done
done | sort -u
# Look for A→B and B→A pairs
```

### Simplified Detection (for common cases)

```bash
# Check if serviceA imports serviceB AND serviceB imports serviceA
# Focus on service-level circulars (most common)
for f in $(find src/main -name '*Service.java' -o -name '*ServiceImpl.java'); do
  class=$(basename $f .java)
  imports=$(grep 'import ' $f | grep -i 'service\|Service' | sed 's/import //;s/;.*//')
  for imp in $imports; do
    imp_file=$(echo $imp | tr '.' '/' | sed 's|$|.java|')
    if grep -q "import.*$(echo $class | sed 's/Impl//')" src/main/java/$imp_file 2>/dev/null; then
      echo "CIRCULAR: $class ↔ $(basename $imp_file .java)"
    fi
  done
done
```

### Suggest

```
**Current:** Circular dependency: `{ClassA}` ↔ `{ClassB}`
  {ClassA} imports {ClassB} for: {methods used}
  {ClassB} imports {ClassA} for: {methods used}

**Fix options:**
  1. **Extract interface:** Create `{InterfaceName}` for the smaller
     dependency surface. One side depends on interface, not implementation.

  2. **Extract shared service:** If both need same logic, extract to
     `{SharedService}` that both depend on (dependency inversion).

  3. **Event-based:** If one side only notifies the other,
     use Spring ApplicationEvent to decouple.

  Recommended: {option N} because {reason based on usage analysis}.

**Effort:** M-L
```

---

## God Modules

### Detection

```bash
# Count classes per package
find src/main -name '*.java' | \
  xargs grep -h 'package ' | sed 's/package //;s/;.*//' | \
  sort | uniq -c | sort -rn | head -10
# >50 classes in one package = God module
# >30 classes = candidate
```

### Confirm

- Package has >50 classes
- Classes serve different concerns (mix of controllers, services, entities, utilities)
- OR: package has >30 classes that should be sub-packaged by domain concept

### Suggest

```
**Current:** Package `{package}` has {N} classes.
  Detected concerns:
  - {concept1}: {list of classes}
  - {concept2}: {list of classes}
  - {concept3}: {list of classes}

**Fix:** Split into sub-packages:
  {package}.{concept1}/
  {package}.{concept2}/
  {package}.{concept3}/

**Effort:** M (move files + update imports)
```

---

## Missing Abstraction for External Service

### Detection

```bash
# Direct HTTP client usage in service layer
grep -rn 'RestTemplate\|WebClient\|HttpClient\|FeignClient\|OkHttp' \
  --include='*.java' src/main/ | grep -i 'service\|Service' | head -10

# Direct DB driver usage outside repository layer
grep -rn 'MongoTemplate\|JdbcTemplate\|EntityManager' \
  --include='*.java' src/main/ | grep -iv 'repository\|Repository\|config\|Config' | head -10
```

### Confirm

- Service class directly uses HTTP client / DB template (no interface)
- Makes unit testing impossible without mocking framework internals
- If external service changes API, multiple files need updating

### Suggest

```
**Current:** `{ServiceClass}` directly uses `{Client}` for {purpose}.
  No interface — can't mock, can't swap implementation.

**Fix:**
  interface {ExternalService}Gateway {
      {ReturnType} {method}({params});
  }

  @Component
  class {ExternalService}GatewayImpl implements {ExternalService}Gateway {
      private final {Client} client;
      // wraps actual HTTP/DB calls
  }

  // {ServiceClass} injects {ExternalService}Gateway instead of {Client}

**Effort:** M
```

---

## Dead Code

### Detection

```bash
# Controller methods — check if any endpoint has zero callers
# (hard to detect via static analysis alone, but can flag suspects)

# Unused service methods (grep for method name across codebase)
# For each public method in service classes:
for f in $(find src/main -name '*Service.java' -name '*ServiceImpl.java'); do
  grep -oP 'public \S+ (\w+)\(' $f | grep -oP '\w+(?=\()' | while read method; do
    count=$(grep -r "$method" --include='*.java' src/ | grep -v "$(basename $f)" | wc -l)
    if [ "$count" -eq 0 ]; then
      echo "UNUSED: $f → $method()"
    fi
  done
done
# Note: may have false positives (reflection, interface contracts)

# Unused imports
grep -rn '^import ' --include='*.java' src/main/ | \
  while IFS=: read file line import; do
    class=$(echo $import | sed 's/.*\.\([A-Z][^;]*\);/\1/')
    if ! grep -q "$class" "$file" 2>/dev/null | grep -v "^import"; then
      echo "UNUSED IMPORT: $file:$line"
    fi
  done
```

### Suggest

```
**Current:** `{ClassName}.{method}()` appears to have zero callers.

**Verify:** Check for:
  - Reflection-based invocation
  - Interface contract (method required by interface)
  - Scheduled/async invocation (@Scheduled, @Async)
  - External API consumers

**If confirmed dead:** Remove method. If entire class is dead, remove class.

**Effort:** S (per method/class, after verification)
```

---

## Wrong-Layer Responsibility

### Detection

```bash
# Validation in controller (should be in service/domain)
grep -rn 'if.*==.*null\|if.*\.isEmpty\|if.*\.length\|throw.*Validation\|throw.*IllegalArgument' \
  --include='*.java' src/main/ | grep -i 'controller\|Controller' | head -10

# Business logic in controller (complex branching)
grep -A10 '@PostMapping\|@PutMapping\|@DeleteMapping' --include='*.java' src/main/ | \
  grep 'if.*else\|switch\|for (' | head -10

# DB/persistence logic in service (should be in repository)
grep -rn 'MongoTemplate\|JdbcTemplate\|EntityManager\|createQuery\|nativeQuery' \
  --include='*.java' src/main/ | grep -iv 'repository\|Repository\|config' | head -10
```

### Confirm

Read the flagged method. Check if:
- Controller has >5 lines of logic beyond "call service, return response"
- Service builds queries or uses persistence API directly
- Validation logic duplicated between controller and service

### Suggest

```
**Current:** {wrong layer responsibility description}
  `{ClassName}.{method}()` — lines X-Y

**Expected location:** {correct layer and class}

**Fix:** Move logic from `{ClassName}` to `{TargetClass}`.
  {ClassName}.{method}() should only: {what it should do}

**Effort:** S-M
```

---

## Shared Mutable State

### Detection

```bash
# Static mutable fields (not final, not constant)
grep -rn 'static [^f].*=\|static .*List\|static .*Map\|static .*Set' \
  --include='*.java' src/main/ | grep -v 'final\|CONSTANT\|LOG\|log\|test' | head -10

# Non-thread-safe shared state
grep -rn 'static.*HashMap\|static.*ArrayList\|static.*HashSet' \
  --include='*.java' src/main/ | head -10
```

### Confirm

- Static mutable field in a Spring bean (singleton by default)
- Modified by request-handling code → thread-safety issue
- Or: instance field on `@Service`/`@Component` (Spring singleton) that's written to

### Suggest

```
**Current:** Mutable shared state in `{ClassName}.{field}` (line X)
  Type: {static HashMap / instance List / etc.}
  Modified by: {list of methods}

**Risk:** Thread-safety issue in Spring singleton. Concurrent requests
  can corrupt state or see stale data.

**Fix options:**
  1. Make immutable (if data is static): `private static final Map<...> = Map.of(...)`
  2. Use ConcurrentHashMap / CopyOnWriteArrayList (if must be mutable)
  3. Move to request scope (@RequestScope) or method-local variable
  4. Use proper caching (@Cacheable) if this is a cache attempt

**Effort:** S-M depending on usage
```
