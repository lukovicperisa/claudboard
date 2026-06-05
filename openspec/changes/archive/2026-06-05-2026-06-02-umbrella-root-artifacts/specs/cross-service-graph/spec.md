## MODIFIED Requirements

### Requirement: Cross-service dependency graph SHALL be constructed in workspace AND monorepo modes

The orchestrator SHALL construct a cross-service dependency graph in both workspace mode and monorepo mode as part of unified Phase 1 (previously workspace-mode only).

The graph is derived from the wide-scan grep output produced by `discover.sh` in Phase 1b — the same data already collected for catalog synthesis. Construction is orchestrator-side (no model fan-out), so it is essentially free in token cost.

The graph feeds two outputs:

1. The `cross_service_edges` field of the convention catalog
2. The umbrella `ecosystem.md` memory file

Single-project mode produces an empty graph (`cross_service_edges: []`) — no cross-service edges exist when there is one service.

#### Scenario: Monorepo mode builds the graph
- **WHEN** monorepo-mode `/analyse` runs against a 19-service monorepo
- **THEN** the orchestrator constructs a graph of cross-service edges (REST, Kafka, gRPC, etc.) AND the catalog's `cross_service_edges` field is populated AND the umbrella ecosystem.md references the graph

#### Scenario: Workspace mode builds the graph (preserved behaviour)
- **WHEN** workspace-mode `/analyse` runs against a 14-repo workspace
- **THEN** the graph is constructed exactly as it was in pre-change workspace mode; the only change is that the consumer is the unified umbrella ecosystem.md rather than per-repo files

#### Scenario: Single-project mode produces empty graph
- **WHEN** `/analyse` runs against a single-project repo
- **THEN** the catalog has `cross_service_edges: []` AND any degenerate ecosystem.md states no cross-service edges exist

---

### Requirement: Graph construction SHALL be cost-bounded as part of default-mode budget

Graph construction SHALL run in default mode (not gated behind `--audit`) because it is essentially free in token cost (orchestrator-side aggregation of grep output) and feeds high-value outputs (ecosystem.md, catalog edges field).

If graph construction in monorepo mode pushes default-mode cost over the cap (≤ $50 per `analyse-performance`), the spec is revised; graph construction does not justify exceeding the cost cap. Empirical estimate: graph construction adds ≤ $1 to monorepo default-mode cost (it operates on data the orchestrator already has).

#### Scenario: Graph construction does not push default mode over cap
- **WHEN** monorepo default `/analyse` runs with graph construction enabled
- **THEN** total measured cost remains within the ≤ $50 cap stated in `analyse-performance`
