# Design Debt Patterns — Java/Spring

Use during Phase 2 Pass 2. For each pattern: what to grep (candidates), what to confirm (read file), what to suggest (fix sketch).

---

## Strategy Pattern — Missing

### Grep for Candidates

```bash
# Switch statements in service/domain layer
grep -rn 'switch\s*(' --include='*.java' src/main/ | grep -v 'test\|config\|Config'
# Long if-else chains on same variable
grep -rn 'else if\s*(' --include='*.java' src/main/ | grep -v 'test'
# Enum-based dispatch
grep -rn '\.ordinal()\|\.name()\|\.toString()' --include='*.java' src/main/ | grep 'switch\|case\|if'
```

### Confirm (read method body)

- Switch/if-else on a **type discriminator** (enum, string type, class type)
- >3 cases that each perform distinct business logic (not simple mapping)
- Cases contain >5 lines each (not trivial returns)
- New types would require modifying this switch → OCP violation

**Not a pattern candidate if:**
- Simple value mapping (enum → string) — a Map or enum method suffices
- Error code handling — switch on error type is often fine
- <4 cases with trivial logic

### Suggest

```
**Pattern:** Strategy

**Current:** switch on `{field}` in `{ClassName}.{method}()` ({N} cases, lines X-Y)

**Suggested:**
  interface {Concept}Strategy {
      Result {action}(Input input);
  }

  class {TypeA}Strategy implements {Concept}Strategy { ... }
  class {TypeB}Strategy implements {Concept}Strategy { ... }
  class {TypeC}Strategy implements {Concept}Strategy { ... }

  // In {ClassName}:
  private final Map<{EnumType}, {Concept}Strategy> strategies;
  // Constructor-injected via Spring, or populated in @Configuration

**Effort:** M (interface + N impl classes + wiring)
```

---

## State Pattern — Missing

### Grep for Candidates

```bash
# Methods checking status/state field repeatedly
grep -rn 'if.*status\|if.*state\|if.*phase' --include='*.java' src/main/ | grep -v test
# Enum fields named status/state
grep -rn 'Status\|State.*enum\|enum.*Status\|enum.*State' --include='*.java' src/main/
```

### Confirm

- Multiple methods in same class check the same state/status field
- Each method has different behavior per state value
- State transitions are scattered (not centralized)

### Suggest

```
**Pattern:** State

**Current:** {N} methods check `{field}` in `{ClassName}` with if/switch

**Suggested:**
  interface {Entity}State {
      void {action1}({Entity} context);
      void {action2}({Entity} context);
  }

  class {StateA} implements {Entity}State { ... }
  class {StateB} implements {Entity}State { ... }

  // {Entity} delegates to current state:
  private {Entity}State currentState;
  public void {action1}() { currentState.{action1}(this); }
```

---

## Builder Pattern — Missing

### Grep for Candidates

```bash
# Sequential setter calls (>5 on same object)
grep -rn '\.set[A-Z]' --include='*.java' src/main/ | \
  awk -F: '{print $1}' | sort | uniq -c | sort -rn | head -10
# Constructor calls with many args
grep -rn 'new [A-Z][a-zA-Z]*(' --include='*.java' src/main/ | grep '.*,.*,.*,.*,' | head -10
```

### Confirm

- >5 sequential `.setXxx()` calls on same object in one method
- OR constructor call with >5 arguments
- Object is a DTO, entity, or config object (not a framework object)
- Same construction pattern repeated in multiple places

### Suggest

```
**Pattern:** Builder

**Current:** {N} sequential setters on `{ClassName}` in `{Location}`
  (also found in: {other locations if repeated})

**Suggested:**
  // If using Lombok:
  @Builder on {ClassName}

  // If no Lombok:
  {ClassName}.builder()
      .{field1}(value1)
      .{field2}(value2)
      .build();

**Effort:** S (with Lombok) / M (manual builder)
```

---

## Facade Pattern — Missing

### Grep for Candidates

```bash
# Classes with many constructor dependencies
grep -rn 'private final' --include='*.java' src/main/ | \
  awk -F: '{print $1}' | sort | uniq -c | sort -rn | head -10
# Filter to >5 deps
```

### Confirm

- Service class with >5 injected dependencies
- Some dependencies are only used in 1-2 methods (not all methods need all deps)
- Dependencies cluster into groups (some always used together)

### Suggest

```
**Pattern:** Facade (or split class)

**Current:** `{ClassName}` has {N} dependencies

**Dependency clusters:**
  Cluster A: dep1, dep2 — used by method1(), method2()
  Cluster B: dep3, dep4, dep5 — used by method3()
  Cluster C: dep6, dep7 — used by method4(), method5()

**Option 1 — Split:** Extract clusters into separate services
**Option 2 — Facade:** If orchestration is the purpose, keep but ensure each dep is essential

**Effort:** M-L depending on entanglement
```

---

## Polymorphism — Missing (Instanceof Chains)

### Grep for Candidates

```bash
grep -rn 'instanceof' --include='*.java' src/main/ | grep -v test
```

### Confirm

- >3 `instanceof` checks in same method/block
- Checks are on a shared interface or base class
- Each branch performs distinct logic

### Suggest

```
**Pattern:** Polymorphism (move behavior to subtypes)

**Current:** {N} instanceof checks in `{ClassName}.{method}()` (lines X-Y)
  Checks: {Type1}, {Type2}, {Type3}, ...

**Suggested:**
  // Add method to base type/interface:
  interface {BaseType} {
      Result {action}();  // each subtype implements its own logic
  }

  // In {ClassName}:
  // Replace: if (x instanceof TypeA) { ... } else if ...
  // With:    x.{action}();

**Effort:** M (add method to interface + N implementations)
```

---

## Rich Domain Model — Anemic Model Detected

### Grep for Candidates

```bash
# Classes in model/entity/domain package with only getters/setters
grep -rl 'class.*{' --include='*.java' src/main/ | xargs grep -lP 'get[A-Z]|set[A-Z]' | \
  xargs grep -L 'public.*void [a-z].*(\|public.*[A-Z].*[a-z].*(' 2>/dev/null | head -10
# Check for @Entity/@Document classes
grep -rl '@Entity\|@Document' --include='*.java' src/main/
```

### Confirm

- Domain/model class has only:
  - Fields
  - Getters/setters (or Lombok @Data/@Getter/@Setter)
  - No business methods (no verbs like `validate()`, `activate()`, `calculateTotal()`)
- Business logic for that entity lives in a service class instead

### Suggest

```
**Pattern:** Rich Domain Model

**Current:** `{Entity}` is anemic — {N} fields, only getters/setters
  Business logic lives in `{ServiceClass}` methods:
  - {service}.validate{Entity}() → should be {entity}.validate()
  - {service}.calculate{Thing}() → should be {entity}.calculate{Thing}()
  - {service}.{action}() → should be {entity}.{action}()

**Suggested:** Move behavior that depends only on entity's own fields
  into the entity class. Keep orchestration (multi-entity, external calls)
  in the service.

**Effort:** M per entity (identify methods, move, update callers)
```

---

## Observer Pattern — Missing (Nested Callbacks)

### Grep for Candidates

```bash
# Nested listener/callback patterns
grep -rn 'addListener\|addEventListener\|onSuccess\|onFailure\|onComplete' \
  --include='*.java' src/main/ | grep -v test
# Deeply nested lambdas
grep -rn '-> {' --include='*.java' src/main/ | \
  awk -F: '{print $1}' | sort | uniq -c | sort -rn | head -10
```

### Confirm

- >3 levels of callback nesting in one method
- Or: multiple places registering callbacks for same event type
- Tight coupling: caller knows about all listeners

### Suggest

```
**Pattern:** Observer / Event-Driven

**Current:** {N}-level nested callbacks in `{ClassName}.{method}()`

**Suggested:**
  // Spring ApplicationEvent approach:
  class {Event}Event extends ApplicationEvent { ... }

  @EventListener
  public void on{Event}({Event}Event event) { ... }

  // Publisher:
  applicationEventPublisher.publishEvent(new {Event}Event(...));

**Effort:** M (event class + listener + publisher wiring)
```

---

## Factory Pattern — Missing (Manual Construction)

### Grep for Candidates

```bash
# Complex new expressions with many args
grep -rn 'new [A-Z][a-zA-Z]*(' --include='*.java' src/main/ | grep '.*,.*,.*,' | head -20
# Same class constructed in multiple places
grep -rn 'new [A-Z]' --include='*.java' src/main/ | \
  sed 's/.*new \([A-Z][a-zA-Z]*\).*/\1/' | sort | uniq -c | sort -rn | head -10
```

### Confirm

- Same class instantiated in >3 places with >3 constructor args
- Construction logic includes conditional setup (different params per context)
- OR: `new` used for polymorphic types (should use factory to decide which subtype)

### Suggest

```
**Pattern:** Factory

**Current:** `new {ClassName}(...)` appears in {N} places with {M} args

**Suggested:**
  @Component
  class {ClassName}Factory {
      {ClassName} create({minimalParams}) { ... }
      {ClassName} createFor{Context}({contextParams}) { ... }
  }

**Effort:** S-M (factory class + update call sites)
```
