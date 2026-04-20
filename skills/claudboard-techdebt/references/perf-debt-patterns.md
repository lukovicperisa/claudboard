# Performance Debt Patterns — Java/Spring

Use during Phase 2 Pass 3. For each pattern: grep to find candidates, call-path tracing to confirm, fix suggestion.

---

## Redundant Entity Fetching

### Grep for Candidates

```bash
# Repository findById / getById / findOne calls
grep -rn 'findById\|getById\|findOne\|getOne\|getReferenceById' \
  --include='*.java' src/main/ | grep -v test
# Group by file to spot multiples in same service
grep -rn 'findById\|getById' --include='*.java' src/main/ | \
  awk -F: '{print $1}' | sort | uniq -c | sort -rn | head -10
```

### Call-Path Tracing

For each service with >1 findById call for same repository:
1. Read the service class fully
2. Trace public method → private helpers
3. Check if same entity ID flows through multiple methods that each call `repo.findById(id)`
4. Check controller → service path: does controller fetch entity, then service fetches again?

**Common patterns:**
- `controller.update(id)` → calls `service.validate(id)` (fetches entity) + `service.save(id)` (fetches entity again)
- `service.process(id)` → calls `validator.check(id)` (fetches) + `enricher.enrich(id)` (fetches) + `persister.save(id)` (fetches)

### Suggest

```
**Current:** `{Repository}.findById({id})` called {N}x in request path:
  1. {ClassName1}.{method1}() — line X
  2. {ClassName2}.{method2}() — line Y
  3. {ClassName3}.{method3}() — line Z

**Fix:** Fetch once at entry point (`{ClassName1}.{method1}()`),
  pass entity object through:
  - {method2}({Entity} entity) instead of {method2}({IdType} id)
  - {method3}({Entity} entity) instead of {method3}({IdType} id)

**Impact:** {N-1} unnecessary DB roundtrips per {operation} request.
```

---

## N+1 Query (DB Call in Loop)

### Grep for Candidates

```bash
# Loop patterns near repository calls
grep -B5 'findById\|findBy\|getBy\|repository\.' --include='*.java' src/main/ | \
  grep -E 'for\s*\(|\.forEach|\.stream\(\)|\.map\(' | head -20

# Or: find forEach/stream followed by repo call within 5 lines
grep -A5 '\.forEach\|\.stream()\|for (' --include='*.java' src/main/ | \
  grep 'Repository\.\|repository\.\|Service\.\|service\.' | head -20
```

### Confirm

Read the method body. Look for:
```java
// Pattern 1: explicit loop
for (Long id : ids) {
    Entity entity = repository.findById(id).orElseThrow(); // N calls!
}

// Pattern 2: stream
ids.stream()
    .map(id -> repository.findById(id).orElseThrow()) // N calls!
    .collect(toList());

// Pattern 3: indirect via service call in loop
for (Item item : items) {
    enrichService.enrich(item); // enrich() internally calls DB
}
```

### Suggest

```
**Current:** `{Repository}.{method}()` called inside loop in
  `{ClassName}.{method}()` (line X)
  Loop iterates over {collection} — {N} DB calls per invocation.

**Fix — Batch:**
  // Before:
  for (Long id : ids) { repo.findById(id)... }

  // After:
  List<Entity> entities = repo.findAllById(ids);  // 1 DB call
  Map<Long, Entity> entityMap = entities.stream()
      .collect(toMap(Entity::getId, identity()));

**Fix — @Query:**
  @Query("SELECT e FROM Entity e WHERE e.id IN :ids")
  List<Entity> findByIds(@Param("ids") Collection<Long> ids);

**Impact:** Reduces {N} DB calls to 1 per {operation}.
```

---

## Missing @Cacheable on Reference Data

### Grep for Candidates

```bash
# Methods that look up config/reference/static data
grep -rn 'findBy\|getBy\|findAll' --include='*.java' src/main/ | \
  grep -i 'config\|setting\|reference\|lookup\|parameter\|constant\|catalog\|category\|type' | \
  grep -v '@Cacheable\|test'

# Check if @Cacheable is used anywhere (indicates caching is set up)
grep -rn '@Cacheable\|@CacheEvict\|@CachePut' --include='*.java' src/main/
```

### Confirm

- Method returns data that changes rarely (configuration, reference tables, lookup values)
- Method is called frequently (from request-handling path)
- No `@Cacheable` annotation on the method
- Caching infrastructure exists in project (Spring Cache dependency present) OR should be added

### Suggest

```
**Current:** `{ClassName}.{method}()` queries {table/collection} on every call.
  Data changes: {rarely/on deploy/on admin action}.
  Called from: {list of callers or "every request"}.

**Fix:**
  @Cacheable(value = "{cacheName}", key = "#param")
  public {ReturnType} {method}({params}) { ... }

  // Add @CacheEvict where data is modified:
  @CacheEvict(value = "{cacheName}", allEntries = true)
  public void update{Entity}(...) { ... }

**Impact:** Eliminates {frequency} DB queries for static data.

**Prerequisite:** spring-boot-starter-cache dependency + @EnableCaching
```

---

## Missing Pagination

### Grep for Candidates

```bash
# Controller endpoints returning List (not Page)
grep -rn 'public.*List<\|public.*Collection<\|ResponseEntity<List' \
  --include='*.java' src/main/ | grep -i 'controller\|Controller' | head -20

# Repository methods returning List without Pageable
grep -rn 'List<.*findAll\|List<.*findBy' --include='*.java' src/main/ | \
  grep -v 'Pageable\|Page<' | head -10

# Check if Pageable is used anywhere
grep -rn 'Pageable\|Page<\|PageRequest' --include='*.java' src/main/
```

### Confirm

- Endpoint returns `List<T>` with no size limit
- Underlying query has no `LIMIT` or `Pageable` parameter
- Table/collection could grow unbounded
- Not a lookup endpoint returning a fixed small set

### Suggest

```
**Current:** `{Controller}.{method}()` returns unbounded `List<{Entity}>`.
  Repository: `{Repository}.findAll()` — no pagination.

**Fix:**
  // Controller:
  @GetMapping
  public Page<{Entity}Response> list(Pageable pageable) {
      return service.findAll(pageable).map(mapper::toResponse);
  }

  // Repository:
  Page<{Entity}> findAll(Pageable pageable);  // Spring Data handles it

  // Default page size via config:
  spring.data.web.pageable.default-page-size=20
  spring.data.web.pageable.max-page-size=100

**Impact:** Prevents OOM on large datasets. Current risk:
  {estimated table size or "unknown"} rows loaded into memory.
```

---

## Sequential Independent Calls (Parallelizable)

### Grep for Candidates

```bash
# Multiple service calls in sequence (look for 3+ service.method() calls)
grep -rn 'Service\.\|service\.' --include='*.java' src/main/ | \
  awk -F: '{print $1}' | sort | uniq -c | sort -rn | head -10
```

### Confirm

Read method body. Look for:
```java
// Sequential calls with no data dependency between them:
Result a = serviceA.getData(id);      // line 10
Result b = serviceB.getOtherData(id); // line 11 — doesn't use 'a'
Result c = serviceC.getMoreData(id);  // line 12 — doesn't use 'a' or 'b'
// Then combines: return merge(a, b, c);
```

Key: calls are **independent** (no data flows from one to the next).

### Suggest

```
**Current:** {N} independent service calls executed sequentially in
  `{ClassName}.{method}()` (lines X-Z). Each call takes ~{estimated}ms.

**Fix — CompletableFuture:**
  CompletableFuture<ResultA> futureA = CompletableFuture.supplyAsync(
      () -> serviceA.getData(id), executor);
  CompletableFuture<ResultB> futureB = CompletableFuture.supplyAsync(
      () -> serviceB.getOtherData(id), executor);

  CompletableFuture.allOf(futureA, futureB).join();
  return merge(futureA.get(), futureB.get());

**Impact:** Latency reduced from sum({N} calls) to max(single call).
  Estimated: ~{N}x → ~1x for these calls.
```

---

## Eager Loading When Lazy Needed

### Grep for Candidates

```bash
# findAll() usage in services
grep -rn '\.findAll()' --include='*.java' src/main/ | grep -v test
# Check if result is filtered afterwards
grep -A5 '\.findAll()' --include='*.java' src/main/ | grep '\.filter\|\.stream\|if ('
```

### Confirm

- `repository.findAll()` loads everything, then Java code filters
- Could be a `findByXxx()` query instead
- Table has >100 rows (or could grow to that)

### Suggest

```
**Current:** `{Repository}.findAll()` in `{ClassName}.{method}()` (line X),
  followed by `.stream().filter(...)` on line Y.

**Fix:** Push filter to query:
  // Instead of: repo.findAll().stream().filter(e -> e.getStatus() == ACTIVE)
  // Use:        repo.findByStatus(Status.ACTIVE)

  // Repository:
  List<{Entity}> findByStatus(Status status);

**Impact:** Loads {subset description} instead of entire table.
```

---

## String Concatenation in Loop

### Grep for Candidates

```bash
# String concat with + in loops
grep -B3 '\".*\" +\|+ \"' --include='*.java' src/main/ | \
  grep -B3 'for (\|while (\|\.forEach' | head -10
```

### Confirm

- String `+` or `+=` inside loop body
- Result is a growing string (log message, SQL builder, report)

### Suggest

```
**Current:** String concatenation in loop at `{ClassName}.{method}()` (line X)

**Fix:**
  StringBuilder sb = new StringBuilder();
  for (...) {
      sb.append(...);
  }
  String result = sb.toString();

**Impact:** O(n) instead of O(n²) memory allocation for {N} iterations.

**Effort:** S
```
