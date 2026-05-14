## Context

Claudboard's workflow generation today produces a single-repo `feature-workflow/` skill: one config, one branch, one PR, one ticket. That works cleanly for solo repos and even per-service slices of a monorepo. It does not work for **multi-repo workspaces** — directories like `/Users/x/meas/` that contain N independent git repositories side by side, where a typical feature lands across 3-5 repos at once.

The user has been running cross-service work in MEAS by opening a session in one of the affected repos and accepting that the workflow only sees that one repo. Yesterday's solo-datahandler feature worked fine because it didn't span. Most cross-service features touch `common-dto` (shared library) plus 2-3 services plus often `web-ui`, and there is currently no workable session location: the workspace root has no `feature-workflow/` skill at all (it's not a git repo and there's no `.claude/` to discover skills from), while inside any service repo the skill exists but is blind to the others.

`workspace-detection` (archived 2026-05-06) already establishes the analysis-side primitives: workspace mode is detected, per-repo analyses are run, ecosystem context is injected. `feature-workflow-generation` (archived 2026-05-13) added the skill-generation pipeline. This change connects those: the skill-generation pipeline learns about workspace mode, the generated skill itself becomes multi-repo-native, and a pair of bootstrap commands solves the not-in-git problem at the workspace root.

The design touches three concerns that interact: (1) where the shared `.claude/` lives and how it stays in sync across the team, (2) how the generated workflow loops over N repos while honoring per-repo conventions, and (3) how Claude Code's session model — anchored to one cwd, with auto-discovery scoped to that cwd — can cooperate with N peer repos that each have their own `.claude/` worth respecting.

## Goals / Non-Goals

**Goals:**
- Enable cross-service feature work to be initiated and driven from a single workspace-root session.
- Keep the generated workflow's mental model unchanged from today's single-repo model; multi-repo is a "for repo in affected_repos" loop, nothing more exotic.
- Ensure each affected repo's local `.claude/` (rules, memory, skills other than feature-workflow) is honored when work happens in that repo.
- Make the workspace `.claude/` shareable across the team via standard git workflow (clone, branch, PR), not bespoke sync mechanisms.
- Solo-repo features continue to fall out of the same code paths with N=1; no separate skill or mode for them.
- Bootstrap is a one-time per workspace per machine; teammates have a one-line link command.

**Non-Goals:**
- Synchronous PR phase with merge polling and artifact-publication waits. Humans handle merge ordering with the agent's recommendation; Claude does not babysit CI.
- Multiple Jira tickets per cross-service feature. One ticket spans the whole feature, full stop.
- A plugin-shipped feature-workflow skill that updates via plugin version bumps. Consistent with existing claudboard, the skill is generated and team-owned; plugin distribution is out of scope for v1.
- An in-place upgrade flow for the generated skill. Re-generation requires manual deletion, consistent with v1 of the single-repo variant.
- Auto-deletion of pre-existing per-repo `feature-workflow/` skills in service repos. The user removes them in an explicit follow-up step.
- Per-feature artifacts living inside per-repo branches (Option 2 from the explore session). v1 places them in the meta-repo's tracked tree (Option 1).
- Sub-agent cwd re-rooting as the per-repo context-loading mechanism. v1 uses explicit Reads via the read-on-entry contract.
- A mechanism to make per-repo skills like `add-cascade-relation` discoverable by Claude Code's Skill tool from the workspace-root session. v1 reads them as instructions via the same read-on-entry contract.

## Decisions

### Decision 1 — Workspace `.claude/` lives in a child meta-repo nested inside the workspace root, symlinked from `<workspace>/.claude`

Three locations were considered:
- **Workspace root directly** (no git): per-developer drift, no version control, no PR workflow for shared rules. Rejected.
- **Inside one of the service repos** (e.g., common-dto/workspace-claude/): leverages an existing clone but couples a DTO library to workspace orchestration concerns. Future maintainers will hate it. Rejected.
- **Sibling git meta-repo** (e.g., `../meas.cloud.workspace/`): standard git workflow but introduces ambiguity in `setup.sh` path resolution (parent of meta-repo is the parent-of-workspace, not the workspace itself — the script can't unambiguously identify which sibling is the workspace root). Considered but rejected.
- **Child git meta-repo** (e.g., `meas/meas.workspace/`): nested inside the workspace root, single-segment relative symlink (`./meas.workspace/.claude`), `setup.sh` infers workspace root unambiguously as the meta-repo's parent directory. Chosen.

Symlink chosen over rsync/copy because it makes "the meta-repo IS the source of truth" mechanically true: `git status` in the meta-repo reflects everything the team should see. Copy mode exists as a fallback only when symlinks are unavailable (Windows without dev mode, restricted filesystems).

The child layout has one small downside: a teammate `find . -name .git` from the workspace root will see the meta-repo's `.git/` alongside the service repos'. This is acceptable — the meta-repo is a legitimate workspace artifact and naming it `<workspace>.workspace` keeps it grouped at the bottom of any sorted listing. No service repo is named `*.workspace`, so collision is structurally avoided.

### Decision 2 — Bootstrap is automated by claudboard, not documented

The teammate-side flow could plausibly be "clone the meta-repo, run `setup.sh`" without any new claudboard skill. We're adding `/claudboard-workspace-link` anyway because:
- It mirrors the creator-side `/claudboard-workspace-init` for symmetry.
- It can validate the workspace-root prerequisite and produce the same diagnostic if the user is in the wrong directory.
- It's the natural place to introduce the workspace concept to a teammate during onboarding ("here's how you join the workspace").

For `init`, the alternative was "have the user run a series of git commands manually." Rejected because it's a high-blast-radius operation (git init + commit + push + symlink + file moves) that benefits enormously from a single confirmation gate and an idempotent retry path.

### Decision 3 — One workflow skill, multi-repo-native, not a separate "feature-workflow-multi" skill

Two factorings were considered:
- **Two separate skills** (`feature-workflow` for single-repo, `feature-workflow-multi` for workspace): cleaner separation, but doubles maintenance and forces solo-repo features in workspaces to choose a skill.
- **One skill that branches on `WORKSPACE_MODE`**: solo-repo and multi-repo are the same code path with the loop degenerated to N=1 in the solo case. Chosen.

The "for repo in affected_repos" loop is the only structural difference; everything else (Phase 1 spec, Phase 6 PR creation, Phase 7 worklog) generalizes naturally. This is consistent with how `monorepo-support` handled the per-service analysis loop in `claudboard-analyse`.

### Decision 4 — Affected-repos is inferred and confirmed, not declared upfront

User chose inference over upfront declaration in the explore session. The architect-agent has the inputs it needs: the spec text and per-repo analysis reports under `<workspace>/.claude/reports/claudboard-analysis-<repo>.md`. Inference will not always be right, so the orchestrator surfaces the inference with a one-line justification per repo and lets the user adjust.

The fallback for ambiguity is the user gate, not silent failure. If the architect-agent can't decide whether `web-ui` is affected, it includes it with a justification like "web-ui: spec mentions 'visible to user' — include if rendering changes, exclude if it's a server-only field" and the user picks.

### Decision 5 — Per-repo context loading via Read-on-entry, helper script for token economy

Three mechanisms for letting workspace-root agents see per-repo `.claude/`:
- **(i) Read on entry**: agent does explicit Read calls (or a Bash invocation of `load-repo-context.sh <repo>`) before working in that repo. No magic, fully observable, works today. Chosen.
- **(ii) Sub-agent cwd re-rooting**: spawn the sub-agent with cwd set to the repo, hope Claude Code re-discovers per-repo skills/rules at that cwd. Unverified semantics; even if it works for skills, the orchestrator still needs to manage cwd state. Rejected for v1.
- **(iii) Hoist per-repo files into workspace `.claude/`**: pollutes the workspace namespace and loses per-repo locality. Rejected.

The `load-repo-context.sh` helper exists purely for token economy: a single Bash call returning a concatenated bundle is far cheaper than 5-10 Read calls, especially when 4+ repos are in scope.

A consequence of (i): per-repo skills like `add-cascade-relation` are not Skill-tool-discoverable from the workspace-root session. The agent reads their `SKILL.md` files as instructions and follows them inline. This is acceptable for v1 because those skills already work that way conceptually — they're guidance documents the agent honors, not opaque tools it invokes.

### Decision 6 — All PRs opened in parallel; merge order is a recommendation to the human

Considered: synchronous PR phase that waits for PR #1 to merge, the artifact to publish, then opens PR #2 with the dependency bumped. Rejected because:
- Polling for merge state inside Claude is fragile (CI failures, reviewer absence, weekend gaps).
- The artifact-publication step (e.g., `common-dto` Maven publish) is itself an async pipeline that can fail in ways requiring human intervention.
- Humans naturally serialize merges anyway when guided.

The recommendation in the final report should be opinionated and explain the reason for each step (e.g., "common-dto first because consumers need its published artifact to bump"), so the human can deviate intelligently if circumstances change.

### Decision 7 — Per-feature artifacts in the meta-repo, not in per-repo branches

Two valid placements for `<TICKET>/spec.feature`, `plan.md`, and per-repo slices:
- **Option 1 — Meta-repo `.claude/changes/<TICKET>/`**: naturally version-controlled, shareable across teammates working the same ticket, but adds per-feature commits to the meta-repo over time.
- **Option 2 — Per-repo branch slices**: spec lives in JIRA, slice rides inside each repo's feature branch, no shared mutable state. More elegant but JIRA round-tripping for the spec is friction-heavy and the master plan has nowhere natural to live.

Chosen Option 1 because the meta-repo already exists for shared rules/config, the additional per-feature noise is bounded (one directory per ticket), and teammates collaborating on the same ticket genuinely benefit from a shared spec/plan they can both edit. Cleanup of historical change directories can be a future house-keeping concern, not a v1 problem.

### Decision 8 — Existing per-repo `feature-workflow/` skills are NOT auto-deleted

In MEAS, the user already has hand-edited `feature-workflow/` skills inside each service repo. Auto-deleting them during workspace-init would be a high-blast-radius surprise. Instead:
- Init detects them and lists them in the completion report.
- The report includes the explicit removal command the user can run.
- Until removed, the per-repo skills remain available when the user opens a session inside that repo for solo-repo work — providing a graceful transition window where both forms coexist.

The user can decide when to commit fully to the workspace-root model.

## Risks / Trade-offs

[**Risk** — symlinks on Windows] → Detect symlink-creation failure at runtime, fall back to copy-mode bootstrap with a `.copy-mode` marker file and explicit re-sync command in the README. Document the fallback in `setup.sh` so re-runs work. The trade-off is that copy-mode loses the "git status reflects truth" property — devs must re-run `setup.sh` after `git pull` to see updates locally.

[**Risk** — meta-repo path drift across teammates] → `setup.sh` infers paths relative to its own location (workspace root = parent of meta-repo). Any teammate who clones the meta-repo as a child of the workspace root gets a working symlink without manual configuration. The risk degenerates to "teammate clones in the wrong place," handled by `link` validating the workspace-root prerequisite.

[**Risk** — agents forget to load per-repo context] → The contract is documented in every code-touching agent's prompt template, and `load-repo-context.sh` makes compliance a one-line Bash call rather than a multi-step Read fan-out. Lapses will manifest as the agent suggesting changes that violate per-repo conventions; design-reviewer (which also loads context per the contract) catches these in Phase 5.

[**Risk** — per-repo skills like `add-cascade-relation` are invisible to the Skill tool from the workspace-root session] → Accepted v1 trade-off. Agents read them as instructions instead of invoking them as tools. If this proves friction-heavy in practice (e.g., users explicitly want to type `/add-cascade-relation` from a workspace-root session), a v2 mechanism could hoist per-repo SKILL.md descriptors into the workspace skill namespace.

[**Risk** — token cost balloons when 4+ repos × full context loads** → Mitigated by `load-repo-context.sh` bundling Reads, and by the architect-agent declaring implementation order so that not every agent loads every repo's context. The implementation-agent loads the context for the repo it's currently working in, not all of them.

[**Risk** — merge-order recommendation gets stale or wrong] → The recommendation is human-readable and explains its reasoning. If the architect-agent missed a coupling, the human reviewer notices when reading the rationale. The cost of being wrong is "human merges in a slightly suboptimal order," not "system breaks."

[**Risk** — Phase 1 inference of `affected_repos` is wrong] → Surfaced via the user-confirmation gate with one-line justifications per repo. The user can add or remove repos before the plan slices are written. The cost of inference being wrong is one round-trip in Phase 1, not silent miscommitment.

[**Risk** — meta-repo gets noisy with per-feature change directories over time] → Acceptable; per-feature directories are small, mostly text, and can be cleaned up with a future housekeeping command. v1 does not implement cleanup.

[**Risk** — workspace-init's git push step fails on a freshly-created remote without permissions configured] → Push failure leaves the local meta-repo intact with the remote pre-configured; the user can push manually after sorting out auth. No rollback of local state.

[**Risk** — `monorepo-support` (active change) and this change overlap in their treatment of multi-service workspaces] → They are complementary, not overlapping. `monorepo-support` is per-service ANALYSIS in single-git monorepos. This change is multi-repo EXECUTION engine in multi-git workspaces. The detection signal is different (`workspace: true` vs monorepo-with-multiple-services). Both can land independently with no merge conflict in proposal artifacts; some shared template paths may require sequencing during implementation.

## Migration Plan

**For the user's MEAS workspace specifically:**
1. Land this change in claudboard.
2. User runs `/claudboard-workspace-init` from `/Users/LUP1BG/Documents/BoschProjects/meas/` — bootstraps `meas.workspace` as a child directory inside `meas/`.
3. User runs `/claudboard-workflow` from the workspace root — generates the multi-repo skill into the meta-repo.
4. User exercises the workflow on a small synthetic cross-service feature (e.g., add a no-op field to common-dto + reflect in datahandler) to validate the loop end-to-end.
5. User decides per service repo whether to remove the existing hand-edited `feature-workflow/` skill or leave it for solo-repo sessions.

**For other workspaces in the future:**
- `claudboard-analyse` already detects workspace mode.
- `/claudboard-workspace-init` is the next step the analyse completion message will recommend (dispatcher routing addition is part of this change's impact).
- `/claudboard-workflow` then proceeds normally with workspace-mode generation.

**Rollback:** the symlink can be removed with `rm <workspace>/.claude` and the meta-repo deleted with `rm -rf <meta-repo>`. The backup created during init contains the pre-bootstrap workspace `.claude/` for restoration. No state outside these paths is touched.

## Open Questions

- **Q**: Should the architect-agent's affected-repos inference also consider the workspace's `cross-service-graph` (from `workspace-detection`) as an input alongside per-repo analysis reports?
  - **Tentative**: Yes, it's the most authoritative source of inter-repo coupling. The spec for `multirepo-feature-workflow` lists it as one of the inputs but the design of the inference prompt is implementation-time work.
- **Q**: Where do we surface the recommended PR merge order — only in the orchestrator's final terminal output, or also as a comment on each PR / on the Jira ticket?
  - **Tentative**: All three. Final report is essential; PR comment is a low-cost addition during Phase 6; Jira aggregated worklog already includes it per the spec. Implementation can decide whether to include in the PR template body or as a separate comment.
- **Q**: Does the `repos` map in `config.json` need to permit per-repo overrides for git conventions (branch pattern, commit format)?
  - **Tentative**: No in v1. All MEAS repos share branch conventions today, and per-repo overrides add config surface area without clear demand. Defer until a workspace appears that needs it.
- **Q**: Does the meta-repo need its own CI to validate the generated skill files are well-formed?
  - **Tentative**: Out of scope for this change. The team can add CI to the meta-repo independently if they choose.
