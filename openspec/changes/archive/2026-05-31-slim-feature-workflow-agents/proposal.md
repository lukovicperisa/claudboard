## Why

The 10 agent files in the generated `feature-workflow/agents/` directory total ~3400 lines. They are loaded once per spawn into a fresh sub-agent context — and the architect-agent (879 lines, Opus model) and implementation-agent (570 lines, Sonnet, 5-10 spawns per workflow) dominate per-run cost. Rough per-workflow sub-agent prompt cost: **$0.30-0.50** in worst-case-no-caching, plus TTFT (time-to-first-token) latency on every spawn that scales with prompt size.

Investigation found six structural patterns of repetition and over-detail that can be trimmed without losing signal:

1. **Shared agent preamble** — every agent restates "You are a scoped sub-agent / you have access to X / do not attempt other tool calls / execute the action / emit a JSON result block, nothing else after it" (~25-40 lines per agent, ~250-300 lines across the corpus). The frontmatter's `allowedTools` already enforces tool scope.
2. **"Read CLAUDE.md and rules first" duplicated in 4-5 agents** — sdd-expert, architect, implementation, spec-reviewer, design-reviewer each have a 30-65 line "load project context" section with slightly different wording (~150 lines total).
3. **Architect's Plan structure overlaps with Phase C contracts** — Phase C teaches contract content; Plan structure restates the contract headings with example bodies. ~60-80 redundant lines.
4. **AC template (`## Goal / ## Acceptance Criteria / ## Context`) appears in three places** — SKILL.md, jira-agent, architect-agent. Three sources of truth = three places to drift.
5. **Spec-reviewer and design-reviewer share structure** — same Step 1 / 2 / 5 / Determining passed/failed / Output sections, near-identical wording. ~80-120 lines of shared scaffolding.
6. **Per-action output JSON schemas have repeated failure shapes** — several agents define an "Output (success)" and "Output (failure)" block per action; the failure shape is often constant across actions within the agent. ~30-50 lines per agent.

The bet is the same as the orchestrator proposal: sub-agents (Opus and Sonnet) can follow a stated pattern without per-instance reminders. The runtime savings are real because each sub-agent spawn is an independent API call; smaller prompts mean lower input cost AND lower TTFT.

## What Changes

- **NEW `references/agent-preamble.md`** in the template tree — a 5-line canonical statement of the subagent contract (scoped tool access, INPUT CONTEXT execution, JSON result block as final emission). The generator inlines it at render time into the head of each agent file. The per-agent verbose preamble (~25-40 lines) is removed; each agent file's opening now just states what's unique to that agent (its job, its specific MCP server if any).

- **NEW `references/agent-context-loading.md`** — canonical 8-12 line "load project context" snippet that the generator inlines into agents that need it (sdd-expert, architect, implementation, spec-reviewer, design-reviewer). Each agent retains a 3-line "what to extract for this agent's job" override; the bulk of the context-loading instructions are stated once.

- **NEW `references/reviewer-protocol.md`** — shared Step 1 / 2 / 5 / Determining-passed-failed / Output structure for the two reviewer agents. The generator inlines it into both reviewers. Per-reviewer files retain only the rubric-specific Step 3 ("apply spec checks" vs "apply design rules") and Step 4.

- **NEW `references/ticket-description-template.md`** (introduced by the sibling `slim-feature-workflow-orchestrator` change; this change updates the agent files to reference it). Both `jira-agent.md` and `architect-agent.md`'s Plan structure section reference this file instead of restating the `## Goal / ## Acceptance Criteria / ## Context` template inline. The tracker-specific AC-placement note (Jira: custom field; T&R: inline) lives once in that reference file.

- **TIGHTENED architect-agent Plan structure** — reduced from full skeleton with example bodies to skeleton headings only. Phase C remains the authority for each contract's content. Saves ~60-80 lines.

- **TIGHTENED per-action output JSON schemas** — each agent states its standard "Output (error)" shape once at the top instead of repeating it per action. Per-action blocks show only the success shape and reference the standard error shape.

- **NO change to runtime contract.** Agents still receive `action` and INPUT CONTEXT, execute the action, and emit a JSON result block. MCP tool surfaces and allowedTools are unchanged.

- **NO new capability flags or substitution variables.** The dedup is structural; the generator's existing concat-and-substitute machinery is enough.

- **Sub-agent prompt caching is the wildcard.** If the harness caches agent.md prefixes across spawns within a session, dollar savings are smaller but TTFT improvements remain. Either way, lower TTFT is a UX win.

## Capabilities

### Modified Capabilities

- `feature-workflow-template`: The template tree SHALL contain shared snippet files (`references/agent-preamble.md`, `references/agent-context-loading.md`, `references/reviewer-protocol.md`, `references/ticket-description-template.md`). The generator SHALL inline these snippets at render time into each agent file that uses them. The generated agent files SHALL be self-contained at runtime (no runtime concatenation, no extra Read calls at spawn time). Total per-agent line counts SHALL drop by an average of 25-30% with no loss of agent capability.

## Impact

- **Files modified:**
  - `skills/claudboard-workflow/references/feature-workflow.template/agents/architect-agent.md.template`
  - `skills/claudboard-workflow/references/feature-workflow.template/agents/implementation-agent.md.template`
  - `skills/claudboard-workflow/references/feature-workflow.template/agents/sdd-expert-agent.md.template`
  - `skills/claudboard-workflow/references/feature-workflow.template/agents/spec-reviewer.md.template`
  - `skills/claudboard-workflow/references/feature-workflow.template/agents/design-reviewer.md.template`
  - `skills/claudboard-workflow/references/feature-workflow.template/agents/git-agent.md.template`
  - `skills/claudboard-workflow/references/feature-workflow.template/agents/jira-agent.md`
  - `skills/claudboard-workflow/references/feature-workflow.template/agents/tr-agent.md`
  - `skills/claudboard-workflow/references/feature-workflow.template/agents/pr-agent-ado.md`
  - `skills/claudboard-workflow/references/feature-workflow.template/agents/pr-agent-github.md`

- **Files added:**
  - `skills/claudboard-workflow/references/feature-workflow.template/references/agent-preamble.md`
  - `skills/claudboard-workflow/references/feature-workflow.template/references/agent-context-loading.md`
  - `skills/claudboard-workflow/references/feature-workflow.template/references/reviewer-protocol.md`
  - (`references/ticket-description-template.md` is added by the sibling change `slim-feature-workflow-orchestrator`; this change consumes it.)

- **Generator behavior change:** The `claudboard-workflow` skill SHALL inline the new shared snippet files into each agent file at render time. The output agent file is self-contained — no runtime references to shared snippets. This is a generation-time concat, not a runtime concat.

- **Generated-artifact behavior change at runtime:** None functional. Same actions, same INPUT CONTEXT, same MCP tool surface, same JSON result-block shapes. The runtime contract between orchestrator and sub-agents is unchanged.

- **Estimated runtime savings per workflow run:**
  - architect-agent prompt: ~879 → ~640 lines (~27% smaller) × 1-3 Opus spawns
  - implementation-agent prompt: ~570 → ~440 lines (~23% smaller) × 5-10 Sonnet spawns
  - jira-agent + tr-agent + git-agent prompts: ~25% smaller × Haiku spawns
  - Total per-run sub-agent prompt cost (worst-case-no-caching): $0.30-0.50 → $0.22-0.36
  - TTFT improvement per spawn: ~20-30%, most noticeable on Opus spawns (architect, sdd-expert)

- **Eval requirement:** One full-workflow eval against a Bosch-style repo (craftsphere or MEAS) before declaring victory. Specific checks: (a) each agent action completes successfully with the slimmer prompt; (b) JSON result blocks parse correctly; (c) live testing in implementation-agent still works (no convention regressions from the trimmed coding-standards section).

- **Coordination with sibling change:** This change depends on `references/ticket-description-template.md` from `slim-feature-workflow-orchestrator`. Land that change first OR coordinate so both changes' template-reference adds happen together.

- **Out of scope (explicit):**
  - Extracting a dedicated `cost-analyst-agent` (deferred — separate explore session)
  - Reducing the architect-agent's Phase C contract templates (the IF-gated stack-specific contracts are signal, not bloat)
  - Reducing the implementation-agent's live-testing patterns (necessary detail)
  - Changes to `block-catalog.md`, `substitution-catalog.md`, or capability-flag resolution
  - Changes to scripts under `scripts/`

- **Upgrade path:** Per the documented v1 caveat, projects that already ran `/claudboard-workflow` will not auto-pick up the slimmer agent files. Users wanting the slimmer agents remove `.claude/skills/feature-workflow/` and re-run.

- **Rollback:** If eval surfaces a regression in any agent's behavior, revert this change. The orchestrator-side slim (sibling change) can stand or fall independently.
