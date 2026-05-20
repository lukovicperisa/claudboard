## Context

The generated `feature-workflow` skill has two MCP touchpoints — a tracker agent for ticket operations and a PR agent for repo operations — and both are currently hard-coded to single backends (Atlassian Jira and Azure DevOps respectively). In practice, Bosch teams operate across at least two trackers (Jira and the in-house Track & Release) and two repo hosts (ADO and GitHub). When the generator emits a Jira-flavoured `jira-agent.md` and the team's environment has a T&R MCP instead, the agent improvises against an unfamiliar tool surface at runtime: worklog calls degrade into comment spam, additive label writes degrade into full overwrites, and ticket creation fails outright because the T&R MCP exposes no create operation. The fix is to expand from 2 to 4 first-class backends across 2 independent dimensions, with explicit per-backend tool maps and explicit refusal (not improvisation) when a backend cannot honour an action.

The Bosch `bosch-jira-mcp` was inspected directly (per `/Users/LUP1BG/Documents/BoschProjects/mcp-servers/bosch-jira-mcp/API.md` v1.0.0). It exposes exactly 6 tools: `jira_search`, `jira_get_issue`, `jira_add_comment`, `jira_transition`, `jira_update_issue`, `jira_get_myself`. It lacks issue creation, worklog, and custom-field writes, and its `jira_update_issue` labels semantics are REPLACE (not Jira's REST `update.labels[{add:...}]` atomic add). These gaps drive the reduced-flow design for `TRACKER_TR`. Extending the MCP to close the gaps is the long-term plan but is out of our control; the design is shaped to enable additional blocks under `TRACKER_TR` when the MCP grows, without restructuring.

The official GitHub MCP is well-understood and used elsewhere in this fleet. ADO and GitHub diverge in several primitives — repository identifier shape (GUID vs `owner/repo` slug), ticket-to-PR linking mechanism (work-item-link field vs `Closes #N` body syntax), pipeline model (manually triggered Pipelines vs event-driven Actions runs), and branch policy model (central policies vs per-rule Branch Protection Rules / Rulesets). The design matches ADO at the intent level, not the surface — same workflow shape, different implementation per block.

Existing in-progress change `expand-comms-detection` (70/102 tasks complete) operates in workflow-signals territory inside the analyse phase and does not overlap with this change's backend wiring; the two can land independently in either order.

## Goals / Non-Goals

**Goals:**
- Expand from 2 to 4 first-class backends across 2 independent dimensions (tracker × repo) with mutual exclusion within each dimension.
- Replace ambiguous flag names (`JIRA_AVAILABLE`, `ADO_AVAILABLE`) with dimensional names (`TRACKER_JIRA`, `TRACKER_TR`, `REPO_ADO`, `REPO_GITHUB`) so a future reader can tell what the flag selects.
- Detect all 4 MCPs at generation time and prompt the user when two MCPs in the same dimension are present.
- Define a per-dimension action contract that all backend agents implement, so the orchestrator dispatches by action name regardless of backend.
- Document T&R v1 limitations as explicit accepted design (not bugs), with each limitation tied to a missing MCP capability so the path forward is obvious.
- Keep the generation contract verbatim-conditional for backend agents (matches existing `jira-agent.md` pattern; better skim-ability than templated branching).

**Non-Goals:**
- Extending `bosch-jira-mcp` with the missing tools. The Bosch MCP team owns that. When tools land, this design enables the additional blocks; we don't ship them now.
- Generic "tracker abstraction" with config-driven tool dispatch. Explicitly rejected earlier in discovery — gray-zone improvisation is what we're getting rid of, not adding more of.
- `gh` CLI as a secondary GitHub path. GitHub MCP is first-class; the existing fallback path is removed.
- Migration tooling for existing generated configs. Projects regenerate; the hand-edited Bosch repo copies are carved out per the existing refresh-exclusion rule.
- Adding Linear, Notion, or any other tracker. Same pattern applies when demand arrives.
- Mixing tracker backends in a single workflow (e.g., Jira for ticket fetch, T&R for comments). Mutual exclusion is enforced at generation time.

## Decisions

### Decision 1: 4 verbatim conditional agent files, not templated branching

The two new agent files (`tr-agent.md`, `pr-agent-github.md`) and the renamed `pr-agent-ado.md` are all verbatim and conditional — written only when their flag is true, and never both members of a mutually-exclusive pair at the same time. Rejected alternative: one templated `tracker-agent.md.template` with `IF TRACKER_JIRA` / `IF TRACKER_TR` branches inside the same file.

Rationale: the existing `jira-agent.md` is already a verbatim conditional file (per `block-catalog.md`). Mixing styles between agents would be inconsistent. Templated branching inside one agent file means every reader has to mentally evaluate two-thirds of the content as inapplicable; verbatim files give the active agent a single coherent prompt. The cost is one extra file per dimension, which is negligible relative to the readability win.

### Decision 2: Flat config schema with discriminator strings

The `config.json` keeps its flat shape and adds two top-level discriminator strings:

```json
{
  "tracker": "jira" | "tr",
  "jira":   { ... },   // present iff tracker = jira
  "tr":     { ... },   // present iff tracker = tr
  "repo":   "ado" | "github",
  "azureDevOps": { ... },  // present iff repo = ado
  "github":      { ... },  // present iff repo = github
  "git": { ... }
}
```

Rejected alternative: discriminated union shape `{ "tracker": { "type": "jira", "config": { ... } } }`. Rejected because the flat shape matches the existing schema; users with hand-edited copies have one less surprise; the discriminator string is enough to know which block to read. Migration cost from flat-to-nested would touch every existing `config.json` reader in the agent set.

### Decision 3: Mutual exclusion enforced at flag-resolution time, not at template-render time

The generator halts before writing any files if both `TRACKER_JIRA` and `TRACKER_TR` (or both `REPO_ADO` and `REPO_GITHUB`) resolve true after detection and any user prompts. Rejected alternative: allow both flags true and let conditional blocks coexist, leaving the orchestrator to pick at runtime.

Rationale: the v1 workflow shape assumes a single tracker and single repo backend. Allowing both runtime-active doubles the surface area of orchestrator phases and creates ambiguous semantics ("which tracker does Phase 7's final comment target?"). Pushing the choice to generation time keeps the generated workflow simple and deterministic.

### Decision 4: T&R v1 reduced flow as accepted design — no runtime improvisation

When the orchestrator calls an action that `TRACKER_TR` does not support (notably `create` and `addWorklog`), the agent returns a structured error. The orchestrator does not retry, does not substitute, does not fold into a different tool. Specifically:

- `create` → user must provide an existing ticket key (Path A only). If they don't, the workflow halts before code work begins.
- `addWorklog` → the orchestrator does not spawn the agent for this action at all under `TRACKER_TR`. Instead, time data is folded into the body of the Phase 7 final summary comment.

Rejected alternatives:
- (a) Fall back to comment-as-worklog when worklog tool is missing. This was exactly the behaviour the user encountered and called out as broken; the comment spam was directly caused by this kind of improvisation.
- (b) Skip the worklog silently. Loses the time-tracking signal entirely; no record of refinement vs implementation time.
- (c) Block T&R workflows from logging time. Equivalent to (b) for the user.

The chosen design — fold time into the final summary comment — preserves the signal in a clean, single-comment form. As a side benefit it aligns with the "one comment summary at end" UX preference surfaced during discovery.

### Decision 5: Labels on T&R via read-modify-write through MCP tools, not a shell script

The `tr-agent.md` `addLabels` action calls `jira_get_issue` → unions current labels with new labels → calls `jira_update_issue` with the merged set. Rejected alternative: write a `tr-add-labels.sh` that mirrors the Jira shell script by reading the bearer token from `~/.config/bosch-jira-mcp/config.json` and hitting the T&R REST API directly with `update.labels[{add:...}]`.

Rationale: the shell-script alternative is more atomic (avoids the RMW race window) but adds a maintenance dependency on the MCP's config-file location. For the feature-workflow use case (single user, single workflow run, low concurrent-write probability), the race window is negligible. The completion report documents the non-atomic semantics so users are aware. If concurrent-write races bite in practice, the script is the v2 promotion path.

### Decision 6: GitHub matches ADO at intent, not surface

ADO and GitHub blocks share orchestrator intent (create PR, link ticket, verify pipeline, respect branch policy) but use different primitives:

| Intent | ADO primitive | GitHub primitive |
|--------|---------------|------------------|
| Identify repo | `azureDevOps.repositoryId` (GUID) | `github.owner` + `github.repo` (slug pair) |
| Link ticket to PR | Work-item-link field on PR | `Closes #N` in PR description body |
| Verify CI run | Pipeline trigger + poll | Actions workflow runs (event-triggered) for branch |
| Branch policy | Central, configurable | Branch Protection Rules / Rulesets, per-rule |

Rejected alternative: force GitHub through an ADO-like surface (e.g., generate a "virtual repositoryId" mapping `owner/repo`). Rejected because the divergences are real and meaningful — pretending they're the same would mislead the agent into making bad choices (e.g., trying to mutate Branch Protection Rules to match ADO policy semantics).

### Decision 7: Detection precedence — ask the user when two MCPs in a dimension are detected

When both Atlassian and Bosch T&R MCPs are detected (entirely plausible at Bosch, since Atlassian is often org-wide), the system prompts the user to choose. Rejected alternatives: project-config-wins (silently picks whichever is in `.mcp.json`); first-detected-wins (order-dependent, surprising); error-and-halt (annoying when both are present for unrelated reasons).

Rationale: asking is one extra question, a few seconds of friction. The alternatives all have surprising silent failure modes. Same logic applies to ADO vs GitHub.

### Decision 8: Capability-flag renaming is part of this change, not a separate one

`JIRA_AVAILABLE` → `TRACKER_JIRA` and `ADO_AVAILABLE` → `REPO_ADO` happen as part of this change. Rejected alternative: separate "rename pass" change preceding this one.

Rationale: the rename is only meaningful in the presence of the parallel flag (`TRACKER_TR`, `REPO_GITHUB`). Doing the rename first creates a temporary state where the new name is in use but conveys no additional information. Doing them together makes the diff coherent: every flag rename and every new flag addition co-occur with the templates and detection logic that need them.

## Risks / Trade-offs

- **[Risk] User confusion about T&R limitations.** Users who expect parity with Jira may file bug reports when worklog or auto-create silently absent. → Mitigation: completion report explicitly lists the v1 T&R limitations and ties each to a missing MCP capability; the `TRACKER_TR` agent returns structured errors (not silent skips) when the orchestrator invokes unsupported actions.

- **[Risk] Bosch T&R MCP changes its tool surface.** The MCP team could add tools, rename existing ones, or change parameter shapes. → Mitigation: the `tr-agent.md` action contract is documented at the spec level; when MCP tools land, we update the agent and lift specific limitations one at a time. The orchestrator dispatches by action name, so changes are localised to the agent file.

- **[Risk] GitHub MCP variability.** The "official" GitHub MCP is the one most commonly used today, but the GitHub MCP ecosystem has multiple servers. Tool names might differ between them. → Mitigation: spec the canonical server name and pin the tool names; if the user runs a different server, the agent fails fast on first invocation rather than silently misbehaving.

- **[Risk] Labels-RMW race on T&R.** Two concurrent workflow runs against the same ticket could both read pre-existing labels, compute disjoint unions, and one write would overwrite the other's additions. → Mitigation: documented limitation; v2 promotion path is a `tr-add-labels.sh` shell script using bearer-token auth.

- **[Trade-off] Mutual exclusion costs flexibility.** A team that genuinely wants to use Jira for tickets but T&R for some other reason in the same workflow cannot. → Accepted: no real use case for this; preserves the single-shape orchestrator.

- **[Trade-off] Verbatim conditional files duplicate boilerplate.** The action-dispatch boilerplate inside `jira-agent.md` and `tr-agent.md` is similar. → Accepted: skim-ability outweighs DRY; the divergences in tool maps make full templating brittle.

- **[Trade-off] BREAKING flag rename.** Anyone reading existing template comments or block-catalog entries with the old `JIRA_AVAILABLE` name will need to learn the new names. → Accepted: ambiguity cost of keeping the old names is higher; rename note in completion report softens the transition.

## Migration Plan

The renaming and schema changes are BREAKING for any project where the generated `feature-workflow/` skill is the source of truth (i.e., where `claudboard-workflow` is the authority on the skill's shape). Projects with hand-edited `feature-workflow/` directories (craftsphere, MEAS) are carved out from `claudboard-refresh` per the existing refresh-exclusion rule; they are unaffected.

**Migration for affected projects:**
1. The owner runs `/claudboard-workflow` to regenerate.
2. The regenerator detects the existing `feature-workflow/` directory and refuses to overwrite (per existing requirement). The user removes the old directory manually.
3. The user re-runs `/claudboard-workflow`. The new shape is generated with the four-flag detection logic and the new config schema.
4. If the project was previously on Jira+ADO, the new generation produces an equivalent shape with `TRACKER_JIRA=true`, `REPO_ADO=true`, the same agent surface, and the new top-level `tracker: "jira"` and `repo: "ado"` discriminators in `config.json`.

The completion report after the new generation includes a "Migrated from legacy flag names" note when it detects an older generated tree had existed, listing the old-to-new flag mapping (`JIRA_AVAILABLE → TRACKER_JIRA`, `ADO_AVAILABLE → REPO_ADO`).

No automated migration script ships in this change.

## Open Questions

- **GitHub MCP canonical server name pin.** The detection spec lists `github-mcp-server` and `@modelcontextprotocol/server-github` as the matched patterns. Confirm the exact name(s) of the "official" / "most common" GitHub MCP at implementation time and pin them precisely in `mcp-detection/spec.md` and `block-catalog.md`. Likely resolves during the first task (detection logic extension) without scope expansion.

- **T&R `transitions` configuration.** The spec assumes T&R workflows have configurable start / success / failure / pause transitions, mirroring the Jira shape. Confirm the canonical Bosch T&R workflow has analogues for these lifecycle states at implementation time; if not, the `transitions` block under `tr:` config may need a different shape.

- **Workspace-mode interaction with mixed-backend repos.** In workspace mode, all repos are assumed to share one tracker and one repo backend. If a Bosch workspace has some service repos on ADO and some on GitHub, the current design picks one for all of them. Confirm whether mixed-backend workspaces exist in practice; if so, the `REPOS_MAP_JSON` shape may need per-repo backend overrides.

- **Whether to add a `--prefer` CLI flag to `/claudboard-workflow`.** Could let users pre-specify which backend wins the precedence prompt non-interactively (useful in scripted regeneration). Out of scope for this change; flag the question for v2.
