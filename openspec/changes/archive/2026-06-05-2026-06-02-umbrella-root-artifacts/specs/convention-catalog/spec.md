## MODIFIED Requirements

### Requirement: Catalog SHALL support workspace mode and locate at the umbrella root

The catalog's `mode` enum SHALL include the value `"workspace"` in addition to `"single-project"` and `"monorepo"`.

The catalog file SHALL be located at `<umbrella_root>/.claudboard/catalog.json`, where `<umbrella_root>` is:

- the repository root for `mode: "single-project"` and `mode: "monorepo"`
- the workspace directory for `mode: "workspace"` (with `.claudboard/` reachable via the meta-repo symlink when bootstrapped, or written inline at the workspace root when not bootstrapped — see `analyse-performance`)

The catalog SHALL include an `umbrella_root` field carrying the resolved absolute path to the umbrella root. Consumers (`/generate`, future `/refresh`) use this field to locate sibling artifacts (`.claude/reports/`, `.claudboard/audits/`).

Consumers MUST NOT branch on the `mode` field for logic. The `stacks`, `conventions`, `patterns`, `proposed_artifacts`, and `adaptive_depth` fields carry all the structural information generation needs, regardless of mode. The `mode` field is for diagnostic and UX text only.

#### Scenario: Workspace catalog has `mode: "workspace"` and correct umbrella_root
- **WHEN** `/analyse` runs against MEAS workspace at `/Users/x/meas/`
- **THEN** the catalog at `/Users/x/meas/.claudboard/catalog.json` has `mode: "workspace"` AND `umbrella_root: "/Users/x/meas"`

#### Scenario: Monorepo catalog umbrella_root equals repo root
- **WHEN** `/analyse` runs against craftsphere.cloud at `/Users/x/craftsphere.cloud/`
- **THEN** the catalog has `mode: "monorepo"` AND `umbrella_root: "/Users/x/craftsphere.cloud"` (equal to the `repo` field)

#### Scenario: Workspace catalog reachable via meta-repo symlink when bootstrapped
- **WHEN** the workspace has been bootstrapped via `/claudboard-workspace-init` AND `<workspace>/.claudboard` is a symlink to `<workspace>/meas.workspace/.claudboard`
- **THEN** the catalog file written at `<workspace>/.claudboard/catalog.json` resolves through the symlink to the meta-repo's `.claudboard/catalog.json`; consumers reading either path see the same file

---

### Requirement: Catalog `stacks` entries SHALL disambiguate service count from repo count

Each entry in the catalog's `stacks` array SHALL include both `service_count` (number of detected services in this stack, applies to monorepo and single-project) and `repo_count` (number of detected repos in this stack, applies to workspace; equal to `service_count` for monorepo and single-project).

The fields are equal in monorepo and single-project modes (one repo, N services). In workspace mode they may differ — a stack might be "5 React MFEs across 5 repos" (both 5) or "1 shared library with N services depending on it" (different shape; library handled separately).

#### Scenario: Workspace stack carries both counts
- **WHEN** MEAS workspace has 7 Java service repos and 5 React MFE repos
- **THEN** the catalog's `stacks` array contains entries `{id: "java-spring", service_count: 7, repo_count: 7, ...}` and `{id: "react-ts", service_count: 5, repo_count: 5, ...}`

#### Scenario: Monorepo stack repo_count equals 1 globally
- **WHEN** craftsphere.cloud monorepo has 11 Java services in one repo
- **THEN** the `stacks` entry for `java-spring` has `service_count: 11` AND `repo_count: 1`

---

### Requirement: Catalog SHALL include cross-service edges across all multi-service modes

The catalog SHALL include a `cross_service_edges` field — an array of edges, each `{source: <service>, target: <service>, transport: "rest" | "kafka" | "grpc" | "graphql" | "amqp" | …, source_file: <path>, coupling: "loose" | "tight"}` — populated in both workspace and monorepo modes from the cross-service dependency graph constructed in Phase 1 (see `cross-service-graph` spec).

In single-project mode the field is `[]` (empty array).

Consumers use this field for any cross-service analysis they need; the canonical render is the umbrella ecosystem.md.

#### Scenario: Workspace catalog includes cross-service edges
- **WHEN** MEAS workspace's `/analyse` detects 30 cross-service edges (REST, Kafka, REST-via-shared-DTO, etc.)
- **THEN** the catalog's `cross_service_edges` array has 30 entries with `source`, `target`, `transport`, `source_file`, and `coupling`

#### Scenario: Monorepo catalog includes cross-service edges (new)
- **WHEN** craftsphere.cloud's `/analyse` detects cross-service edges between its 19 services
- **THEN** the catalog's `cross_service_edges` array is populated (this is a new field in monorepo mode catalogs; prior versions did not populate it)

#### Scenario: Single-project catalog has empty edges array
- **WHEN** `/analyse` runs against a single-project repo
- **THEN** the catalog has `cross_service_edges: []`
