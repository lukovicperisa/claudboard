## Why

Claudboard analyses repositories in isolation — run from within a service, it produces service-local findings with no awareness of the broader ecosystem. For microservice architectures (both monorepo and multi-repo), this misses the most valuable architectural insights: which services depend on which, where synchronous chains create fragility, and where coupling is tighter than it should be. It also means developers frequently run analysis at the wrong level without realising it.

## What Changes

- **Right-level check in Phase 1a**: before any analysis, detect whether the CWD is a microservice within a larger system. If sibling services are found at the parent directory, ask the user to step up to ecosystem level. Escape hatch: user can confirm "proceed here" if the service is genuinely a monolith.
- **Workspace mode detection**: extend the existing monorepo detection to recognise a workspace directory (no build file at CWD, subdirs each have build files + independent `.git/`) as a new analysis entry point.
- **Per-repo analysis in workspace mode**: run the full per-service analysis loop (same as monorepo per-service, Phase 1c-1h) for each detected repo. Each repo gets its own `.claude/reports/claudboard-analysis.md`.
- **Cross-service graph construction** (new Phase 1c for workspace mode): after all per-repo analyses, build a directed dependency graph by matching outbound calls against inbound surfaces across repos. Detect REST (FeignClient, RestTemplate, WebClient, Axios), Kafka (topic matching), and Solace (Spring Cloud Stream + JCSMP both).
- **Service identity resolution**: `spring.application.name` from config if present, directory name as fallback. Used to match FeignClient names and service references against actual repos.
- **Ecosystem context injection**: for each repo, write `.claude/memories/ecosystem.md` containing its role, depends-on table, used-by table, shared contracts, and coupling warnings. Auto-loaded by Claude Code — no change to developer workflow.
- **Workspace-level refresh**: running `/refresh` from workspace root re-runs graph construction and updates all ecosystem files. Running from a single service updates only that service and warns that sibling ecosystem files may be stale.

## Capabilities

### New Capabilities
- `right-level-check`: Detect whether CWD is a microservice within a larger system; prompt to step up to ecosystem level
- `workspace-detection`: Recognise workspace directory (subdirs with independent `.git/` repos) as analysis entry point
- `cross-service-graph`: Build directed dependency graph across repos via REST, Kafka, and Solace detection; classify coupling strength
- `ecosystem-injection`: Write per-repo `ecosystem.md` memory files with cross-service context, coupling warnings, and shared contracts

### Modified Capabilities
- `techdebt-scanner`: workspace-level refresh behaviour (partial update with stale warning when run from single service)

## Impact

- **analyse SKILL.md**: Phase 1a extended with right-level check and workspace detection; new Phase 1c (graph construction) and Phase 1d (injection) for workspace mode
- **stack-detectors.md**: service identity resolution rules; REST/Kafka/Solace outbound+inbound detection patterns
- **refresh SKILL.md**: workspace-level vs service-level refresh behaviour
- **No breaking changes**: single-project and monorepo flows unchanged; workspace mode is additive
- **Real test targets**: two projects — one using Spring Cloud Stream/Solace, one using JCSMP/Solace
