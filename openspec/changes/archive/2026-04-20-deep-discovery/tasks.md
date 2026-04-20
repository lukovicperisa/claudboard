# Tasks: Deep Discovery

## Task 1: Add Wide Scan step to SKILL.md
- [x] Add step 1c "Wide Scan" between structure mapping (1b) and source sampling
- [x] Define grep patterns for Java, TypeScript, Python (inheritance, annotations, anti-patterns, conventions)
- [x] Define Pattern Inventory output format
- [x] Add skip condition: repos <50 files bypass wide scan
- **Files:** `skills/claudboard/SKILL.md`

## Task 2: Update stack-detectors.md with grep patterns
- [x] Add "Wide Scan Patterns" section per language with exact grep commands
- [x] Add custom pattern detection section (abstract classes, @interface, extends mapping)
- [x] Add file size analysis commands (wc -l based)
- [x] Add convention frequency commands (DI ratio, logging style, import style)
- **Files:** `skills/claudboard/references/stack-detectors.md`

## Task 3: Expand skill triggers in quality-signals.md
- [x] Add 11 new skill triggers: @Scheduled, WebSocket, GraphQL, CLI, DB migration, Security config, @Async, @EventListener, @FeignClient, custom validators, @Aspect
- [x] Add "custom pattern skill" trigger: base class with 5+ subclasses = skill candidate
- [x] Add "custom annotation rule" trigger: annotation on 3+ classes = rule candidate
- [x] Cap total skills at 8, prioritize by usage count
- **Files:** `skills/claudboard/references/quality-signals.md`

## Task 4: Replace random sampling with Strategic Sampling
- [x] Rename step 1c (old source sampling) to step 1d
- [x] Implement file selection algorithm: base classes → annotations → God classes → trigger examples → hotspots
- [x] Add file budget tiers (<50, 50-200, 200-500, 500+)
- [x] Require `reason` field for each selected file
- **Files:** `skills/claudboard/SKILL.md`

## Task 5: Expand call-path tracing to 3-5 paths
- [x] Change step 1f from "pick ONE write operation" to "pick 3-5 paths based on Wide Scan"
- [x] Add path selection matrix (simple CRUD, complex business, async, auth, external)
- [x] Add per-path recording: DI, exceptions, logging, validation, reflection
- **Files:** `skills/claudboard/SKILL.md`

## Task 6: Add anti-pattern grep patterns to pattern-catalog.md
- [x] Add "Whole-Repo Grep Patterns" section with exact commands per anti-pattern
- [x] Add God class detection via file size (>300 LOC threshold)
- [x] Add custom pattern detection: parallel hierarchies via naming similarity
- [x] Add convention conflict detection (mixed DI styles, mixed logging)
- **Files:** `skills/claudboard/references/pattern-catalog.md`

## Task 7: Mirror changes in claudboard-analyse and claudboard-refresh
- [x] Update claudboard-analyse/SKILL.md Phase 1 to match new flow
- [x] Update claudboard-refresh/SKILL.md delta discovery to include wide scan signals
- **Files:** `skills/claudboard-analyse/SKILL.md`, `skills/claudboard-refresh/SKILL.md`

## Task 8: Add meas.cloud.datahandler eval case
- [x] Add eval case to evals.json targeting meas.cloud.datahandler
- [x] Expected: 5+ skills (rest-controller, mongodb-entity, domain-service, leaf-crud-controller, cascade-entity)
- [x] Expected: 6+ rules (java-conventions, crud-hierarchy, mongo-entity, authorization, azure-storage, testing, tech-debt)
- [x] Expected anti-patterns: God class, reflection in CRUD, dual cascade, legacy Date
- **Files:** `evals/evals.json`

## Execution Order

Tasks 1-6 done in sequence. Task 7 mirrored after 1+4+5. Task 8 done last.
