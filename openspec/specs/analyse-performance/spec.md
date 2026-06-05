## MODIFIED Requirements

### Requirement: Workspace mode SHALL share the unified pipeline with monorepo and single-project modes

Workspace mode (detected by per-repo `.git/` directories in subdirs of a non-git parent) SHALL execute the same `/analyse` pipeline as monorepo mode after the detection step. The detection step SHALL set `umbrella_root` once; all subsequent phases SHALL use that path to write outputs.

Default `/analyse` in workspace mode SHALL produce the same artifacts at the umbrella root as default `/analyse` in monorepo mode:

1. `<umbrella_root>/.claudboard/catalog.json` — convention catalog (with `mode: "workspace"`)
2. `<umbrella_root>/.claude/reports/claudboard-analysis.md` — thin human-readable summary
3. `<umbrella_root>/.claude/memories/ecosystem.md` — single umbrella-wide topology file

Default workspace `/analyse` SHALL NOT fan out per-repo sub-agents. The orchestrator picks one reference repo per detected stack (e.g. one Java service, one React MFE) and performs the deep pass inline, producing catalog content representative of the whole workspace.

`/analyse --audit` in workspace mode SHALL fan out per-service Sonnet sub-agents — one per service repo (libraries excluded) — producing per-repo audit reports at `<umbrella_root>/.claudboard/audits/<repo>.md`. The audit output location is identical to monorepo's audit output location.

The prior "workspace-mode behaviour is preserved pending follow-up adaptation" requirement is hereby REPLACED.

#### Scenario: Default workspace `/analyse` on a 14-repo workspace
- **WHEN** `/analyse` (default) runs against MEAS workspace (14 service repos)
- **THEN** the orchestrator picks ~5 reference repos (one per detected stack) and performs a deep pass on each; the catalog is written at `<workspace>/.claudboard/catalog.json` with `mode: "workspace"`; the thin summary is written at `<workspace>/.claude/reports/claudboard-analysis.md`; the umbrella ecosystem.md is written at `<workspace>/.claude/memories/ecosystem.md`; no per-repo sub-agents are spawned; no per-repo report files are written

#### Scenario: `/analyse --audit` on the same workspace
- **WHEN** `/analyse --audit` runs against MEAS workspace
- **THEN** 14 Sonnet-tier sub-agents are spawned (one per service repo, excluding libraries); each writes its per-service audit to `<workspace>/.claudboard/audits/<repo>.md`; the catalog has `from_audit: true`; the thin summary cross-references the audit files

#### Scenario: Workspace mode without bootstrapped meta-repo
- **WHEN** `/analyse` runs in workspace mode AND `<workspace>/.claude` is not a symlink (no `/claudboard-workspace-init` has been run)
- **THEN** the system creates `<workspace>/.claudboard/` and `<workspace>/.claude/reports/` and `<workspace>/.claude/memories/` inline AND writes outputs there AND prints one line at completion: "To share `.claude/` across your team under git, run `/claudboard-workspace-init` next."

---

### Requirement: Default `/analyse` SHALL produce ecosystem.md and dependency graph in all multi-service modes

Default `/analyse` SHALL produce a cross-service dependency graph and an umbrella-wide ecosystem.md in both monorepo mode and workspace mode. (Prior behaviour produced these only in workspace mode.)

Single-project mode SHALL either omit ecosystem.md entirely or produce a degenerate single-section file ("This project has no cross-service dependencies"). Implementation choice; either is acceptable as long as `/generate` and `/refresh` handle the degenerate case without erroring.

The graph is constructed in Phase 1 (orchestrator-side, from the wide-scan grep output that the existing pipeline already produces). It is cheap (no model fan-out) and feeds the ecosystem.md render directly.

#### Scenario: Monorepo default mode produces ecosystem.md
- **WHEN** `/analyse` (default) runs against a monorepo with 19 services
- **THEN** the orchestrator builds a cross-service dependency graph from wide-scan output AND writes a single `<repo-root>/.claude/memories/ecosystem.md` containing one section per service (role / depends-on / used-by / shared-contracts / coupling-warnings)

#### Scenario: Workspace default mode produces ecosystem.md (single file, umbrella root)
- **WHEN** `/analyse` (default) runs against MEAS workspace
- **THEN** a single `<workspace>/.claude/memories/ecosystem.md` is written at the umbrella root; per-repo `<repo>/.claude/memories/ecosystem.md` files are NOT written

#### Scenario: Single-project mode handles the degenerate case
- **WHEN** `/analyse` (default) runs against a single-project repo
- **THEN** either no ecosystem.md is written, OR a short degenerate ecosystem.md is written stating no cross-service dependencies exist; either choice is acceptable

---

### Requirement: Cost-model claims SHALL extend to workspace mode

The `/analyse` SKILL.md "Cost expectations" section SHALL state cost caps for workspace mode. The claimed caps are:

| Mode | Baseline | Cost cap |
|---|---|---|
| `/analyse` default — workspace | MEAS workspace (14 service repos, mixed stack) | ≤ $80 |
| `/analyse --audit` — workspace | MEAS workspace (same) | ≤ $250 |
| `/generate` — workspace | MEAS umbrella catalog | ≤ $25 |
| `/analyse` default — monorepo | craftsphere.cloud (19 services), unchanged baseline | ≤ $50 (regression cap; baseline ~$27) |
| `/analyse --audit` — monorepo | craftsphere.cloud (same), unchanged baseline | ≤ $250 |
| `/generate` — monorepo | craftsphere.cloud catalog, post per-service write removal | ≤ $15 (improvement expected from $11.31 baseline) |
| `/analyse` default — single-project | small repo baseline | ≤ $15 (unchanged) |

If measured cost exceeds any cap at validation time, the proposal SHALL be revised before merge.

#### Scenario: SKILL.md documents workspace caps alongside monorepo caps
- **WHEN** the analyse SKILL.md is loaded
- **THEN** the "Cost expectations" section names the per-mode caps including workspace mode

---

### Requirement: Asymmetric model tiering applies uniformly across modes

The asymmetric model tier (orchestrator on Opus for synthesis, sub-agents on Sonnet for per-service extraction during `--audit`, `/generate` on Sonnet for template-fill) SHALL apply to all three modes — single-project, monorepo, workspace.

Workspace-mode sub-agent dispatch during `--audit` SHALL specify Sonnet tier explicitly in the `Agent` tool call (`model: "claude-sonnet-4-6"` or current Sonnet ID), the same as monorepo-mode `--audit` dispatch.

#### Scenario: Workspace `--audit` sub-agents on Sonnet
- **WHEN** `/analyse --audit` runs in workspace mode and spawns 14 sub-agents
- **THEN** each `Agent` invocation explicitly requests Sonnet tier
