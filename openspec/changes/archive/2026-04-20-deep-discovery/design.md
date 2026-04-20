# Design: Two-Layer Discovery

## Architecture Change

Current Phase 1 flow:
```
1a. Parallel file detection (build files, CI, Docker)
1b. Structure mapping (dirs, monorepo check)
1c. Source sampling (3-5 random files per language)  ← PROBLEM
1d. Test strategy detection
1e. Call-path tracing (1 path)                       ← PROBLEM
1f. Duplication detection
1g. Existing .claude/ inventory
```

New Phase 1 flow:
```
1a. Parallel file detection (unchanged)
1b. Structure mapping (unchanged)
1c. WIDE SCAN (NEW) ← grep-based inventory, zero full-file reads
1d. STRATEGIC SAMPLING (CHANGED) ← picks files based on 1c results
1e. Test strategy detection (unchanged)
1f. Call-path tracing (CHANGED) ← 3-5 paths, not 1
1g. Duplication detection (unchanged)
1h. Existing .claude/ inventory (unchanged)
```

## Step 1c: Wide Scan

### Purpose
Build a complete inventory of patterns, anti-patterns, and skill trigger signals across the entire repo using only grep/find (no full file reads). Fast, cheap, comprehensive.

### Scan Categories

**Category 1: Inheritance & Abstraction Map**
```bash
# Custom annotations (project-specific patterns)
grep -rn '@interface' --include='*.java' src/

# Abstract base classes
grep -rn 'abstract class' --include='*.java' src/

# Inheritance usage (who extends what)
grep -rn 'extends ' --include='*.java' src/

# Interface declarations
grep -rn 'public interface' --include='*.java' src/

# TypeScript/Python equivalents
grep -rn 'abstract class\|extends ' --include='*.ts' src/
grep -rn 'class.*ABC\|class.*Protocol' --include='*.py' src/
```

**Decision:** If N classes extend the same base class (N >= 3), that base class is a **skill candidate**. If a custom annotation appears on 3+ classes, it's a **rule candidate**.

**Category 2: Skill Trigger Signals**
Existing 13 triggers from quality-signals.md, PLUS new triggers:

| Signal | Grep Pattern | Skill |
|--------|-------------|-------|
| Scheduled tasks | `@Scheduled`, `@EnableScheduling` | `scheduled-task` |
| WebSocket | `@MessageMapping`, `WebSocketHandler` | `websocket-handler` |
| GraphQL | `@QueryMapping`, `@MutationMapping` | `graphql-resolver` |
| CLI commands | `@Command`, `@ShellComponent` | `cli-command` |
| DB migrations | `flyway`, `liquibase`, `V\d+__` | `db-migration` |
| Security config | `SecurityFilterChain`, `@EnableMethodSecurity` | `security-config` |
| Background jobs | `@Async`, `@EnableAsync`, `CompletableFuture` | `async-task` |
| Event listeners | `@EventListener`, `ApplicationEvent` | `event-handler` |
| Feign clients | `@FeignClient` | `feign-client` |
| Custom validators | `implements Validator`, `ConstraintValidator` | `validator` |
| AOP aspects | `@Aspect`, `@Around`, `@Before` | `aspect` |

Run ALL trigger greps in parallel. Record: trigger name, file count, file list.

**Category 3: Anti-Pattern Signals**
```bash
# God class candidates (files > 300 LOC)
find . -name '*.java' -path '*/src/main/*' -exec wc -l {} + | sort -rn | head -30

# Field injection
grep -rc '@Autowired' --include='*.java' src/main/ | grep -v ':0$'

# Broad exception catching
grep -rn 'catch (Exception\|catch (Throwable' --include='*.java' src/

# Null returns
grep -rn 'return null' --include='*.java' src/main/

# Legacy date usage
grep -rl 'import java.util.Date' --include='*.java' src/

# Console logging in production
grep -rn 'System.out.print\|System.err.print' --include='*.java' src/main/

# Star imports
grep -rn 'import .*\.\*;' --include='*.java' src/

# TODO/FIXME/HACK count
grep -rc 'TODO\|FIXME\|HACK' --include='*.java' src/ | grep -v ':0$'

# Reflection in business logic
grep -rn 'ReflectionUtils\|getDeclaredField\|getMethod\|setAccessible' --include='*.java' src/main/
```

**Category 4: Convention Frequency Analysis**
```bash
# DI style ratio
FIELD_INJ=$(grep -rc '@Autowired' --include='*.java' src/main/ | awk -F: '{s+=$2}END{print s}')
CONST_INJ=$(grep -rc 'private final' --include='*.java' src/main/ | awk -F: '{s+=$2}END{print s}')

# Logging style
grep -rn 'LoggerFactory.getLogger\|@Slf4j\|@Log4j' --include='*.java' src/ | head -5

# Test naming pattern
ls src/test/**/*Test.java src/test/**/*Spec.groovy 2>/dev/null | head -10
```

### Output Format

Wide scan produces a **Pattern Inventory** (internal, not shown to user):

```yaml
inheritance_map:
  - base: AbstractDataEntity
    extends_count: 43
    sample_files: [Project.java, Canvas.java, Sketch.java]
  - base: LeafCrudService
    extends_count: 5
    sample_files: [NoteService.java, SketchService.java]

custom_annotations:
  - name: "@Cascade"
    usage_count: 12
    files: [Project.java, Canvas.java, ...]
  - name: "@Authorize"
    usage_count: 14
    files: [ProjectController.java, ...]

skill_triggers:
  - trigger: "@RestController"
    count: 14
    best_example: ProjectController.java (smallest, cleanest)
  - trigger: "@FeignClient"
    count: 2
    files: [UserAccountsClient.java, SubscriptionsClient.java]
  - trigger: "@Async"
    count: 1
    files: [UserResourceUsageAsyncRecalculator.java]

anti_patterns:
  - type: god_class
    files: [{name: CanvasService.java, loc: 609}, {name: ProjectService.java, loc: 407}]
  - type: reflection_in_business
    count: 8
    files: [CascadeSaveCallback.java, CascadeDeleteCallback.java, ...]
  - type: legacy_date
    count: 20+
    files: [AbstractDataEntity.java, ...]

conventions:
  di_style: "constructor-only (0 @Autowired, 45+ private final)"
  logging: "LoggerFactory.getLogger (no @Slf4j)"
  test_naming: "*Test.java, *IntegrationTest.java"
```

## Step 1d: Strategic Sampling (replaces old 1c)

### File Selection Algorithm

From the Pattern Inventory, select files to read fully:

1. **Base classes** (all, typically 3-8 files): Every abstract class with 3+ subclasses
2. **Custom annotations** (all declarations): Every `@interface` file
3. **God class candidates** (top 3 by LOC): Confirm anti-pattern, understand scope
4. **Best example per skill trigger** (1 per trigger): Smallest, cleanest file with that trigger — becomes the template for generated skills
5. **Hotspot files** (top 3 most recently changed, from `git log --since=3months --name-only`): Active code = important code

### Max Files

- Small repo (<50 files): Read all source files (no sampling needed)
- Medium repo (50-200): Read up to 25 files (strategic selection)
- Large repo (200-500): Read up to 20 files (strategic selection)
- Very large (500+): Read up to 15 files (strict prioritization)

This is MORE files than current (3-5) but LESS than reading everything, and each file is chosen for a reason.

## Step 1f: Enhanced Call-Path Tracing

### Selection Strategy

Pick 3-5 call paths based on what Wide Scan revealed:

| Path Type | Selection | What It Reveals |
|-----------|-----------|-----------------|
| Simple CRUD | Smallest controller → service → repo | Happy path, base patterns |
| Complex business | Largest service method (from God class scan) | Real complexity, edge cases |
| Async/event | File with @Async or @EventListener (if found) | Async patterns, error handling |
| Auth flow | Controller with @Authorize → aspect → validation | Security patterns |
| External integration | Feign client call chain (if found) | Error handling, resilience |

### Trace Depth

For each path, read 3-4 files in the chain. Record:
- DI pattern used
- Exception handling approach
- Logging pattern
- Validation approach
- Any reflection or runtime type manipulation

## Impact on Downstream Phases

### Phase 2 (Analysis Report)

New sections enabled by Wide Scan:

- **Inheritance Map**: Show base class hierarchy with subclass counts
- **Custom Pattern Catalog**: List project-specific annotations and their purpose
- **Anti-Pattern Inventory**: Counts across whole repo, not just sampled files
- **Convention Confidence**: "100% constructor DI (45 files scanned)" vs "constructor DI (seen in 3/3 sampled files)"

### Phase 3 (Artifact Generation)

**More skills generated** because:
- Custom base class hierarchies → skills (e.g., "add new LeafCrudService entity")
- More trigger types detected → more standard skills
- Best examples selected → higher quality skill templates

**More rules generated** because:
- Custom annotations documented → project-specific rules
- Anti-patterns quantified → tech-debt rules with evidence
- Convention frequency data → confident convention rules

**Better quality** because:
- Code examples in rules pulled from *best* files, not random ones
- Skills reference actual base classes and annotations from the project
- Anti-pattern rules cite specific files and counts

## Files Modified

| File | Change |
|------|--------|
| `skills/claudboard/SKILL.md` | Add step 1c (wide scan), modify 1d (strategic sampling), expand 1f (multi-path trace) |
| `skills/claudboard/references/stack-detectors.md` | Add wide scan grep patterns per language |
| `skills/claudboard/references/pattern-catalog.md` | Add custom pattern detection section, expand anti-pattern grep patterns |
| `skills/claudboard/references/quality-signals.md` | Add new skill triggers (scheduled, websocket, feign, async, etc.) |
| `skills/claudboard-analyse/SKILL.md` | Mirror Phase 1 changes |
| `skills/claudboard-refresh/SKILL.md` | Add wide scan to delta discovery |

## Risks

1. **Grep overhead on huge repos (10K+ files)**: Mitigate with `--include` file type filters and early termination
2. **Too many skill candidates**: Cap at 8 skills, prioritize by usage count
3. **Custom pattern false positives**: An abstract class with 3 subclasses might be incidental, not a pattern. Mitigate: only promote to skill if subclass count >= 5 or if annotation-based
4. **Regression on small repos**: Small repos don't benefit from wide scan (already reading everything). Mitigate: skip wide scan for <50 files
