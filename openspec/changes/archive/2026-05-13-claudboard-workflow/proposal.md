## Why

Bosch teams across multiple repos (Craftsphere, MEAS workspace, others) want the same opinionated `feature-workflow` skill — ticket → BDD spec → architect plan → implement → review → PR — but the existing skill is hand-edited per repo with ~90% duplicated content and 10% project-specific bits scattered across SKILL.md, agent prompts, and `config.json`. Maintaining N copies by hand drifts fast, and onboarding a new team currently means hand-porting hundreds of lines. claudboard already understands a project deeply enough to substitute the project-specific bits at generation time.

## What Changes

- Add a new peer skill `claudboard-workflow` (sibling to `claudboard-analyse` / `claudboard-generate` / `claudboard-refresh` / `claudboard-techdebt`) that generates a tailored `.claude/skills/feature-workflow/` skill into a target project.
- Ship the `feature-workflow` skill as templates inside `claudboard-workflow/references/feature-workflow.template/` — this is the single source of truth across all repos.
- Templates use HTML comment fences (`<!-- IF X -->...<!-- ENDIF -->`) for capability-gated sections and `{{VAR}}` for substitutions.
- Heavy agents (architect, implementation, sdd-expert) use a layered model: universal text + detected substitutions + pointers into claudboard-generated `.claude/` context + capability blocks + `{{STACK_REMINDERS}}` escape hatch lifted from the analysis report.
- v1 capability blocks: `JIRA_AVAILABLE`, `ADO_AVAILABLE`, `WORKSPACE_MODE`, `CROSS_SERVICE_EDGES`, `SHARED_LIB`, `AUTH_PERIMETER`, `MEMORIES_PRESENT`, `MONGODB`, `JPA`, `KAFKA`.
- v1 ticket host: Jira only. v1 PR host: Azure DevOps only. Both can be stripped if the corresponding MCP isn't configured — generated workflow degrades gracefully with a user-facing warning.
- `config.json` generation: auto-detect ADO org/project from `git remote -v`, inherit shared values from sibling repos in the same workspace if present, ask user for the rest, support "stub with TODO" escape.
- Hard prereq: `/claudboard-workflow` requires that `/claudboard-generate` has run first (CLAUDE.md + `.claude/rules/` present); if missing, prompt the user to run `/generate` first rather than running it inline.
- `/claudboard-refresh` does NOT touch generated `feature-workflow/` artifacts. Upgrade path is opt-in via a future `--upgrade` flag (not in v1 scope).
- Add a "workflow signals" subsection to the `claudboard-analyse` report output that exposes: cross-service edges, shared libraries with consumer count, auth perimeter style, ticket prefix heuristic. Cheap to compute, only consumed by `claudboard-workflow`.

## Capabilities

### New Capabilities
- `feature-workflow-generation`: Generates a tailored `.claude/skills/feature-workflow/` skill into a target project from claudboard analysis output and user-supplied Jira/ADO config. Owns the template rendering pipeline (substitutions + capability-block evaluation), the config.json prompting flow with sibling-repo inheritance, and the MCP-availability detection that gates Jira/ADO functionality.
- `workflow-signals-detection`: Extends `claudboard-analyse` output with a "workflow signals" subsection consumed by `claudboard-workflow`: cross-service edge inventory, shared-library consumer counts, auth perimeter classification, ticket prefix heuristic from commit history.

### Modified Capabilities
<!-- None. claudboard-workflow is purely additive — does not change existing analyse/generate/refresh/techdebt behavior. -->

## Impact

- **New skill directory**: `skills/claudboard-workflow/` with SKILL.md and `references/` (including the full `feature-workflow.template/` tree, block catalog, substitution catalog, Jira config prompts).
- **Dispatcher update**: `skills/claudboard/SKILL.md` gains routing for `/claudboard-workflow` and its trigger phrases.
- **Analysis schema update**: `skills/claudboard-analyse/SKILL.md` and the analysis report template gain the "workflow signals" subsection. Backward-compatible — existing reports still parse, missing subsection treated as empty.
- **Plugin manifest**: `plugin/.claude-plugin/plugin.json` lists the new skill so it ships with the plugin distribution.
- **No source-code changes** to projects being onboarded — claudboard-workflow only writes under `.claude/skills/feature-workflow/`.
- **No changes** to `claudboard-generate` or `claudboard-refresh` behavior beyond mentioning the new skill in the `/generate` completion report's "Next steps" when Jira+ADO MCPs are configured.
