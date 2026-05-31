## ADDED Requirements

### Requirement: Shared agent preamble inlined at generation time

The template tree SHALL contain `references/agent-preamble.md` — a ~5-line canonical statement of the sub-agent contract covering:

- Scoped tool access (delegated to frontmatter `allowedTools`)
- Action execution from `action` field of INPUT CONTEXT
- JSON result block as the final emission with nothing after it

The generator SHALL inline this snippet into each agent file in the generated `feature-workflow/agents/` directory at render time. The generated agent file SHALL be self-contained — it SHALL NOT contain any `{{INCLUDE}}` directives at runtime, and the orchestrator SHALL NOT read this snippet separately at spawn time.

Each agent file in the template tree SHALL reference the snippet via a `{{INCLUDE references/agent-preamble.md}}` directive (or equivalent generator-recognized mechanism) and SHALL NOT restate the preamble inline.

#### Scenario: Generated agent file is self-contained

- **GIVEN** the generator has rendered `feature-workflow/agents/jira-agent.md` for a project
- **WHEN** the file is inspected
- **THEN** the canonical preamble text (scoped tool access, action execution, JSON result block) appears literally near the top of the file
- **AND** no `{{INCLUDE}}` directive appears anywhere in the file
- **AND** the orchestrator's spawn instruction does not read any external preamble file

#### Scenario: Template tree avoids duplication

- **GIVEN** the template tree at `skills/claudboard-workflow/references/feature-workflow.template/agents/`
- **WHEN** the preamble text is searched literally
- **THEN** it appears once, in `references/agent-preamble.md`
- **AND** each agent `.md` and `.md.template` file references it via the include directive, not by restating

---

### Requirement: Shared agent context-loading snippet

The template tree SHALL contain `references/agent-context-loading.md` — an 8-12 line canonical statement of how a sub-agent loads project context: read `CLAUDE.md`, then `.claude/rules/*.md`, then `.claude/memories/`, then `.claude/skills/` (in priority order), and note missing files in the agent's risks/openQuestions output.

The generator SHALL inline this snippet into agent files that need project context: sdd-expert-agent, architect-agent, implementation-agent, spec-reviewer, design-reviewer.

Each consuming agent file MAY include a short (≤3 line) override note describing what the agent specifically extracts from the loaded context (e.g., "extract domain vocabulary for Gherkin scenarios" for sdd-expert).

#### Scenario: Context-loading snippet inlined in five agents

- **GIVEN** a generated `feature-workflow/agents/` directory
- **WHEN** each agent file is inspected
- **THEN** the canonical context-loading instructions (the four-step priority list) appear literally in sdd-expert-agent.md, architect-agent.md, implementation-agent.md, spec-reviewer.md, design-reviewer.md
- **AND** the wording is identical in all five (modulo per-agent override notes)
- **AND** the other agents (jira-agent, tr-agent, git-agent, pr-agent-ado, pr-agent-github) do NOT contain the context-loading snippet

---

### Requirement: Shared reviewer protocol

The template tree SHALL contain `references/reviewer-protocol.md` containing the shared scaffolding used by both spec-reviewer and design-reviewer:

- "What you receive" (INPUT CONTEXT shape)
- "Workspace-mode: load per-repo context first"
- "Step 1: Load context" (read changed files via git-agent get-changed-files)
- "Step 2: Read all relevant inputs"
- "Step 5: Compile findings" (file, line, severity, type, description, suggested fix)
- "Determining passed/failed" (passed = no Critical findings)
- "Output JSON shape"

The generator SHALL inline this snippet into `spec-reviewer.md` and `design-reviewer.md` at render time.

Each reviewer file SHALL retain its rubric-specific content unchanged:
- spec-reviewer: Step 3 (verify each BDD scenario) and Step 4 (check for scope drift)
- design-reviewer: Step 3 (apply rule checks per .claude/rules/) and Step 4 (general quality review)

#### Scenario: Reviewers share scaffolding but keep their rubrics

- **GIVEN** generated `feature-workflow/agents/spec-reviewer.md` and `design-reviewer.md`
- **WHEN** both files are inspected
- **THEN** Steps 1, 2, 5, "Determining passed/failed", and "Output" sections are byte-identical (modulo whitespace and per-reviewer headings)
- **AND** Step 3 in spec-reviewer is rubric-specific ("verify each scenario is implemented and tested")
- **AND** Step 3 in design-reviewer is rubric-specific ("apply rule checks per .claude/rules/")

---

### Requirement: AC template consumed from shared reference

The `## Goal / ## Acceptance Criteria / ## Context` ticket-description template SHALL live in `references/ticket-description-template.md` (introduced by the sibling change `slim-feature-workflow-orchestrator`).

The following agent files SHALL reference this template instead of inlining it:
- `jira-agent.md` — `create` action and `updateDescription` action
- `architect-agent.md` — "Plan structure" section's Acceptance Criteria placement subsection

#### Scenario: Template appears in exactly one source

- **GIVEN** the template tree
- **WHEN** the markdown pattern `## Goal\n.*## Acceptance Criteria\n.*## Context` is grep'd
- **THEN** it appears only in `references/ticket-description-template.md`
- **AND** does NOT appear inlined in `SKILL.md.template`, `jira-agent.md`, or `architect-agent.md.template`

---

### Requirement: Architect Plan structure section reduced to headings

The `architect-agent.md.template` "Plan structure" section SHALL list only the required headings of `execution-plan.md` with one-line guidance per heading. It SHALL NOT restate full example bodies for each contract.

Phase C (Define software contracts) remains the authoritative source for each contract's body content. The Plan structure section references Phase C by name and instructs the agent to follow Phase C templates exactly for contract bodies.

The reduction target is from ~140 lines to ~60-80 lines for this section.

#### Scenario: Plan structure is headings-only

- **GIVEN** the slimmed `architect-agent.md.template`
- **WHEN** the "Plan structure" section is inspected
- **THEN** each contract listed under "Software contracts" appears as a heading + one-line guidance (e.g., "endpoint contracts for each operation"), not as a full example body
- **AND** the section is at most 80 lines
- **AND** the agent's produced `execution-plan.md` still contains every required heading (verified by eval)

---

### Requirement: Per-action error output shape stated once per agent

In each multi-action agent (jira-agent, tr-agent, git-agent, implementation-agent, architect-agent, pr-agent-github), the standard error/failure output shape SHALL be stated once near the top of the file (after Configuration). Per-action sections SHALL show only the success output shape and reference the standard error shape with `action: "<this action>"`.

This SHALL NOT apply to action-specific error shapes that genuinely differ (e.g., a `transition` action's "no matching transition" error has a unique payload — it stays inline).

#### Scenario: Standard error shape stated once

- **GIVEN** the slimmed `jira-agent.md`
- **WHEN** the file is grep'd for the standard error JSON shape (`{ "action": ..., "error": ... }`)
- **THEN** the full shape appears in exactly one "Standard error output" section near the top
- **AND** per-action sections reference it with one-liner notes like *"On failure: emit the standard error shape with `action: 'addWorklog'`."*
- **AND** action-specific error shapes (the transition error with `availableTransitions` payload) remain inline at the relevant action

---

### Requirement: Per-agent size reduction targets

The generated agent files SHALL meet the following minimum size reductions (measured by line count vs the pre-change baseline):

| Agent | Pre-change | Target | Min reduction |
|-------|-----------|--------|---------------|
| architect-agent.md | ~700 lines | ~520 lines | 20% |
| implementation-agent.md | ~500 lines | ~410 lines | 15% |
| jira-agent.md | ~520 lines | ~430 lines | 15% |
| git-agent.md | ~500 lines | ~430 lines | 12% |
| sdd-expert-agent.md | ~290 lines | ~240 lines | 15% |
| tr-agent.md | ~360 lines | ~280 lines | 20% |
| spec-reviewer.md | ~280 lines | ~190 lines | 25% |
| design-reviewer.md | ~230 lines | ~160 lines | 25% |
| pr-agent-github.md | ~370 lines | ~310 lines | 15% |
| pr-agent-ado.md | ~200 lines | ~165 lines | 15% |

If any agent falls below the minimum reduction, additional consolidation is required before merge.

If any agent loses a documented capability (an action stops working, a JSON result schema changes shape, an MCP tool is no longer invoked correctly), the change is reverted for that agent.

#### Scenario: All agents meet their reduction targets

- **GIVEN** the slimmed template tree and the size-reduction table above
- **WHEN** the generator renders agents for a craftsphere-equivalent config and line counts are measured
- **THEN** every agent's generated file is at most the "Target" value from the table
- **AND** the cumulative reduction across all 10 agents is at least 800 lines

---

### Requirement: No runtime behavioral regression in any agent

The slimmed agent files SHALL drive the same external sub-agent behavior as the pre-change versions:

- Every documented `action` value still executes successfully
- JSON result blocks parse correctly with the same field names and types
- MCP tool invocations still happen at the same points with the same parameter shapes
- Generated artifacts (execution-plan.md from architect, BDD spec files from sdd-expert, code from implementation, findings JSON from reviewers, PRs from pr-agents, tickets from tracker agents) have the same shape as before

#### Scenario: Eval run confirms agent behavior is preserved

- **GIVEN** a Bosch-style repo and a pre-recorded baseline run from the verbose agents
- **WHEN** the same feature is run end-to-end against the slimmed agents
- **THEN** every agent spawn returns a parseable JSON result block
- **AND** the architect's execution-plan.md contains the same set of headings as the baseline
- **AND** the implementation-agent produces code that respects the same conventions (constructor injection, log-or-throw, naming) as the baseline
- **AND** the reviewers produce findings JSON with the same structure as the baseline
- **AND** the tracker agents post tickets/comments with the same shape as the baseline
