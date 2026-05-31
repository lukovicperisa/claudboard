# discover.sh — v1 JSON Output Schema

`scripts/discover.sh <repo-path>` emits a single JSON document to stdout.
The analyse SKILL.md asserts `schema_version == "1"` before consuming any fields.

## Schema

```json
{
  "schema_version": "1",
  "repo": {
    "path": "<absolute-path>",
    "languages": ["java", "typescript"],
    "source_file_count": 412
  },
  "build_files": {
    "java":       ["pom.xml", "build.gradle"],
    "typescript": ["package.json", "tsconfig.json"],
    "python":     [],
    "go":         [],
    "rust":       [],
    "dotnet":     [],
    "common":     ["Dockerfile", ".github/workflows/ci.yml"]
  },
  "wide_scan": {
    "skill_triggers": {
      "@RestController":  {"count": 18, "best_example": "src/main/.../OrderController.java"},
      "@KafkaListener":   {"count":  5, "best_example": "src/main/.../OrderConsumer.java"},
      "useQuery":         {"count": 12, "best_example": "src/components/DataList.tsx"}
    },
    "anti_patterns": {
      "field_injection":          23,
      "broad_exception_catch":     7,
      "null_returns":              5,
      "reflection":                2,
      "ts_any":                   45,
      "console_log":              12,
      "todo_fixme":               34
    },
    "conventions": {
      "java_di_style":    "constructor",
      "java_logging":     "slf4j",
      "ts_import_style":  "alias"
    },
    "god_class_candidates": [
      {"file": "src/main/.../OrderService.java", "loc": 850},
      {"file": "src/main/.../UserService.java",  "loc": 612}
    ],
    "inheritance_map": [
      {"base": "AbstractBaseService", "subclasses": 12,
       "sample_file": "src/main/.../AbstractBaseService.java"}
    ]
  },
  "duplication": {
    "candidates": []
  },
  "ref_load_signals": {
    "messaging":     true,
    "streaming":     false,
    "graphql":       false,
    "architectural": false
  }
}
```

## Field Semantics

### `schema_version`
String. Increment when any breaking field is added/removed/renamed.
Current version: `"1"`.

**Schema-bump procedure:** When changing the schema:
1. Increment `SCHEMA_VERSION` in `discover.sh`.
2. Update the assertion in the analyse SKILL.md (`schema_version == "1"` → new version).
3. Update this doc with the new shape and a changelog entry.
4. Search for any other consumers of the JSON (e.g., techdebt skill) and update them.
5. Commit all four changes atomically so the version is always consistent.

### `repo`
- `path` — Absolute path passed to the script.
- `languages` — Detected languages; populated from build file presence.
- `source_file_count` — Count of source files (`.java`, `.kt`, `.ts`, `.tsx`, `.js`, `.py`, `.go`, `.rs`, `.cs`), excluding generated dirs.

### `build_files`
Per-language list of detected build files (relative paths from repo root). `"common"` holds cross-language files (Dockerfile, CI configs, infra).

### `wide_scan`

#### `skill_triggers`
Per-trigger object with `count` (total occurrences across repo) and `best_example` (the shortest/simplest file containing the trigger — strongest template candidate).

#### `anti_patterns`
Per-pattern integer count:
- `field_injection` — Java `@Autowired` fields
- `broad_exception_catch` — `catch (Exception` / `catch (Throwable`
- `null_returns` — `return null;`
- `reflection` — `ReflectionUtils`, `getDeclaredField`, `setAccessible`
- `ts_any` — TypeScript `any` / `@ts-ignore` / `as any`
- `console_log` — TypeScript `console.log` in non-test files
- `todo_fixme` — `TODO`/`FIXME`/`HACK` comments

#### `conventions`
- `java_di_style` — `"constructor"` / `"field"` / `"mixed"` / `"unknown"`
- `java_logging` — `"slf4j-annotation"` / `"slf4j-factory"` / `"mixed"` / `"unknown"`
- `ts_import_style` — `"alias"` / `"relative"` / `"mixed"` / `"unknown"`

#### `god_class_candidates`
Files >300 LOC in main source (not tests), sorted descending by LOC. Top 10 only.

#### `inheritance_map`
Base classes/interfaces with ≥3 subclasses. Array of `{base, subclasses, sample_file}`.

### `duplication`
- `candidates` — Always `[]` when `repo.source_file_count < 30` (detection skipped).
  Otherwise: array of objects `{pattern, occurrences, files}` where the same ~5-line
  pattern appears in 3+ different files.

### `ref_load_signals`
Booleans indicating whether keyword matches for each transport family were found.
Used by the SKILL.md to gate which reference files to load.

| Field | `true` when |
|-------|-------------|
| `messaging` | Any of: kafka, rabbitmq, amqp, jms, sns, sqs, solace, activemq |
| `streaming` | Any of: websocket, sse, server-sent-events, rsocket |
| `graphql` | Any of: graphql, apollo, type-graphql |
| `architectural` | Any of: saga, cqrs, outbox, event-sourcing |
