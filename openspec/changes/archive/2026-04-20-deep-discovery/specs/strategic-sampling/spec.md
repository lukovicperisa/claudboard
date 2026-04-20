# Spec: Strategic Sampling (Step 1d)

## Overview

Replaces random "3-5 files per language" with purpose-driven file selection based on Wide Scan inventory. Each file read has a reason.

## Requirements

### MUST

1. Read ALL abstract base classes with 3+ subclasses (architecture backbone)
2. Read ALL custom annotation declarations (`@interface` files)
3. Read top 3 largest source files (God class confirmation)
4. Read 1 best example per detected skill trigger (smallest/cleanest file)
5. Never exceed max file budget per repo size tier
6. Record WHY each file was selected (for Phase 2 reporting)

### SHOULD

7. Read top 3 git hotspot files (most changed in last 3 months)
8. Read 1 representative test file per test framework detected
9. Prefer files from different packages/modules (coverage diversity)

### COULD

10. Read files referenced in README or docs (documented entry points)

## File Budget

| Repo Size | Max Files Read | Selection Priority |
|-----------|---------------|-------------------|
| <50 files | All source files | No sampling needed |
| 50-200 | 25 | All categories |
| 200-500 | 20 | Drop hotspots if budget tight |
| 500+ | 15 | Base classes + triggers + God classes only |

## Selection Algorithm

```
1. Start with empty read_list
2. Add all base classes (extends_count >= 3)
3. Add all @interface declarations
4. Add top 3 by LOC (if not already in list)
5. For each skill trigger with count > 0:
   - Pick smallest file with that trigger (cleanest example)
   - Add if not already in list
6. If budget remains: add top 3 git hotspots
7. If budget remains: add 1 test file per framework
8. Trim to budget by dropping lowest-priority items
```

## Acceptance Criteria

- On meas.cloud.datahandler (138 files): reads ~20 files including AbstractDataEntity, Root/Branch/LeafCrudService, @Cascade declaration, CanvasService (God class), smallest @RestController, a test file
- Each file in read_list has a `reason` field (e.g., "base class with 43 subclasses", "God class candidate at 609 LOC")
- No random file selection — every file justified by Wide Scan data
