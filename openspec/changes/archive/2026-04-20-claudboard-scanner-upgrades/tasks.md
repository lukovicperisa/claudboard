## 1. Security Posture Detection

- [x] 1.1 Add security grep patterns to `stack-detectors.md` — `SecurityFilterChain`, `@PreAuthorize`, `@Secured`, `@EnableMethodSecurity`, `OncePerRequestFilter`, `CorsConfigurationSource`, `@CrossOrigin`, custom auth annotations
- [x] 1.2 Add "Security" scoring dimension to `quality-signals.md` — Enforced / Basic / Missing levels with detection criteria
- [x] 1.3 Add auth coverage gap detection to `quality-signals.md` Detection Checklist — compare controller count vs auth-annotated endpoint count
- [x] 1.4 Add CORS detection checklist items to `quality-signals.md`
- [x] 1.5 Add security anti-patterns to `pattern-catalog.md` — unprotected endpoints, missing CORS with REST API, no security framework

## 2. API Surface Inventory

- [x] 2.1 Add endpoint counting grep patterns to `stack-detectors.md` — `@GetMapping`, `@PostMapping`, `@PutMapping`, `@DeleteMapping`, `@PatchMapping` with tally
- [x] 2.2 Add API versioning detection pattern to `stack-detectors.md` — regex for `/v\d+/` in `@RequestMapping` values
- [x] 2.3 Add OpenAPI/Swagger dependency detection to `stack-detectors.md` — `springdoc-openapi`, `springfox`, `swagger`
- [x] 2.4 Add "API Surface" subsection template to `quality-signals.md` Quality Report Template — controller count, endpoint total, versioning, docs tooling

## 3. Observability Detection

- [x] 3.1 Add observability dependency detection to `stack-detectors.md` — `spring-boot-starter-actuator`, `micrometer-core`, `micrometer-tracing`, `spring-cloud-sleuth`, `io.opentelemetry`
- [x] 3.2 Add observability annotation grep patterns to `stack-detectors.md` — `@Timed`, `MeterRegistry`
- [x] 3.3 Add structured logging detection to `stack-detectors.md` — `logstash-logback-encoder`, `net.logstash.logback`
- [x] 3.4 Add "Observability" scoring dimension to `quality-signals.md` — Good / Acceptable / Debt levels

## 4. Skill Deduplication

- [x] 4.1 Add skill dedup logic section to `SKILL.md` Phase 2 — after skill trigger collection, before report presentation
- [x] 4.2 Define overlap criteria in SKILL.md: >50% file glob intersection OR same trigger annotation in both scopes
- [x] 4.3 Add dedup report format to `quality-signals.md` — overlap warning with merge/keep question for user

## 5. Compound Severity

- [x] 5.1 Add compound severity lookup table to `pattern-catalog.md` with initial 4 rules (null+reflection, broad-catch+cascade, god-class+no-tests, no-auth+PII)
- [x] 5.2 Add compound severity reporting format to `quality-signals.md` Quality Report Template — "[HIGH — compound]" format with explanation
- [x] 5.3 Add compound severity cross-reference step to `SKILL.md` Phase 2 — after individual anti-pattern detection, check pairs against table

## 6. Dependency Deep Scan

- [x] 6.1 Add BOM detection patterns to `stack-detectors.md` — `platform(`, `enforcedPlatform(` for Gradle; `<dependencyManagement>` for Maven
- [x] 6.2 Add dependency conflict detection to `stack-detectors.md` — `resolutionStrategy`, `force =`, `<exclusions>`
- [x] 6.3 Add SBOM detection to `stack-detectors.md` — `cyclonedx`, `spdx` plugins in build/CI
- [x] 6.4 Add cross-module version mismatch detection to `stack-detectors.md` — compare same dep across modules
- [x] 6.5 Expand Dependencies scoring dimension in `quality-signals.md` to include BOM, conflicts, SBOM presence

## 7. SKILL.md Orchestration Updates

- [x] 7.1 Update Phase 1c in `SKILL.md` to include security, API surface, and observability grep patterns in parallel scan
- [x] 7.2 Update Phase 2 report template in `SKILL.md` to include new sections: Security, API Surface, Observability
- [x] 7.3 Add skill dedup step to `SKILL.md` Phase 2 between trigger collection and proposal presentation
- [x] 7.4 Add compound severity step to `SKILL.md` Phase 2 after Watch section generation

## 8. Verification

- [ ] 8.1 Re-run claudboard against `meas.cloud.datahandler` and verify new sections appear in report
- [ ] 8.2 Verify skill dedup catches mongodb-entity / leaf-entity overlap
- [ ] 8.3 Verify compound severity escalates null-returns from INFO given reflection co-occurrence
- [ ] 8.4 Run against `craftsphere.cloud` to verify no regressions on polyglot monorepo scan
