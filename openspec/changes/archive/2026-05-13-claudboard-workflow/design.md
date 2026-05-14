## Context

The `feature-workflow` skill (ticket → BDD spec → architect plan → implement → review → PR) currently exists as hand-edited copies in Bosch repos: `craftsphere.cloud`, `meas.cloud.controller`, `meas.cloud.datahandler`, and the other six MEAS repos. Diff analysis between two of these:

- `scripts/`, `references/claude-pricing.md`, `agents/jira-agent.md` — **identical** across repos. Pure portable.
- `config.json` — **6 lines diff**. Pure data: Jira IDs, Azure DevOps IDs, branch conventions.
- `agents/git-agent.md`, `agents/pr-agent.md`, `agents/spec-reviewer.md`, `agents/design-reviewer.md` — **small diffs**, mostly terminology.
- `agents/sdd-expert-agent.md`, `agents/architect-agent.md`, `agents/implementation-agent.md` — **100-260 line diffs**. These encode project-specific knowledge: package layout, repo topology, persistence stack, cross-service edges, shared-library bump rules, auth perimeter.
- `SKILL.md` — **78 lines diff**, mostly ticket prefix and repo-list terminology.

The user originally targeted Bosch repos but is now distributing claudboard to teams whose project shape is unknown. Hand-curated per-stack variants don't generalize. claudboard already produces deep per-project analysis; this change leverages that output to render a tailored `feature-workflow/` skill on demand.

This is a **cross-cutting addition** (new sibling skill, modified analysis output, dispatcher routing update, plugin manifest entry) and introduces a **new templating runtime** (substitutions + capability-block evaluation) that doesn't currently exist in claudboard. Both factors warrant a design document.

## Goals / Non-Goals

**Goals:**
- Generate a working `feature-workflow/` skill into any project, not just the Bosch ones the templates were authored against.
- Single source of truth for the templates — fixing a bug or improving a prompt benefits all generated copies on the next regeneration.
- Graceful degradation when Jira and/or Azure DevOps MCPs aren't configured: emit a stripped-but-still-useful workflow with a clear warning.
- Workspace-friendly: when 8 sibling MEAS repos all need the same skill, ask for shared values once and inherit per repo.
- Heavy agent quality scales with the richness of claudboard-generated `.claude/` context — the more rules and memories present, the smarter the agents.

**Non-Goals:**
- v1 supports only Jira (ticket host) and Azure DevOps (PR host). GitHub Issues, Linear, GitLab, Bitbucket are out of scope; users get a clear "host not supported" message.
- No upgrade path for already-generated `feature-workflow/` skills in v1. `/claudboard-refresh` skips them. Future `/claudboard-workflow --upgrade` is acknowledged but deferred.
- No inline analysis. `/claudboard-workflow` requires `/claudboard-generate` to have run first; will not call analyse/generate transparently.
- Not a templating engine in the general case — intentionally minimal: only `{{VAR}}` substitution and `<!-- IF X -->...<!-- ENDIF -->` block fences. No loops, no nested conditionals, no expression language.
- No automatic MCP installation. We detect availability and warn; we don't install or configure MCPs on the user's behalf.

## Decisions

### Decision 1: Peer skill, not a phase of `/claudboard-generate`

**Choice**: Create `claudboard-workflow` as a sibling skill, triggered explicitly via `/claudboard-workflow` (and natural-language variants).

**Why**:
- The workflow is heavy and opinionated — auto-proposing it from `/generate` would surprise users who don't run a ticketed development process.
- Generation requires user input (Jira IDs, Azure DevOps repo ID) that doesn't fit `/generate`'s mostly-autonomous flow.
- Mirrors the existing claudboard layout (`-analyse`, `-generate`, `-refresh`, `-techdebt`) and gives `/refresh` a natural reason to skip it.

**Alternatives considered**:
- *Inline phase of `/generate`*: rejected — couples a heavy opt-in workflow to the default onboarding flow.
- *Always-on skill that scaffolds a generic stub*: rejected — without project-specific tailoring it's no better than copy-paste from a sample repo.

### Decision 2: Template syntax = HTML comment fences + `{{VAR}}`

**Choice**: Capability blocks use `<!-- IF CAPABILITY_NAME -->...<!-- ENDIF -->`; substitutions use `{{VARIABLE_NAME}}`.

**Why**:
- HTML comments survive Markdown previews — template files are still readable as drafts when opened in any editor.
- No nesting, no loops, no expression language — keeps the renderer trivial (a few hundred lines of bash or a tiny Python script) and keeps templates auditable by humans who haven't learned a templating DSL.
- Mustache-style `{{VAR}}` is universally recognizable and visually distinct from prose.

**Alternatives considered**:
- *Handlebars with `{{#if}}...{{/if}}`*: rejected — clutters the source view of agent prompts that are meant to be human-readable.
- *Front-matter-driven section toggles*: rejected — pushes the conditionals away from the affected text, making it harder to maintain.

### Decision 3: Heavy-agent layered model

**Choice**: Each heavy-agent template (`architect-agent.md.template`, `implementation-agent.md.template`, `sdd-expert-agent.md.template`) is structured as:

1. **Universal text** — purpose, inputs/outputs, JSON contract, phase structure. Stack-agnostic.
2. **Substitutions** — `{{PROJECT_NAME}}`, `{{REPO_NAME}}`, `{{STACK_NAME}}`, `{{TEST_FRAMEWORK}}`, `{{BASE_PACKAGE}}`, `{{BUILD_CMD}}`, `{{TEST_CMD}}`, `{{LINT_CMD}}`, `{{TICKET_PREFIX}}`.
3. **Pointers into claudboard-generated context** — instructions to read CLAUDE.md, `.claude/rules/*`, `.claude/memories/*` before proposing structure. Heavier the project's context, smarter the agent.
4. **Capability blocks** — fenced sections gated on detected features (workspace, cross-service edges, shared lib, auth perimeter, persistence stack).
5. **`{{STACK_REMINDERS}}` escape hatch** — bullet list lifted verbatim from the analysis report's "Patterns detected" section. Catches the long tail when no named block matches.

**Why**: This delivers "general instructions + project specifics" for both well-known stacks (where layers 4 and 5 carry rich content) and unknown stacks (where layers 1-3 plus the escape hatch still produce a useful prompt).

**Alternatives considered**:
- *Variants catalog (per-stack hand-authored copies)*: rejected by user — doesn't generalize to unknown projects.
- *Pure LLM synthesis from analysis at gen time*: rejected — quality of 250-line dense agent prompts is too risky to synthesize fresh each run; also non-deterministic.

### Decision 4: v1 capability blocks (minimal)

**Choice**: Ship exactly these blocks in v1: `JIRA_AVAILABLE`, `ADO_AVAILABLE`, `WORKSPACE_MODE`, `CROSS_SERVICE_EDGES`, `SHARED_LIB`, `AUTH_PERIMETER`, `MEMORIES_PRESENT`, `MONGODB`, `JPA`, `KAFKA`.

**Why**: Each of these has concrete text in the existing Craftsphere or MEAS feature-workflow agents that justifies the block existing. Aspirational additions (`OPENAPI_PRESENT`, `FEATURE_FLAG_TOOL`, `OBSERVABILITY_STACK`) wait until we hit a real case that needs them — keeps v1 reviewable.

### Decision 5: Symmetric Jira/ADO stripping via `JIRA_AVAILABLE` / `ADO_AVAILABLE`

**Choice**: When the corresponding MCP isn't configured, strip the dependent agent (`jira-agent.md` / `pr-agent.md`), drop dependent SKILL.md phases, simplify branch pattern, and emit a user-facing warning. Generate the rest.

**Why**: Symmetry with how Jira is handled (user request). A workflow without PR creation is "barely a workflow" but still emits commits with consistent branch naming and review discipline — better than nothing, and the warning makes the tradeoff explicit.

**Alternatives considered**:
- *ADO required, Jira optional*: rejected — inconsistent and harder to explain.
- *Both required*: rejected — gates onboarding on MCP setup that may be a separate step in some teams.

### Decision 6: `config.json` input — auto-detect, inherit, ask, escape

**Choice**: Three-tier input flow:
1. **Auto-detect**: parse `git remote -v` for Azure DevOps org + project (URL pattern `dev.azure.com/{org}/{project}/_git/{repo}` or legacy `{org}.visualstudio.com/{project}`).
2. **Inherit**: scan parent directory for sibling repos containing `.claude/skills/feature-workflow/config.json` and offer to inherit shared fields (Jira `cloudId`, `projectKey`, custom field IDs, ADO org+project — but NOT ADO `repositoryId`, which is per-repo).
3. **Ask**: prompt user for whatever's still unresolved. Each prompt offers a "stub with TODO" escape that writes a placeholder and continues.

**Why**: Solves both single-repo onboarding (path 3) and workspace onboarding (path 2 — install on the first MEAS repo, the other 7 inherit). Auto-detection catches the easiest values without asking.

### Decision 7: Hard prereq on `/claudboard-generate`

**Choice**: `/claudboard-workflow` refuses to run unless `CLAUDE.md` and `.claude/rules/` (with at least one rule file) exist. If missing, prints: "Run `/claudboard-generate` first to create the context heavy agents will lean on. claudboard-workflow without that context produces weak prompts."

**Why**: The layered heavy-agent model relies on Layer 3 (pointers into claudboard-generated context) to compensate for unknown stacks. Without rules and CLAUDE.md, Layer 3 points to nothing and the generated agents are noticeably worse. Better to refuse with clear guidance than produce a degraded artifact.

**Alternatives considered**:
- *Soft prereq (warn and proceed)*: rejected — increases the chance users get a poor result and blame the tool. The fix (run /generate first) is one command away.
- *Auto-run /generate*: rejected — /generate has its own confirmation gate; chaining them inline robs the user of review opportunity.

### Decision 8: Renderer location and language

**Choice**: Renderer logic lives **inside the SKILL.md prompt itself** for v1, executed by the agent at runtime — not a separate script. The agent reads each `.template` file, evaluates `<!-- IF X -->` blocks against the resolved capability set, substitutes `{{VAR}}` tokens, writes the rendered file.

**Why**:
- Matches the rest of claudboard's pattern — generation is agent-driven, not script-driven.
- Templates remain plain Markdown — no compile step, no Node/Python dependency.
- Easier to debug: the agent can explain what it rendered and why.
- For v1 there are ~10 capability blocks and ~15 substitutions across ~10 template files. Hand-evaluation by an LLM is cheap and reliable at this scale.

**Alternatives considered**:
- *Bash script with sed-based substitution*: rejected — block evaluation is awkward in pure sed; another language adds a dependency.
- *Node-based renderer with handlebars*: rejected — adds a runtime dependency users would need installed.

If the template count grows past ~20 files or the capability block count past ~25, we revisit and extract a small renderer script. Not a v1 concern.

### Decision 9: Workflow-signals subsection in analysis report

**Choice**: Extend the `claudboard-analyse` report with a "Workflow Signals" subsection containing:
- `cross_service_edges`: list of detected outgoing HTTP/Feign/Kafka/gRPC edges (with target service name when resolvable).
- `shared_libraries`: list of `{name, consumer_count}` for libraries used by 2+ services.
- `auth_perimeter`: one of `gateway` / `in-service-jwt` / `none` / `unknown`.
- `ticket_prefix`: regex match from recent commit messages (e.g., `PROJ-` from `PROJ-1234: subject`), or `null` if no consistent pattern.

**Why**: These signals drive capability-block resolution. Computing them in `analyse` (where we already walk the codebase) is cheap; computing them in `claudboard-workflow` would duplicate scanning. Subsection is additive — existing reports without it are treated as "all signals unknown".

**Backward compatibility**: A missing subsection defaults all signals to `unknown` / empty. Generated workflows degrade gracefully (capability blocks default to off; user gets a "limited signals" warning).

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| Heavy-agent templates drift from real-world Craftsphere/MEAS variants over time, generating worse prompts than the hand-edited originals | Validation eval: render templates against Craftsphere + MEAS analysis reports and diff against the hand-edited copies. Significant divergence flags template debt. Run as part of skill development. |
| Users on stranger projects get a workflow whose heavy agents lean on `.claude/rules/` and `CLAUDE.md` that may themselves be skeleton-quality (from a messy codebase) — agents end up vague | Document this in the user-facing completion report: "feature-workflow agents reference your rules and memories. The richer those are, the better the agent guidance. Consider improving rules first." |
| MCP-availability detection at runtime is fragile (e.g., MCP configured but server offline) | Detect by reading the user's MCP config file (presence-based), not by liveness probe. Document the limitation: "Configured ≠ reachable. If the MCP fails at runtime, the agent will report it." |
| `git remote -v` parsing for Azure DevOps URLs misses non-standard remotes (SSH, mirror remotes) | Fall back to asking the user. The auto-detect is a convenience, not a requirement — prompt path always works. |
| Sibling-repo inheritance picks up stale or wrong config from an abandoned sister repo in the same parent dir | Show inherited values explicitly and require user confirmation before writing. User can edit any field before commit. |
| Stripped Jira/ADO modes produce a workflow so degraded users disable it anyway | Print the warning prominently in the completion report; document that a configured MCP later + `/claudboard-workflow --upgrade` (future) restores full functionality. |
| Adding a "Workflow Signals" subsection to `claudboard-analyse` complicates the report schema | Subsection is appended at the end; existing parsers (none yet, but humans reading the report) ignore unknown sections. Schema change is documented in `claudboard-analyse/SKILL.md`. |
| Template renderer logic-in-prompt produces inconsistent output across runs (LLM non-determinism) | Templates are deterministic by design (substitution and block-eval are unambiguous). Provide a smoke test: render the templates against a fixed analysis report and diff the output against a checked-in golden file. |

## Migration Plan

Not applicable — purely additive change. No existing project is affected; users opt in by running `/claudboard-workflow`. Existing hand-edited `feature-workflow/` skills in Craftsphere/MEAS continue to work; they're not touched by `/claudboard-refresh` and won't be replaced unless the user explicitly invokes the future `--upgrade` flag.

## Open Questions

- Should the v1 `JIRA_AVAILABLE` / `ADO_AVAILABLE` detection check the user-level MCP config (`~/.claude/mcp_servers.json` or similar) only, or also the project-level config? Project-level may shadow user-level; both should probably be checked. Lock the answer during implementation by inspecting the actual MCP config file structure.
- Where does the user-facing warning text for stripped modes live? Probably in `claudboard-workflow/references/jira-config-prompts.md` so it's editable without touching the SKILL.md prompt. Confirm during implementation.
- The future `--upgrade` flag is mentioned in proposal/design but explicitly out of v1 scope. We should still leave a `## Upgrade Path` placeholder section in the generated `feature-workflow/SKILL.md` that says "Generated from claudboard-workflow vX.Y on YYYY-MM-DD. To regenerate against the current templates, see future docs." — gives the eventual upgrade path a hook.
