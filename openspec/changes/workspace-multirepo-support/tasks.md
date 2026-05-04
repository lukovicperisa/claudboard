## 1. Right-Level Check (stack-detectors.md + analyse Phase 1a)

- [x] 1.1 Add "Right-Level Check" section to `stack-detectors.md` documenting sibling detection logic: scan `../` for directories containing any build file (`build.gradle`, `pom.xml`, `package.json`, `go.mod`, `pyproject.toml`, `Cargo.toml`, `*.csproj`); if N≥2 sibling dirs found, trigger step-up prompt
- [x] 1.2 Add right-level check to `claudboard-analyse/SKILL.md` Phase 1a as step 0 (before CWD build file check): show sibling list with detected stacks, ask "Analyse at ecosystem level? [y/n]"; YES → re-run from parent; NO → proceed at CWD
- [x] 1.3 Add scenario for "no siblings detected" (skip check) and "already at workspace/monorepo root" (skip check — no build file in CWD triggers later path)
- [x] 1.4 Ensure step-up prompt lists each sibling with its detected stack (e.g., "user-service (Java/Spring Boot)", "frontend (React/TypeScript)"), and unknown-stack siblings shown as "(unknown stack)"

## 2. Workspace Detection (analyse Phase 1a extended)

- [x] 2.1 Extend Phase 1a detection sequence in `claudboard-analyse/SKILL.md` with workspace branch: when CWD has no build file → check subdirs for build files → check each build-file subdir for `.git/` → workspace mode if `.git/` found, monorepo mode if not
- [x] 2.2 Add service vs library classification for workspace repos: same signals as monorepo classification (Dockerfile or main entry point → service; publish tasks + no main → library); excluded library repos noted in ecosystem context
- [x] 2.3 Add topology presentation step: after classification, display "Found N repos: [services with stacks] + [libraries]. Running full analysis of each service." and wait for user confirmation before proceeding
- [x] 2.4 Handle mixed subdirs: subdirs with `.git/` → independent repos; subdirs without `.git/` but with build files → treated as shared libraries/infra and excluded from service list
- [x] 2.5 Handle "no build files found anywhere" edge case: report error "No projects found at [path]. Check the path and try again." and stop
- [x] 2.6 Add user correction step: after topology presentation, allow user to correct misclassifications before analysis begins

## 3. Service Identity Resolution (stack-detectors.md)

- [x] 3.1 Add "Service Identity Resolution" section to `stack-detectors.md`: read `spring.application.name` from `application.yml` or `application.properties` if present; fall back to directory name
- [x] 3.2 Document supplementary identity signals (Kubernetes service manifests, Docker Compose service names) as fallback if both primary signals absent
- [x] 3.3 Add identity extraction step to per-repo analysis loop in `claudboard-analyse/SKILL.md` Phase 1b: extract and record each repo's resolved identity before surface extraction

## 4. Per-Repo Surface Extraction (analyse Phase 1b extension)

- [x] 4.1 Add outbound REST surface extraction to `stack-detectors.md`: `@FeignClient(name=...)`, `RestTemplate` URL patterns, `WebClient` base URLs (Java); Axios/fetch with service name in URL (TypeScript)
- [x] 4.2 Add inbound REST surface extraction: `@RestController` endpoint paths, `spring.application.name` as service identity
- [x] 4.3 Add outbound Kafka extraction: `KafkaTemplate.send("topic-name", ...)`, `@SendTo("topic-name")` literals
- [x] 4.4 Add inbound Kafka extraction: `@KafkaListener(topics = "topic-name")` values
- [x] 4.5 Add outbound Solace Spring Cloud Stream extraction: `spring.cloud.stream.bindings.{channel}.destination` values from `application.yml`/`application.properties`, linked to `@Output` channels or `StreamBridge`
- [x] 4.6 Add inbound Solace Spring Cloud Stream extraction: `@StreamListener` binding destinations
- [x] 4.7 Add outbound Solace JCSMP extraction: `Topic.of("name")` and `Queue.get("name")` literals in producer code; when topic is a constant, grep for constant definition and resolve the literal value; note unresolved constants
- [x] 4.8 Add inbound Solace JCSMP extraction: `XMLMessageConsumer.addSubscription(Topic.of("name"))` values
- [x] 4.9 Integrate surface extraction into per-repo loop in `claudboard-analyse/SKILL.md` Phase 1b: after standard per-service analysis, run outbound + inbound extraction and record results for graph construction

## 5. Cross-Service Graph Construction (new Phase 1c in workspace mode)

- [x] 5.1 Add Phase 1c to `claudboard-analyse/SKILL.md` (workspace mode only): iterate all repo pairs, match outbound references against known identities and inbound surfaces; REST match on identity string in FeignClient name/URL; Kafka/Solace match on exact topic string equality
- [x] 5.2 Record unresolved outbound references as "external dependency (unresolved)" — do not discard
- [x] 5.3 Add coupling strength classification per edge: TIGHT (REST, no `@CircuitBreaker`/`@Retry`/Resilience4j config detected), MODERATE (REST + circuit breaker or retry detected), LOOSE (Kafka/Solace async)
- [x] 5.4 Add synchronous chain detection: flag A→B→C (all REST/TIGHT) as "latency amplification and failure cascade risk"
- [x] 5.5 Add circular dependency detection: flag A→B→A as "circular dependency — architectural risk"
- [x] 5.6 Add graph review prompt before injection: display full graph with edges, coupling classifications, and warnings; ask "Proceed with ecosystem injection? [y/n/edit]"

## 6. Ecosystem Injection (new Phase 1d in workspace mode)

- [x] 6.1 Add Phase 1d to `claudboard-analyse/SKILL.md` (workspace mode only, runs after user confirms graph): write `.claude/memories/ecosystem.md` in each service repo; skip library repos and workspace root directory
- [x] 6.2 Add managed-file notice as first line: `<!-- Managed by claudboard — do not edit manually. Run /refresh from workspace root to update. -->`
- [x] 6.3 Populate "Role" section: one sentence describing the service's position and purpose, inferred from its inbound/outbound surface and name
- [x] 6.4 Populate "Depends On" table: service, protocol, purpose, source file — one row per outbound dependency; unresolved external deps listed as `[service-name] | [protocol] | [external — not in workspace] | [source file]`
- [x] 6.5 Populate "Used By" table: service, protocol, how — one row per inbound dependency from graph
- [x] 6.6 Populate "Shared Contracts" section: Kafka/Solace topics and schemas this service participates in; OpenAPI spec path if detected
- [x] 6.7 Populate "Coupling Warnings" section: TIGHT edge warnings for this service (both as caller and callee), synchronous chains, circular dependencies
- [x] 6.8 Add CLAUDE.md ecosystem reference: when a service CLAUDE.md is generated in workspace mode, add "## Ecosystem" section pointing to `ecosystem.md` path — do not duplicate content

## 7. Workspace and Service-Level Refresh (refresh SKILL.md)

- [x] 7.1 Add workspace-level refresh path to `claudboard-refresh/SKILL.md`: when `/refresh` is run from workspace root, re-run Phase 1c (graph construction) using current per-repo surfaces and completely overwrite all `ecosystem.md` files
- [x] 7.2 Add new-service detection on workspace refresh: if a new repo directory appears that was not in the prior analysis, flag: "New repo detected: {dir-name}. Run `/analyse` from workspace root to include it in the ecosystem graph."
- [x] 7.3 Add service-level refresh path: when `/refresh` is run from within a single service repo, update only that service's `ecosystem.md` from its own outbound perspective; then display stale warning listing sibling service names
- [x] 7.4 Add no-workspace-context case: when `/refresh` is run from a service repo with no detectable sibling repos at parent level, proceed with normal service-level refresh without ecosystem updates or warnings

## 8. Verification

- [ ] 8.1 Test right-level check: run `/analyse` from a microservice directory that has siblings; verify step-up prompt fires with correct sibling list and stacks; verify "n" proceeds without further checks
- [ ] 8.2 Test workspace detection: run `/analyse` from a parent directory above multiple git repos; verify each repo is classified as service or library; verify topology presentation and confirmation step
- [ ] 8.3 Test surface extraction and graph construction: verify REST edges detected via FeignClient; verify Kafka edges via producer/consumer topic matching; verify Solace Spring Cloud Stream and JCSMP edges detected in respective projects
- [ ] 8.4 Test ecosystem injection: verify `.claude/memories/ecosystem.md` written in each service repo with correct sections; verify libraries and workspace root have no ecosystem.md written
- [ ] 8.5 Test workspace refresh: verify all ecosystem.md files overwritten; verify new-service detection warning; verify service-level refresh stale warning
