## Why

Claudboard already detects workspace mode (multiple independent git repos under a parent dir, established by `workspace-detection`) and generates per-repo `feature-workflow/` skills via `claudboard-workflow`. But the generated skill is single-repo by construction: one config, one branch, one PR. In a real workspace like MEAS (8 repos), cross-service features are common and the current shape forces an impossible choice — start the session at workspace root and have no `/start-feature` available, or start it inside one service repo and lose visibility into the others. Compounding this, the workspace root is not a git repo, so any shared `.claude/` placed there is per-developer and drifts across the team.

This change makes the workspace itself a first-class feature-workflow target: one multi-repo-aware skill at workspace root, bootstrapped through a tracked meta-repo so the team shares a single source of truth.

## What Changes

- **NEW: workspace meta-repo bootstrap** — two new claudboard commands, `/claudboard-workspace-init` and `/claudboard-workspace-link`, that create (or link to) a sibling git repo holding the workspace `.claude/` and symlink it into the workspace root. Bootstrap runs before `/generate` or `/claudboard-workflow` in workspace mode.
- **NEW: multi-repo feature-workflow** — the generated `feature-workflow/` skill in workspace mode is multi-repo-native: Phase 1 infers `affected_repos` from the spec and surfaces detection to the user; Phases 2-5 loop over affected repos; Phase 6 opens all PRs in parallel with a recommended merge order; Phase 7 aggregates worklogs to a single Jira ticket. Solo-repo features fall out as N=1.
- **NEW: per-repo context-loading contract** — every code-touching agent (architect, implementation, design-reviewer, spec-reviewer) MUST read each affected repo's `.claude/CLAUDE.md`, `rules/`, `memory/MEMORY.md`, and skill `SKILL.md` files (excluding feature-workflow itself, which no longer exists per-repo) before working in that repo. Backed by a `scripts/load-repo-context.sh` helper for token economy.
- **MODIFIED: `feature-workflow-generation`** — generation branches on `workspace: true`. In workspace mode, the skill is generated into the workspace meta-repo's `.claude/skills/feature-workflow/` (multi-repo variant) and per-repo feature-workflow generation is suppressed. In single-repo mode, behavior is unchanged.
- **NEW: per-feature artifact placement** — Phase 1 writes shared spec + plan + per-repo slices to `<workspace>/.claude/changes/<TICKET>/` (which lives in the meta-repo, naturally version-controlled).
- **NEW: `WORKSPACE_MODE` capability flag in workflow** — already partially defined in `feature-workflow-generation` for substitution purposes; this change extends it to drive the multi-repo template variant of the generated skill itself.
- **BREAKING (workspace mode only)**: in workspace mode, `claudboard-workflow` no longer generates per-repo `feature-workflow/` skills. Existing hand-edited per-repo skills are NOT auto-deleted by `init`; the user removes them in an explicit follow-up step.
- **OUT OF SCOPE**: synchronous PR phase that waits for merges + artifact publish (deliberately not implemented — humans handle merge ordering with the agent's recommendation); plugin-shipped vs meta-repo-generated trade-off for the skill (v1 picks generated, consistent with current claudboard); upgrade path for the multi-repo skill (v1 has none, consistent with v1 of claudboard-workflow); per-feature artifact Option 2 (per-repo branch slices) — deferred unless Option 1 proves problematic; `/refresh` integration for the multi-repo skill (refresh-exclusion already covers feature-workflow/ in v1).

## Capabilities

### New Capabilities
- `workspace-meta-repo-bootstrap`: Bootstrap a sibling git repo to hold the workspace `.claude/` and symlink it into the workspace root. Covers `/claudboard-workspace-init` (creator flow with confirmation gate, migration, optional remote, idempotency) and `/claudboard-workspace-link <remote-url>` (teammate flow). Includes safety guards (refuse if workspace root is itself a git repo, refuse on name collision, backup existing contents) and Windows symlink fallback.
- `multirepo-feature-workflow`: The multi-repo-aware feature-workflow execution model. Covers `affected_repos` inference + user-confirmation gate, per-repo phase loop (branch/develop/commit/review), parallel PR creation with merge-order recommendation, single-ticket worklog aggregation, and the per-repo context-loading contract (read repo's `.claude/` before any work).

### Modified Capabilities
- `feature-workflow-generation`: Generation branches on `workspace: true`. In workspace mode, the skill is generated into the meta-repo (single instance, multi-repo variant) and per-repo generation is suppressed; in single-repo mode, unchanged. Adds requirements for the multi-repo template variant, the workspace `config.json` shape (with `repos: { ... }` map), and prereq ordering (`/claudboard-workspace-init` must run first when `workspace: true`).

## Impact

- **NEW skills**:
  - `skills/claudboard-workspace-init/SKILL.md` — bootstrap flow for the first team member
  - `skills/claudboard-workspace-link/SKILL.md` — teammate bootstrap from a remote URL
- **NEW templates**:
  - `skills/claudboard-workflow/references/feature-workflow.template/` gains a workspace variant (or its existing files learn `<!-- IF WORKSPACE_MODE -->` blocks for the multi-repo branches; choice of factoring lives in design.md)
  - `scripts/load-repo-context.sh` template — bundled per-repo context reader
  - workspace `setup.sh` template — idempotent symlink bootstrap with copy-mode fallback
- **MODIFIED skills**:
  - `skills/claudboard-workflow/SKILL.md` — branches on `workspace: true`, requires meta-repo presence in workspace mode, generates into meta-repo path
  - `skills/claudboard/SKILL.md` (dispatcher) — adds `claudboard-workspace-init` and `claudboard-workspace-link` to its routing table
  - `.claude-plugin/plugin.json` — registers the two new skills
- **MODIFIED references**:
  - `skills/claudboard-workflow/references/block-catalog.md` — extend `WORKSPACE_MODE` with the multi-repo workflow blocks it now gates
  - `skills/claudboard-workflow/references/substitution-catalog.md` — add tokens for repo map (`{{REPOS_MAP_JSON}}`, etc.)
- **NO impact** on `claudboard-analyse`, `claudboard-refresh`, or `claudboard-techdebt` — workspace-detection already established the analysis-side primitives; refresh-exclusion of `feature-workflow/` already in place.
- **Coordination with existing changes**: complementary to active `monorepo-support` (that change is about per-service ANALYSIS in single-git monorepos; this change is about the EXECUTION engine in multi-git workspaces). No conflict, no supersession. Both can land independently.
- **Real test target**: MEAS workspace at `/Users/LUP1BG/Documents/BoschProjects/meas/` — 8 repos, `workspace: true` in analysis report, ecosystem documentation already present at `meas/.claude/rules/` and per-service `.claude/` dirs. End-to-end validation: bootstrap meta-repo, generate multi-repo skill, run a synthetic cross-service feature touching common-dto + datahandler + controller.
