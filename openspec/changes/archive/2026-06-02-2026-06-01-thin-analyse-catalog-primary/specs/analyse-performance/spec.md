## MODIFIED Requirements

### Requirement: Default `/analyse` SHALL produce only the catalog and a thin human-readable summary

Default `/analyse` (invoked without flags) SHALL produce exactly two artifacts:

1. `<project>/.claudboard/catalog.json` — the primary structural artifact (see `convention-catalog` capability for full schema)
2. `<project>/.claude/reports/claudboard-analysis.md` — a thin human-readable summary suitable for the user's pre-generate review

Default `/analyse` SHALL NOT produce per-service audit reports under any path. Per-service audit production is the exclusive responsibility of `/analyse --audit` (see `per-service-analysis` spec).

The human-readable summary's size is bounded: typical output 80-150 lines for single-project, 150-250 lines for monorepo. The summary cross-references the catalog and, in monorepo mode, lists the detected services and stacks but does NOT include per-service Watch findings, quality scores, or cross-service Kafka graphs (those are audit-mode outputs).

#### Scenario: Default `/analyse` writes catalog and thin summary
- **WHEN** `/analyse` (default) completes against any project
- **THEN** the produced artifacts are exactly `.claudboard/catalog.json` and `.claude/reports/claudboard-analysis.md` (plus the existing `.claude/memories/ecosystem.md` in workspace mode, unchanged)

#### Scenario: Default mode produces no per-service files
- **WHEN** `/analyse` (default) runs against a 19-service monorepo
- **THEN** no files are written under `.claudboard/audits/` and no `claudboard-analysis-<svc>.md` files are written anywhere

#### Scenario: Summary remains thin
- **WHEN** the human-readable summary is generated for a 19-service monorepo
- **THEN** the file is ≤ 250 lines; per-service Watch findings, per-service quality dimension breakdowns, and cross-service edge graphs are absent or replaced with "See `/analyse --audit` for per-service detail"

---

### Requirement: `/analyse` SHALL accept and route the `--audit` flag

`/analyse` SHALL accept an `--audit` flag in the user's invocation (e.g. `/analyse --audit`, `/analyse <path> --audit`).

When `--audit` is passed, `/analyse` SHALL additionally execute the per-service deep analysis (Phases 1c through 1h per service via Sonnet sub-agents) and write per-service audit reports to `.claudboard/audits/<svc>.md` as defined in the `per-service-analysis` spec.

When `--audit` is NOT passed, the default behaviour (catalog + thin summary, no per-service files) applies.

`--audit` is also a no-op-modifier in single-project mode: a single-project repo has no "per-service" axis. In that mode `--audit` MAY produce a slightly more detailed summary (e.g. richer Watch findings) but no per-service files. Detailed single-project audit content is not specified here; the v1 default is "audit in single-project mode behaves the same as default."

#### Scenario: `--audit` on a monorepo
- **WHEN** `/analyse --audit` runs against a monorepo
- **THEN** the catalog includes `from_audit: true`, per-service audit files are written to `.claudboard/audits/`, and the human-readable summary includes cross-references to those audit files

#### Scenario: `--audit` on a single-project repo (v1)
- **WHEN** `/analyse --audit` runs against a single-project repo
- **THEN** behaviour is identical to default `/analyse` in v1 (catalog + thin summary; no per-service files); the catalog's `from_audit` field may still be set to `true` to signal user intent

#### Scenario: Absence of `--audit` preserves default behaviour
- **WHEN** `/analyse` runs without `--audit`
- **THEN** no audit files are written and `from_audit: false` is set in the catalog

---

### Requirement: Asymmetric model tier SHALL be documented as the performance contract

The `/analyse` SKILL.md SHALL document the model tier assigned to each stage of the pipeline as a performance contract. Tiers are guidance to harness operators and SDK consumers; the skill itself does not enforce model choice (the harness does), but the SKILL.md states the assumed tier so that cost-model claims and performance characteristics are reproducible.

Tier assignments:

| Stage | Tier | Rationale |
|---|---|---|
| `discover.sh` and other bash steps | n/a | Deterministic; no model |
| Sub-agent per-service extraction (during `--audit` fan-out only) | Sonnet | Template-fill on file contents; well within Sonnet's competence |
| Orchestrator catalog synthesis (cross-stack pattern dedup, outlier detection) | Opus | Genuine cross-document synthesis; Opus delivers measurably better outlier detection |
| Orchestrator outlier sweep ("which services deviate from canonical conventions") | Opus | Pattern-recognition work; Opus is materially better |
| Generation orchestrator (in `/generate`, downstream consumer) | Sonnet | Pure template-fill on structured catalog; see `monorepo-generation` spec |

Sub-agent `Agent` invocations during `--audit` fan-out SHALL specify `model: "claude-sonnet-4-6"` (or current Sonnet ID) explicitly in the `Agent` tool call. This is a behavioural requirement on the skill, not just documentation.

Haiku tier is intentionally NOT used in v1. The aggressive-tier option (Haiku for extraction) is a future capability that may be revisited after the conservative tier ships and calibration data accumulates. Calling it out explicitly to avoid silent "let me try Haiku here" drift.

#### Scenario: Sub-agent dispatch specifies Sonnet
- **WHEN** the SKILL.md describes a sub-agent spawn for `--audit` per-service analysis
- **THEN** the spawn directive explicitly names the Sonnet tier (e.g. `Agent({model: "claude-sonnet-4-6", ...})`)

#### Scenario: SKILL.md documents tier table
- **WHEN** the analyse SKILL.md is loaded
- **THEN** it contains a "Model Tiers" section near the top stating the tier per stage and the rationale

#### Scenario: Haiku is not invoked
- **WHEN** `/analyse` runs in any mode
- **THEN** no stage spawns Haiku-tier sub-agents (explicitly excluded in v1)

---

### Requirement: Cost-model claims SHALL be stated and validated against measured baselines

The `/analyse` SKILL.md and the associated proposal/design SHALL state explicit cost claims for the supported invocation modes, grounded in a named baseline. Past performance claims ("$1-2 single-project baseline") that did not name the model tier and the codebase shape silently misled downstream readers.

Stated claims for v1 (validated by tasks 6.1-6.5 against craftsphere.cloud and a single-project repo baseline):

| Mode | Baseline | Cost cap |
|---|---|---|
| `/analyse` default | craftsphere.cloud (19 services, monorepo, Opus-orchestrator + Sonnet-sub-agents) | ≤ $150 |
| `/analyse --audit` | craftsphere.cloud (same) | ≤ $250 |
| `/analyse` default | single-project repo (e.g. GardenMind, ~500 files, asymmetric tier) | ≤ $15 |
| `/generate` consuming catalog | craftsphere.cloud catalog | ≤ $25 |

If measured cost exceeds the cap at validation time, the proposal SHALL be revised before merge; claims SHALL NOT be merged unless validated.

The SKILL.md SHALL link to the change's design.md for full forensic context (the $417 measured baseline, the cost-loss breakdown, the rationale for the catalog-as-primary architecture).

#### Scenario: Cost claims are stated in SKILL.md
- **WHEN** the analyse SKILL.md is loaded
- **THEN** it contains a "Cost expectations" section naming the per-mode caps and the baseline they were measured against

#### Scenario: Merge gate on cost validation
- **WHEN** this change is merged
- **THEN** the measured costs from tasks 6.1-6.5 are appended to design.md as a "Validation" section, confirming all four caps were met

---

### Requirement: Workspace-mode behaviour is preserved pending follow-up adaptation

Workspace mode (multi-repo, each repo has its own `.git/`, reports historically written to `<workspace>/.claude/reports/`) is NOT restructured in this change. The current workspace-mode parallelisation protocol, per-repo report writing, and ecosystem.md generation remain unchanged.

The catalog-as-primary architecture extends naturally to workspace mode (one catalog per repo, plus an optional workspace-level rollup), but the adaptation has open design questions (where does the rollup live? does the per-repo report location also move to `.claudboard/`? what tier do per-repo orchestrators use?) that warrant their own design pass.

A follow-up change will define the workspace-mode catalog adaptation. Until that lands, workspace-mode users continue to see the current behaviour: per-repo reports under `<workspace>/.claude/reports/`, no catalog produced.

#### Scenario: Workspace mode unchanged
- **WHEN** `/analyse` runs against a workspace (detected by per-repo `.git/` in build-root directories)
- **THEN** workspace mode executes as previously defined (per-repo sub-agents, reports under `<workspace>/.claude/reports/`, ecosystem.md per repo); no catalog is produced in v1

#### Scenario: `/generate` against a workspace
- **WHEN** `/generate` runs against a workspace project
- **THEN** the existing workspace-generation behaviour applies (reads per-repo reports); the catalog-first path does not yet apply to workspace mode in v1
