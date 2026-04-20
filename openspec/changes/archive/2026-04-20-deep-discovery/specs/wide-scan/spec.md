# Spec: Wide Scan (Step 1c)

## Overview

Grep-based inventory of the entire repo that reads zero full files. Produces a Pattern Inventory used by Strategic Sampling (step 1d) to pick which files to read deeply.

## Requirements

### MUST

1. Detect all custom annotations (`@interface` declarations) with usage counts
2. Detect all abstract base classes with subclass counts
3. Run all existing skill triggers (13) plus new triggers (11) via grep
4. Detect God class candidates (files > 300 LOC in src/main or equivalent)
5. Count anti-pattern signals: field injection, broad catches, null returns, reflection in business logic, legacy date, console logging, star imports, TODO/FIXME/HACK
6. Measure convention frequency: DI style ratio, logging framework, test naming pattern
7. Complete in <30 seconds for repos up to 1000 files
8. Skip known build output dirs (node_modules, target, build, dist, __pycache__, .venv, vendor, .gradle)
9. Produce structured Pattern Inventory for downstream consumption
10. Work for Java, TypeScript, Python (primary); Go, Rust, .NET (secondary)

### SHOULD

11. Detect interface-implementation pairs (ports & adapters signal)
12. Detect parallel class hierarchies (Root*, Branch*, Leaf* naming)
13. Count files per directory to identify thin vs thick modules
14. Detect mixed patterns (e.g., some @Autowired + some constructor DI = transitional)

### COULD

15. Use git log for hotspot detection (most recently/frequently changed files)
16. Detect comment density per file (high comments = documentation culture)

## Language-Specific Grep Patterns

### Java
```
Inheritance:    grep -rn 'abstract class\|extends \|implements ' --include='*.java'
Annotations:   grep -rn '@interface' --include='*.java'
DI:            grep -rc '@Autowired' / grep -rc 'private final' --include='*.java'
Anti-patterns: grep -rn 'catch (Exception\|return null\|System.out\|import .*\.\*;'
Reflection:    grep -rn 'ReflectionUtils\|getDeclaredField\|setAccessible\|getMethod('
```

### TypeScript
```
Inheritance:    grep -rn 'abstract class\|extends \|implements ' --include='*.ts'
Patterns:       grep -rn 'export class\|export interface\|export type' --include='*.ts'
Anti-patterns:  grep -rn 'any\b\|// @ts-ignore\|as any' --include='*.ts'
React hooks:    grep -rn 'useState\|useEffect\|useQuery\|useMutation' --include='*.tsx'
```

### Python
```
Inheritance:    grep -rn 'class.*ABC\|class.*Protocol\|class.*BaseModel' --include='*.py'
Patterns:       grep -rn '@abstractmethod\|@dataclass\|@validator' --include='*.py'
Anti-patterns:  grep -rn 'except Exception\|except:\|# type: ignore\|pass$' --include='*.py'
```

## Output: Pattern Inventory Schema

```yaml
inheritance_map:
  - base: <class_name>
    file: <path>
    extends_count: <int>
    subclass_files: [<paths>]

custom_annotations:
  - name: <annotation>
    declaration_file: <path>
    usage_count: <int>
    usage_files: [<paths>]

skill_triggers:
  - trigger: <name>
    grep_pattern: <pattern>
    count: <int>
    files: [<paths>]
    best_example: <path>  # smallest file with this trigger

anti_patterns:
  - type: <name>
    severity: <CRITICAL|HIGH|MEDIUM>
    count: <int>
    files: [{name: <path>, detail: <context>}]

god_class_candidates:
  - file: <path>
    loc: <int>

conventions:
  di_style: <"constructor-only"|"field-injection"|"mixed">
  di_ratio: {constructor: <int>, field: <int>}
  logging: <"slf4j-factory"|"@Slf4j"|"@Log4j"|"mixed">
  test_naming: <pattern>
  import_style: <"explicit"|"star"|"mixed">

file_size_distribution:
  total_source_files: <int>
  median_loc: <int>
  p90_loc: <int>
  max_loc: <int>
  max_file: <path>
```

## Acceptance Criteria

- On meas.cloud.datahandler: detects AbstractDataEntity (43+ subclasses), Root/Branch/LeafCrudService hierarchy, @Cascade/@Authorize/@References annotations, CanvasService as God class, reflection in business logic
- On craftsphere.cloud: detects all existing triggers + any new ones from expanded catalog
- On a <50 file repo: skips wide scan, falls through to full read
- Total grep execution time < 30s on 1000-file repo
