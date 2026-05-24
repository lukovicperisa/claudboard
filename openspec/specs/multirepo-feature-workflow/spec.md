## Requirements

### Requirement: Single multi-repo-aware skill at workspace root
In workspace mode, the `feature-workflow/` skill SHALL exist at exactly one location: the workspace meta-repo's `.claude/skills/feature-workflow/`, accessible at `<workspace>/.claude/skills/feature-workflow/` via the bootstrap symlink. Per-repo `feature-workflow/` skills SHALL NOT be generated.

#### Scenario: Workspace mode generation
- **WHEN** `/claudboard-workflow` is invoked in workspace mode (analysis report has `workspace: true`)
- **THEN** the system SHALL generate the multi-repo skill into the meta-repo's `.claude/skills/feature-workflow/` and SHALL NOT generate any per-repo `feature-workflow/` skills

#### Scenario: Existing per-repo skills are not deleted
- **WHEN** workspace bootstrap and multi-repo skill generation complete on a workspace whose service repos contain pre-existing hand-edited `feature-workflow/` skills
- **THEN** those per-repo skills SHALL NOT be modified or deleted; the completion report SHALL list them under "Existing per-repo feature-workflow skills detected — remove manually if you want this workspace's skill to be the only one." with the explicit removal command

### Requirement: config.json shape with per-repo map
The generated workspace `config.json` SHALL include a `repos` map keyed by repo name, where each entry contains the per-repo settings that differ across the workspace (Azure DevOps `repositoryId`, optional repo-local overrides). Shared fields (`jira.cloudId`, `jira.projectKey`, `jira.urlBase`, `jira.customFields`, `azureDevOps.organization`, `azureDevOps.project`, `git.branchTypes`, `git.branchPattern`, `git.ticketRegex`) SHALL remain top-level.

#### Scenario: Standard workspace config shape
- **WHEN** the workspace contains 3 service repos
- **THEN** the generated `config.json` SHALL have `jira`, `azureDevOps` (with shared `organization` and `project`), and `git` at the top level, plus a `repos` object with 3 keys, each containing at minimum the per-repo `azureDevOps.repositoryId`

#### Scenario: Repo with no Azure DevOps presence
- **WHEN** a workspace repo has no Azure DevOps remote configured (e.g., a local-only sandbox repo accidentally included)
- **THEN** the generation flow SHALL exclude that repo from the `repos` map and SHALL warn the user during the confirmation gate

### Requirement: Phase 1 — affected_repos inference and user gate
The orchestrator's Phase 1 SHALL produce a written specification (BDD or equivalent), then the architect-agent SHALL infer the list of affected repos from the spec text combined with the workspace's analysis reports, and the orchestrator SHALL surface the inferred list to the user for confirmation or adjustment before continuing.

The architect-agent's inference SHALL be based on: the spec text, each repo's analysis report under `<workspace>/.claude/reports/claudboard-analysis-<repo>.md`, and any cross-service edge information in the workspace ecosystem rules. The inference output SHALL include a one-line justification for each affected repo.

#### Scenario: Architect infers multi-repo feature
- **WHEN** the spec describes adding a new field that flows from a shared DTO library through two services to the UI
- **THEN** the architect-agent's plan SHALL list the DTO library, the two services, and the UI as affected repos, each with a one-line justification (e.g., "common-dto: DTO change is the schema source", "datahandler: persists the new field", "controller: exposes via REST", "web-ui: renders in detail view")

#### Scenario: User confirms affected repos
- **WHEN** the orchestrator presents the inferred list and the user accepts it
- **THEN** the orchestrator SHALL proceed to Phase 2 with the confirmed `affected_repos` list

#### Scenario: User adjusts affected repos
- **WHEN** the user removes or adds a repo to the inferred list
- **THEN** the orchestrator SHALL re-prompt the architect-agent to re-write the per-repo plan slices for the adjusted list before continuing

#### Scenario: Solo-repo feature
- **WHEN** the architect-agent infers exactly one affected repo
- **THEN** the orchestrator SHALL still surface the one-line justification, accept user confirmation, and proceed with N=1; the per-repo loop in subsequent phases SHALL execute normally with one iteration

### Requirement: Per-repo plan slices
The architect-agent SHALL produce per-repo plan slices in addition to the master plan. Each slice SHALL be written to `<workspace>/.claude/changes/<TICKET>/slices/<repo>.md` and SHALL contain only the checkpoints and context relevant to that repo.

The master plan at `<workspace>/.claude/changes/<TICKET>/plan.md` SHALL include a top-level "Affected repos" section with the confirmed list and a "Recommended PR merge order" section (see PR ordering requirement).

#### Scenario: Per-repo slice is self-contained
- **WHEN** the implementation-agent reads `<workspace>/.claude/changes/MEAS-1234/slices/datahandler.md`
- **THEN** the slice SHALL contain enough context (relevant excerpt of the spec, the checkpoints scoped to datahandler, references to the DTO contract) for the agent to execute without needing to load the master plan or other repos' slices

#### Scenario: Master plan lists slices
- **WHEN** the master plan is written
- **THEN** it SHALL include a "Per-repo slices" section that links each affected repo to its slice file path

### Requirement: Per-repo context loading contract
Every code-touching sub-agent (architect-agent, implementation-agent, design-reviewer, spec-reviewer) SHALL load the affected repo's local context before performing any work in that repo. The contract is:

1. Read `<workspace>/<repo>/.claude/CLAUDE.md` if present.
2. Read all `<workspace>/<repo>/.claude/rules/*.md` files.
3. Read `<workspace>/<repo>/.claude/memory/MEMORY.md` if present.
4. List `<workspace>/<repo>/.claude/skills/`, then Read each `SKILL.md` file under that directory.
5. Treat all loaded contents as authoritative for that repo.

The system SHALL provide a helper script `<feature-workflow-skill>/scripts/load-repo-context.sh <repo>` that performs steps 1-4 in a single Bash invocation and prints the concatenated content with file-path delimiters, so agents can use one Bash call instead of N Read calls.

#### Scenario: Agent enters a repo for the first time in this run
- **WHEN** the implementation-agent begins work on its first checkpoint in `datahandler`
- **THEN** the agent SHALL invoke `scripts/load-repo-context.sh datahandler` (or equivalent Read fan-out) and SHALL include the loaded content in its working context before reading any source files

#### Scenario: Per-repo skill SKILL.md is loaded
- **WHEN** `meas.cloud.datahandler/.claude/skills/add-cascade-relation/SKILL.md` exists
- **THEN** the implementation-agent SHALL Read it and treat its instructions as guidance applicable when the current checkpoint matches the skill's scope; the agent does NOT invoke the skill via the Skill tool (which would not see it from the workspace-root session)

#### Scenario: Repo has no `.claude/` directory
- **WHEN** the affected repo has no `.claude/` directory at all
- **THEN** the helper script SHALL exit successfully with a one-line note "<repo>: no local .claude/ context" and the agent SHALL proceed with workspace-level rules only

#### Scenario: Helper script handles missing optional files
- **WHEN** the affected repo has `.claude/rules/` but no `CLAUDE.md` and no `memory/`
- **THEN** the helper script SHALL print only the rules content (with file-path delimiters) and SHALL NOT error on the missing files

### Requirement: Per-repo phase loop
Phases 2 (branch), 3 (develop), 4 (commit), and 5 (review) SHALL iterate over `affected_repos`. The orchestrator SHALL execute each phase per repo before moving to the next phase, OR (where parallelism is safe) execute the phase concurrently across repos. Phase 3 (develop) SHALL respect the implementation order declared by the architect-agent (typically: shared libraries first, then consumers, then UI).

Within each per-repo phase iteration, the orchestrator SHALL pass the repo identifier to the relevant sub-agent and the sub-agent SHALL operate exclusively against that repo's working tree.

#### Scenario: Phase 2 creates branches in all affected repos
- **WHEN** Phase 2 runs with `affected_repos = [common-dto, datahandler, controller, web-ui]`
- **THEN** the git-agent SHALL create the same branch name (per `git.branchPattern`) in each of the four repos, in any order, and SHALL report success per repo

#### Scenario: Phase 3 respects implementation order
- **WHEN** the architect-agent's plan declares implementation order `common-dto → [datahandler, controller] → web-ui`
- **THEN** Phase 3 SHALL run common-dto's checkpoints to completion first, then datahandler and controller (which may run in either order or concurrently), then web-ui last

#### Scenario: Phase 4 commits per repo
- **WHEN** Phase 4 runs after Phase 3 completion
- **THEN** the git-agent SHALL stage and commit changes in each affected repo's branch independently, producing one commit per repo

#### Scenario: Phase 5 reviews per repo
- **WHEN** Phase 5 runs
- **THEN** the design-reviewer and spec-reviewer SHALL execute per repo, each loading per-repo context first per the per-repo context-loading contract

### Requirement: Sub-agent repo argument
Every code-touching sub-agent (git-agent, implementation-agent, architect-agent, design-reviewer, spec-reviewer, pr-agent) in the workspace variant SHALL accept a `repo` argument identifying which workspace repo to operate on. The argument SHALL be passed in the sub-agent's prompt envelope by the orchestrator.

The sub-agent SHALL prefix all filesystem operations with `<workspace>/<repo>/`. Bash commands that depend on the working directory SHALL be invoked as `(cd "<workspace>/<repo>" && <command>)` or via the `--repo` flag of the workflow's `lib.sh` helpers.

#### Scenario: git-agent receives repo argument
- **WHEN** the orchestrator spawns git-agent for branch creation in datahandler
- **THEN** the git-agent's prompt SHALL include `repo: datahandler`, the agent SHALL run `(cd <workspace>/datahandler && git checkout -b <branch>)`, and the result block SHALL include the repo identifier alongside the branch name

#### Scenario: Implementation-agent receives repo argument
- **WHEN** the orchestrator spawns implementation-agent for checkpoint 2 in controller
- **THEN** the prompt SHALL include `repo: controller`, the agent SHALL load controller's local context before any work, and all file Reads/Edits SHALL use absolute paths under `<workspace>/controller/`

### Requirement: Phase 6 — parallel PR creation with merge-order recommendation
Phase 6 SHALL open one pull request per affected repo, in parallel (no waiting for any PR to merge). After all PRs are created, the orchestrator SHALL print a final report listing every PR URL together with a recommended merge order and a one-line reasoning for that order.

The orchestrator SHALL NOT poll for PR merge status, SHALL NOT trigger artifact publication, and SHALL NOT block on inter-PR dependencies. Merge ordering is the human reviewer's responsibility, informed by the recommendation.

#### Scenario: All PRs opened
- **WHEN** Phase 6 runs with `affected_repos = [common-dto, datahandler, controller, web-ui]`
- **THEN** the pr-agent SHALL be spawned four times (one per repo), each producing one PR; the orchestrator SHALL collect all four PR URLs

#### Scenario: Recommended merge order printed
- **WHEN** all PRs are open
- **THEN** the final report SHALL contain a "Recommended merge order" section listing the PRs in the order the architect-agent declared during Phase 1, with a one-line rationale per step (e.g., "1. common-dto — must merge first so consumers can bump dependency. 2. datahandler, controller — parallel, no inter-dependency. 3. web-ui — depends on gateway being live with new field.")

#### Scenario: Single-repo PR creation
- **WHEN** Phase 6 runs with `affected_repos = [datahandler]` (solo-repo feature)
- **THEN** the pr-agent SHALL be spawned once and the final report SHALL list the single PR with no merge-order section

#### Scenario: PR creation fails for one repo
- **WHEN** the pr-agent fails to create a PR for one repo (e.g., transient ADO error)
- **THEN** the orchestrator SHALL report the failure for that repo, continue creating the remaining PRs, and present the final report listing successful PRs plus the failed repo with retry instructions

### ~~Requirement: Phase 7 — single-ticket worklog aggregation~~ — REMOVED

**Reason**: The aggregated worklog body (per-repo PR URLs + merge-order summary folded into the Jira worklog comment) produced bloated, noisy entries in Jira's worklog log view, and duplicated information that already lives in the PR descriptions. The new policy is that Jira worklog comments are a fixed terse one-line label only (enforced by the `tracker-backends` capability's MODIFIED "Jira backend full-flow capability set" requirement) regardless of single-repo vs multi-repo mode.

**Migration**: The single-ticket-per-feature invariant is preserved (the orchestrator still creates exactly one Jira ticket per feature, and that ticket still receives the worklog entries from Phase 1 and Phase 6/7). What changes is the worklog comment body: it is now `"Requirement refinement work"` (Phase 1) or `"Implementation work"` (Phase 6/7) in both single-repo and multi-repo runs. Per-repo PR URLs are accessible via the PR descriptions on the host (Azure DevOps / GitHub). The "Recommended merge order" remains in the orchestrator's final report to the user (see the existing "Phase 6 — parallel PR creation with merge-order recommendation" requirement) and SHALL NOT be re-posted into Jira. No data is lost; it simply lives in the appropriate surface.

### Requirement: Per-feature artifact placement
Phase 1 outputs (`spec`, `plan.md`, per-repo `slices/<repo>.md`) SHALL be written to `<workspace>/.claude/changes/<TICKET>/`. Because `<workspace>/.claude` is a symlink to the meta-repo, these files SHALL be naturally version-controlled in the meta-repo and shareable across teammates working the same ticket.

The orchestrator SHALL NOT write per-feature artifacts into individual service repos (Option 2 from explore session is deferred).

#### Scenario: Phase 1 writes to meta-repo via symlink
- **WHEN** Phase 1 completes for ticket MEAS-1234
- **THEN** the spec, plan, and slices SHALL exist at `<workspace>/.claude/changes/MEAS-1234/...` (resolving through the symlink to the meta-repo's tracked tree)

#### Scenario: Per-feature artifacts NOT written to service repos
- **WHEN** Phase 1 completes
- **THEN** no `.claude/changes/MEAS-1234/` directory SHALL be created inside any individual service repo's `.claude/`

### Requirement: WORKSPACE_MODE flag drives skill template variant
The `WORKSPACE_MODE` capability flag (defined by `feature-workflow-generation`) SHALL gate the multi-repo template variants of every generated workflow file: SKILL.md phases, agents that take a `repo` argument, scripts that prefix paths with the repo, and the workspace `config.json` shape.

When `WORKSPACE_MODE` is true at generation time, the multi-repo variants SHALL be rendered. When false, the existing single-repo variants SHALL be rendered (no change to current behavior).

#### Scenario: WORKSPACE_MODE true
- **WHEN** the analysis report has `workspace: true`
- **THEN** `/claudboard-workflow` SHALL render the multi-repo SKILL.md, multi-repo agent variants, the workspace config.json shape, and `scripts/load-repo-context.sh`; SHALL NOT generate any per-repo `feature-workflow/` skills

#### Scenario: WORKSPACE_MODE false
- **WHEN** the analysis report has `workspace: false` (single repo or monorepo)
- **THEN** `/claudboard-workflow` SHALL render the existing single-repo SKILL.md and agents into the project's `.claude/skills/feature-workflow/` per the existing `feature-workflow-generation` requirements

### Requirement: No upgrade path in v1
The multi-repo `feature-workflow/` skill SHALL have no in-place upgrade path in v1, consistent with the single-repo variant. Re-running `/claudboard-workflow` on a workspace where the skill already exists SHALL refuse to overwrite and instruct the user to remove the directory manually before regenerating.

#### Scenario: Re-running workflow on existing skill
- **WHEN** `/claudboard-workflow` is invoked on a workspace whose meta-repo already contains `.claude/skills/feature-workflow/`
- **THEN** the system SHALL refuse with "feature-workflow skill already exists at <path>. Upgrade flow is not available in v1; remove the existing skill manually if you want to regenerate." and stop
