## 1. Service Boundary Detection (stack-detectors.md)

- [x] 1.1 Add "Monorepo Detection" section to `stack-detectors.md` with build root discovery heuristics: find independent build files, exclude nested dependencies (`node_modules/`, `vendor/`, `.venv/`)
- [x] 1.2 Add service-vs-library classification table to `stack-detectors.md` with per-stack signals (Java: `@SpringBootApplication`/`maven-publish`, Node: `"start"`/`"publishConfig"`, Python: `__main__.py`/`[build-system]`, Go: `package main`/no main, Rust: `fn main`/`[lib]`, .NET: entry point/`<IsPackable>`)
- [x] 1.3 Add Gradle/Maven multi-module edge case guidance: single root build file + per-module Dockerfiles = ask user to confirm

## 2. Analyse Phase Restructuring (analyse SKILL.md)

- [x] 2.1 Add Phase 1a: monorepo structure detection — find build roots, classify service/library, present topology to user
- [x] 2.2 Modify Phase 1b to separate global-only concerns (CI/CD, GitOps, cross-service communication, shared library inventory, branch/commit conventions) from per-service concerns
- [x] 2.3 Modify Phase 1c (Wide Scan) to scope grep patterns to service directory when in monorepo mode
- [x] 2.4 Modify Phase 1d (file budget) to apply per service independently — reference existing per-service budget allocation already in place
- [x] 2.5 Modify Phase 1e-f to run per service with convention profiling scoped to each service
- [x] 2.6 Modify Phase 2 to produce per-service quality scores and per-service Watch/Preserve findings
- [x] 2.7 Add N+1 report output specification: `claudboard-analysis.md` (global) + `claudboard-analysis-{directory-name}.md` per service, with report templates for each
- [x] 2.8 Add global report template: topology table, CI/CD, cross-service patterns, per-service summary with links
- [x] 2.9 Add single-project fallback: when only 1 build root detected, proceed with existing flow unchanged

## 3. CLAUDE.md Template (claude-md-template.md)

- [x] 3.1 Add monorepo variant section to `claude-md-template.md` with: project overview mentioning monorepo topology, services table (name, stack, directory, build/test commands), shared libraries section (name, consumers), global conventions section

## 4. Generate Multi-Report Support (generate SKILL.md)

- [x] 4.1 Modify Phase 1 report detection: check for `claudboard-analysis-*.md` alongside global report to enter monorepo generation mode
- [x] 4.2 Add monorepo CLAUDE.md generation using the monorepo template variant from claude-md-template.md
- [x] 4.3 Add per-service rule generation: produce `rules/{service-name}-conventions.md` with `paths: ["{service-dir}/**"]` for each service
- [x] 4.4 Add global rule generation: produce rules without `paths:` for repo-level concerns (CI/CD, GitOps, commit conventions)
- [x] 4.5 Add per-service skill generation: if a service report proposes skills, scope them to the service directory
- [x] 4.6 Add malformed report handling: if per-service report found but missing key sections, warn and skip that service (addresses N-26)

## 5. Techdebt Monorepo Support (techdebt SKILL.md)

- [x] 5.1 Add monorepo detection in Phase 1: check for per-service analysis reports; if absent, auto-detect services using same logic as analyse Phase 1a
- [x] 5.2 Modify scanning to scope per service directory when in monorepo mode
- [x] 5.3 Add TD-ID namespacing: prefix derivation from directory name (initials if unique, first-3-chars if collision, `GL` for global), single-project keeps `TD-NNN`
- [x] 5.4 Add cross-report dependency support in `Depends on` field: accept prefixed IDs from other service reports (e.g., `Depends on: GL-01`)
- [x] 5.5 Add monorepo output structure: `summary.md` (global with per-service table), `services/{name}/modules/*.md`, top-level `cross-cutting.md`
- [x] 5.6 Single-project fallback: existing output structure unchanged when not a monorepo

## 6. Refresh Service Delta (refresh SKILL.md)

- [x] 6.1 Add service topology comparison: compare current build roots against existing `claudboard-analysis-*.md` reports
- [x] 6.2 Handle new service: flag "New service detected: {name}. Run /analyse to include it."
- [x] 6.3 Handle removed service: flag "Service removed: {name}. Stale report and rules can be deleted."
- [x] 6.4 Handle renamed service: detect directory rename by matching stack/structure, flag with old→new names

## 7. Catalog Cleanup

- [x] 7.1 Mark N-10 as resolved in self-analysis catalog (per-service quality scoring)
- [x] 7.2 Mark N-24 as resolved (per-module test framework detection)
- [x] 7.3 Mark N-33 as closed/by-design ("Good" threshold varies by dimension — intentional)
- [x] 7.4 Mark N-34 as resolved (per-service file budget allocation)
- [x] 7.5 Mark N-26 as resolved (malformed report handling in generate)

## 8. Verification

- [ ] 8.1 Test against craftsphere.cloud: verify service detection, classification of `libraries/craftsphere.core` as library, per-service reports
- [ ] 8.2 Test against a single-project repo (azure-devops-mcp): verify no behavioral change
- [ ] 8.3 Test techdebt ID namespacing: verify prefixes are unique, cross-report deps resolve
