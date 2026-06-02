## MODIFIED Requirements

### Requirement: Per-service deep analysis SHALL be opt-in via the `--audit` flag

Per-service deep analysis (Phases 1c through 1h running for each detected service in a monorepo) is no longer part of the default `/analyse` behaviour. It is produced only when `/analyse --audit` is invoked.

Default `/analyse` on a monorepo runs the global scan (Phase 1b) and a single reference-service deep pass per detected stack — sufficient to populate the `conventions`, `patterns`, and `proposed_artifacts` fields of the convention catalog. The remaining services are surfaced in the catalog's `stacks` array with `service_count` and `applicable_paths` populated, but no per-service Watch findings, quality scoring, or cross-service Kafka graph is computed for them.

`/analyse --audit` runs the full existing behaviour: Phases 1c through 1h for every detected service via parallel sub-agents, producing per-service audit reports with Watch findings, 8-dimension quality scoring, cross-service edges, and architectural pattern detection.

The per-service report content shape is otherwise unchanged. Only the production trigger changes (default → opt-in) and the output location changes (see following requirement).

#### Scenario: Default `/analyse` on a 19-service monorepo
- **WHEN** `/analyse` runs against a monorepo with 19 services (without `--audit`)
- **THEN** the global scan runs once, a reference-service deep pass runs per detected stack (typically 4-6 stacks, not 19 services), and the convention catalog is produced; NO per-service audit files are written

#### Scenario: `/analyse --audit` on the same monorepo
- **WHEN** `/analyse --audit` runs against the same monorepo
- **THEN** Phases 1c-1h run for every detected service via Sonnet-tier sub-agents, and per-service audit files are written for every service

#### Scenario: Single-project repo (no per-service split applies)
- **WHEN** `/analyse` runs against a single-project repo (without `--audit`)
- **THEN** the existing single-project flow runs and produces the catalog plus a thin human-readable summary; `--audit` is a no-op (or produces a slightly more detailed summary) — the per-service split does not apply

---

### Requirement: Per-service audit reports SHALL be written to `.claudboard/audits/`, not `.claude/reports/`

When `/analyse --audit` produces per-service audit reports, the files SHALL be written to `<project>/.claudboard/audits/<service-name>.md`, not to `.claude/reports/`.

The rationale is the same as for the catalog location (`.claudboard/catalog.json`): per-service audit reports are build state — produced by claudboard skills, consumed by humans on an opt-in cadence, never auto-loaded by Claude Code at runtime. Locating them outside `.claude/` makes the architectural distinction visible in the filesystem.

The audit report's internal structure (YAML frontmatter, sections: Service header / What / How / Why / Quality Assessment / Workflow Signals / Watch / Proposed Skills-Rules) is unchanged. Only the file location changes.

The global human-readable summary `claudboard-analysis.md` remains at `<project>/.claude/reports/claudboard-analysis.md` — this file is a thin overview, useful for human review before running `/generate`, and is small enough that its location does not muddy the build-state-vs-runtime-context distinction.

#### Scenario: `/analyse --audit` writes audits to new location
- **WHEN** `/analyse --audit` runs against a monorepo
- **THEN** per-service audit files are at `.claudboard/audits/<svc>.md`, not at `.claude/reports/claudboard-analysis-<svc>.md`

#### Scenario: Global human-readable summary stays in `.claude/reports/`
- **WHEN** any `/analyse` invocation completes
- **THEN** the global summary file is at `.claude/reports/claudboard-analysis.md` regardless of whether `--audit` was passed

#### Scenario: Legacy reports at old location are not moved by `/analyse`
- **WHEN** `/analyse --audit` runs against a project that has pre-existing `.claude/reports/claudboard-analysis-*.md` files (from prior claudboard versions)
- **THEN** the legacy files are not deleted, moved, or modified; new audit output is written to `.claudboard/audits/` alongside

---

### Requirement: Sub-agent dispatch during `--audit` SHALL use Sonnet tier

When `/analyse --audit` fans out per-service analysis to parallel sub-agents (the existing workspace-mode parallelisation protocol, and the monorepo-mode equivalent), the `Agent` tool invocations SHALL specify the Sonnet model tier explicitly.

The rationale: sub-agent work during audit is mechanical (run `discover.sh`, read 5-8 files, fill the per-service report template). This work is well within Sonnet's competence band. Opus tier for sub-agents was the dominant cost driver in the measured craftsphere.cloud baseline ($296 of $417); switching to Sonnet brings that to ~$60-80 with no observed quality degradation on template-fill work.

The orchestrator catalog synthesis stage SHALL remain on the Opus tier — that is where cross-service pattern deduplication and outlier detection happen, and it is the one stage where Opus delivers measurably better synthesis.

#### Scenario: Audit fan-out uses Sonnet sub-agents
- **WHEN** `/analyse --audit` runs on a monorepo with 19 services
- **THEN** each spawned per-service `Agent` invocation explicitly requests Sonnet tier

#### Scenario: Orchestrator synthesis stays on Opus
- **WHEN** `/analyse` (any mode) runs the catalog synthesis stage
- **THEN** the orchestrator is on Opus tier; the synthesis stage is not delegated to sub-agents

---

### Requirement: Per-service report N+1 output applies only to `--audit` mode

The previously-required "N+1 report output" (global report + one per-service report per detected service) SHALL apply only when `/analyse --audit` is invoked. Default `/analyse` produces N=0 per-service reports.

The global human-readable summary report (`.claude/reports/claudboard-analysis.md`) is produced in both modes — its "Per-service deep reports" section is empty / omitted in default mode and populated with cross-links to `.claudboard/audits/<svc>.md` in audit mode.

#### Scenario: Default mode produces zero per-service reports
- **WHEN** `/analyse` (default) runs on a 19-service monorepo
- **THEN** the per-service report count written is 0; the global summary's "Per-service deep reports" section is empty or marked as "Run `/analyse --audit` for per-service detail"

#### Scenario: Audit mode produces one per-service report per detected service
- **WHEN** `/analyse --audit` runs on a 19-service monorepo
- **THEN** 19 per-service audit reports are written to `.claudboard/audits/`, and the global summary's "Per-service deep reports" section lists them
