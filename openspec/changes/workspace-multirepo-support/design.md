## Context

Claudboard currently supports three analysis modes: single-project, monorepo (added in monorepo-support change), and now workspace (multi-repo). The monorepo change established the N+1 report structure and per-service analysis loop. This change builds on that foundation by adding workspace detection, a right-level guard, cross-service graph construction, and ecosystem injection.

Key insight from monorepo-support: the detection discriminator between monorepo services and workspace repos is `.git/` presence in each build root. Monorepo services share a single `.git/` at the repo root; workspace repos each have their own `.git/`. This single signal enables clean mode switching.

Files affected:
- `skills/claudboard-analyse/SKILL.md` — Phase 1a, new graph phase, injection phase
- `skills/claudboard-refresh/SKILL.md` — workspace vs service-level refresh
- `skills/claudboard/references/stack-detectors.md` — identity resolution, outbound/inbound detection patterns

## Goals / Non-Goals

**Goals:**
- Right-level guard: detect when user is analysing a microservice in isolation and prompt to step up
- Workspace mode: analyse N independent repos from their parent directory in one session
- Cross-service graph: detect REST, Kafka, Solace (Spring Cloud Stream + JCSMP) dependencies between repos
- Ecosystem injection: write per-repo `.claude/memories/ecosystem.md` with cross-service context
- No change to developer workflow: ecosystem.md auto-loads, nothing to configure
- Workspace-level refresh: update all ecosystem files; service-level refresh: partial + stale warning

**Non-Goals:**
- Storing anything at workspace directory level — workspace is entry point only
- Cross-language REST detection beyond the listed stacks (Java FeignClient/RestTemplate/WebClient, TypeScript Axios/fetch with service names)
- gRPC dependency detection — future work
- Shared database detection across repos — future work
- Organisation-level rules published to a central location — future work

## Decisions

### 1. Right-level check: sibling detection, not size heuristics

**Decision:** The right-level check is driven by sibling detection only — if the parent directory contains N≥2 other directories that look like services (have build files), step-up prompt is triggered. Monolith vs microservice is not assessed by file count or domain package count.

**Rationale:** Size heuristics are unreliable. A small monolith looks like a microservice by size. A bloated microservice looks like a monolith. The sibling signal is structural and unambiguous: if other services exist at the same level, the user is almost certainly in a microservice context.

**Escape hatch:** User says "n" to the step-up prompt → proceed at current level. No further checks. User knows their codebase better than heuristics do.

**Alternative considered:** Check for multiple bounded contexts within the service (multiple domain packages). Rejected — too language-specific and prone to false positives (utility packages, config packages).

### 2. Workspace detection: `.git/` as discriminator

**Decision:** Workspace mode is detected when CWD has no build file AND subdirectories have build files AND those subdirectories each contain a `.git/` directory. This discriminates workspace from monorepo (monorepo subdirs have build files but no `.git/`).

**Detection sequence in Phase 1a:**
```
1. Does CWD have a build file?
   YES → standard single-project or monorepo detection (existing logic)
   NO  → check subdirs

2. Do subdirs have build files?
   NO  → nothing to analyse, report error
   YES → check for .git/ in each subdir

3. Do subdirs with build files have .git/?
   YES → workspace mode (multi-repo)
   NO  → monorepo mode (existing logic)
```

**Right-level check (inserted before step 1):**
```
0. Does CWD have a build file AND does parent dir have N≥2 other build-file dirs?
   YES → "Looks like a microservice. Found siblings: [list]. Step up? [y/n]"
         YES → re-run from parent
         NO  → proceed at CWD
```

### 3. Service identity resolution: application name → directory name

**Decision:** Resolve service identity using `spring.application.name` from `application.yml` or `application.properties` if present; fall back to directory name.

**Matching algorithm for dependency graph:**
1. For each detected outbound reference (FeignClient name, URL segment, topic name): attempt to match against every other repo's identity
2. REST match: FeignClient `name` or `url` contains repo identity string
3. Kafka/Solace match: producer topic name equals consumer topic name (exact string match)
4. If no match found: record as "external dependency (unresolved)" — don't discard

**Alternative considered:** Kubernetes service manifest names, Docker compose service names. These are useful supporting signals but not the primary — they may not exist in all projects. Add as supplementary signals if primary lookup fails.

### 4. Cross-service graph construction: new phase after per-repo analysis

**Decision:** Graph construction runs as a dedicated phase after all per-repo analyses complete. It cannot run incrementally because it requires all repos' inbound surfaces to be known before matching any outbound calls.

**Phase structure:**
```
Phase 1b: Per-repo analysis loop (existing, extended to extract surfaces)
  For each repo, additionally extract:
    - Outbound: FeignClient names, RestTemplate/WebClient URLs, Kafka producer topics,
                Solace publisher topics/queues (Spring Cloud Stream destinations +
                JCSMP Topic.of()/Queue.get() literals)
    - Inbound:  @RestController paths, spring.application.name, Kafka @KafkaListener topics,
                Solace @StreamListener destinations + XMLMessageConsumer subscriptions
    - Identity: spring.application.name → directory name fallback

Phase 1c: Cross-service graph construction (NEW)
  For each repo A:
    For each outbound reference in A:
      For each repo B (where B ≠ A):
        If outbound matches B's identity or inbound surface → add edge A→B
  Classify each edge:
    REST with no retry/circuit breaker config → TIGHT
    REST with retry/circuit breaker detected  → MODERATE
    Async event (Kafka/Solace)               → LOOSE
    Same DB connection string detected       → TIGHT (flag as risk)
  Detect compound patterns:
    Synchronous chain: A→B→C (all REST/TIGHT) → flag latency amplification risk
    Circular dependency: A→B→A → flag architectural risk
```

**Solace detection — both flavours:**
| Signal | Spring Cloud Stream | JCSMP |
|--------|--------------------|----|
| Dependency | `solace-spring-cloud-stream` | `sol-jcsmp` |
| Producer topic | `spring.cloud.stream.bindings.{ch}.destination` in config | `Topic.of("name")` in code |
| Consumer topic | `@StreamListener` binding destination | `XMLMessageConsumer` + `addSubscription(Topic.of("name"))` |
| Producer class | `@Output` channel / `StreamBridge` | `XMLMessageProducer` |
| Consumer class | `@StreamListener` / `@Input` | `XMLMessageConsumer.onReceive()` |

### 5. Ecosystem injection: `.claude/memories/ecosystem.md` per repo

**Decision:** Write cross-service context to `.claude/memories/ecosystem.md` in each repo. Do not inject into CLAUDE.md.

**Rationale:** `ecosystem.md` as a managed memory file has clear ownership (claudboard writes it, refresh updates it). CLAUDE.md is hand-editable — injecting managed content creates merge conflicts and user confusion on refresh. Memory files are auto-loaded by Claude Code with no user action required.

**Content per file:** role in ecosystem, depends-on table (service + protocol + how + source file), used-by table, shared contracts (Kafka/Solace schemas, OpenAPI specs), coupling warnings (tight sync chains, circular deps, shared DB).

**Alternative considered:** Inject a delimited section into CLAUDE.md (BEGIN/END markers). Rejected — markers are fragile, user edits break them, refresh becomes a string-manipulation exercise rather than a clean overwrite.

### 6. Refresh: workspace vs service level

**Decision:**
- **Workspace-level `/refresh`**: re-runs graph construction + updates all affected ecosystem files
- **Service-level `/refresh`**: updates that service's ecosystem.md from its own perspective only (its outbound calls may have changed), then warns: "user-service and notification-service ecosystem context may be stale — run `/refresh` from workspace root to sync all"

**Rationale:** Service-level refresh can't see other repos' outbound surfaces — it can only re-derive what it depends on, not who depends on it. Full sync requires workspace context.

## Risks / Trade-offs

- **[Topic name collisions]** Two unrelated services using the same Kafka topic name → false dependency edge. → Mitigation: present graph to user before injecting; user can correct mismatches.
- **[Unresolved dependencies]** FeignClient targeting an external API (not a sibling repo) → recorded as "external (unresolved)". → Mitigation: record explicitly rather than silently dropping; prompts user to annotate if needed.
- **[Stale ecosystem files]** Service-level refresh updates only one repo's file; sibling files drift. → Mitigation: explicit staleness warning on service-level refresh. Workspace-level refresh is the canonical sync operation.
- **[Large workspaces]** 10+ repos → significant context window pressure for full per-repo analysis. → Mitigation: same as monorepo (one-time operation, quality over speed). Document that very large workspaces may need multiple sessions.
- **[JCSMP topic literals not in one place]** Topic strings may be constants defined elsewhere, not inline. → Mitigation: grep for the constant definition, not just the `Topic.of()` call site. Note unresolved topic references in the report.
