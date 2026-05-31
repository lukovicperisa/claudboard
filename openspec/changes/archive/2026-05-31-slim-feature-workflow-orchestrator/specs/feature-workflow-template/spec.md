## ADDED Requirements

### Requirement: Agent invocation contract stated once

The generated `SKILL.md` SHALL contain an "Agent invocation contract" section near the top of the document (after the agent architecture section, before error handling). This section SHALL state, exactly once:

- The canonical spawn shape: `prompt = <full contents of agents/<agent>.md> + "\n\nINPUT CONTEXT:\n" + <json>`
- The rule that `allowedTools` is taken from the per-call site's listed tool list
- The shorthand notation `→ spawn <agent>` with `action`, `input`, and `tools` fields used at per-call sites
- The wrapping rule: when `gate=mcp`, every spawn is preceded by `mcp__bosch__agent_start` and followed by `mcp__bosch__agent_complete`

Per-call spawn sites in the document SHALL use the shorthand notation. They SHALL NOT repeat the full `Tool: Agent / Parameters: / prompt: |` block.

#### Scenario: Spawn site uses shorthand

- **GIVEN** the orchestrator reaches Phase 1d gate approval and needs to log refinement work
- **WHEN** the SKILL.md instructs the spawn
- **THEN** the instruction reads as `→ spawn jira-agent  action: "addWorklog"  input: { ticketKey, timeSpent, comment: "Requirement refinement work" }  tools: [mcp__atlassian__addWorklogToJiraIssue]` (or equivalent shorthand)
- **AND** the SKILL.md does NOT contain a verbatim `Tool: Agent / Parameters: / prompt: | / <paste...>` block at that site

#### Scenario: Orchestrator reads the contract and constructs the call correctly

- **GIVEN** an orchestrator (Sonnet 4.6) has read the "Agent invocation contract" section and a downstream `→ spawn` shorthand
- **WHEN** it issues the Agent tool call at runtime
- **THEN** the actual Agent invocation contains the full agent.md contents in the prompt followed by the INPUT CONTEXT JSON
- **AND** the `allowedTools` list matches the `tools` list at the shorthand site exactly

---

### Requirement: gate=mcp lifecycle signals stated once

The generated `SKILL.md` SHALL contain a "Lifecycle signals (gate=mcp only)" subsection within the Gate mode block. This subsection SHALL state, exactly once, that when `gate=mcp` the orchestrator emits:

- `phase_start` at the entry of each phase and `phase_complete` at exit
- `agent_start` before every Agent spawn and `agent_complete` after each returns
- `checkpoint_start` and `checkpoint_complete` around each Phase 3 checkpoint (including the baseline check as `num: 0`)

When `gate=interactive`, all lifecycle signals SHALL be omitted entirely.

The SKILL.md SHALL NOT contain inline `**If gate=mcp:** Call mcp__bosch__phase_start/agent_start/checkpoint_start/...` reminders at individual phase, spawn, or checkpoint sites. The orchestrator infers the emission from the canonical rule.

The "Hard contract" rules in the Gate mode block (NEVER use AskUserQuestion in mcp mode; NEVER call `mcp__bosch__*` in interactive mode) SHALL remain inline, unchanged.

#### Scenario: Inline gate=mcp reminders removed

- **GIVEN** the generated `SKILL.md` from a project with any tracker and any repo backend
- **WHEN** the file is grep'd for `\*\*If gate=mcp:\*\* Call mcp__bosch__phase` or `\*\*If gate=mcp:\*\* Call mcp__bosch__agent` or `\*\*If gate=mcp:\*\* Call mcp__bosch__checkpoint`
- **THEN** all matches occur only within the "Lifecycle signals (gate=mcp only)" canonical section
- **AND** no matches appear in Phase 1-pre, 1b, 1c, 1d, 2, 3a, 3b, 4a-c, 5a, 5b, 6a, 6b, or 7a-c

#### Scenario: Orchestrator emits the right signals under gate=mcp

- **GIVEN** an orchestrator running with `gate=mcp` and having read the lifecycle signals subsection
- **WHEN** it enters Phase 3 and runs the baseline + checkpoint 1 in parallel followed by checkpoints 2 through N sequentially
- **THEN** at runtime it emits, in order: `phase_start(3)`, `checkpoint_start(0)`, `agent_start(impl, baseline)`, `agent_start(impl, checkpoint 1)`, `agent_complete(impl)` (×2), `checkpoint_complete(0)`, `checkpoint_complete(1)`, then for each remaining checkpoint N: `checkpoint_start(N)`, `agent_start(impl, "checkpoint N")`, `agent_complete(impl)`, `checkpoint_complete(N)`, finally `phase_complete(3)`

---

### Requirement: Phase 7 cost analysis unified across trackers

The generated `SKILL.md` SHALL define the Phase 7 cost-analysis logic — Python token-cost script, per-phase cost computation rules, and cost-comment markdown template — exactly once. Both `TRACKER_JIRA` and `TRACKER_TR` paths SHALL use the same definition.

The unification MAY be achieved by either:
- A capability-flag compound condition (e.g., `<!-- IF TRACKER_JIRA || TRACKER_TR -->`); OR
- A shared `references/phase7-cost-analysis.md` fragment that is inlined by the generator at render time for both tracker paths.

Only the tracker-specific leaf operations SHALL branch:
- `TRACKER_JIRA`: emits `addWorklog` in Phase 7a before the cost comment in 7b
- `TRACKER_TR`: skips worklog (T&R v1 limitation); folds the implementation-elapsed time into the 7b comment body
- Both: post the cost comment via the tracker's `addComment` action in 7b; transition to success state in 7c

The final-report-to-user blocks at the end of Phase 7 MAY remain tracker-specific (different reminder text about worklog availability is acceptable).

#### Scenario: No Python cost script duplication

- **GIVEN** the generated `SKILL.md` from a project with any tracker
- **WHEN** the file is grep'd for `PYEOF` (the Python heredoc closing marker used in the cost script)
- **THEN** there are at most two `PYEOF` matches (one open, one close) in the entire generated file
- **AND** the cost-comment markdown template (containing `## AI-Assisted Development — Cost Analysis`) appears at most once

#### Scenario: Both tracker paths invoke the same script

- **GIVEN** the template tree contains the shared cost-analysis logic
- **WHEN** the generator renders `SKILL.md` for a `TRACKER_JIRA` project AND separately for a `TRACKER_TR` project
- **THEN** the Python cost-script body (between `python3 - <<'PYEOF'` and `PYEOF`) is byte-identical in both rendered outputs
- **AND** the cost-comment markdown template structure is byte-identical in both rendered outputs

---

### Requirement: Phase 1-pre ticket setup shares structure across trackers

The generated `SKILL.md` SHALL describe the Phase 1-pre "Path A — fetchAndPrepare" structure once, with tracker-specific MCP tool invocations branching only at leaf steps. The "compute additive labels" subsection (resolveAreaLabel + `aiLabels ∪ resolvedAreaLabel`) SHALL be stated once and reused by both tracker paths.

Path B (auto-create) SHALL remain `TRACKER_JIRA`-only. The `TRACKER_TR` Path B section SHALL be a brief halt-with-message block (one short paragraph) explaining the v1 limitation.

#### Scenario: Label resolution stated once

- **GIVEN** the generated `SKILL.md` from a project with any tracker
- **WHEN** the file is grep'd for `resolveAreaLabel` definition or the `aiLabels ∪` notation
- **THEN** the definition appears in the canonical "Additive label resolution" section, not in Phase 1-pre per-tracker subsections
- **AND** Phase 1-pre's Path A subsection references the canonical section instead of restating it

---

### Requirement: Error handler shares taxonomy across trackers

The generated `SKILL.md` SHALL define the recoverable/non-recoverable failure taxonomy once, with the failure-transition tool invocation branching only at the leaf step (Jira-MCP for `TRACKER_JIRA`, bosch-jira-mcp for `TRACKER_TR`).

The "always surface error and halt" guidance SHALL be stated once.

#### Scenario: Taxonomy stated once

- **GIVEN** the generated `SKILL.md` from a project with any tracker
- **WHEN** the document is inspected for the recoverable/non-recoverable taxonomy table
- **THEN** the table appears in exactly one error-handler section
- **AND** the tracker-specific failure-transition tool invocation (`mcp__atlassian__transitionJiraIssue` vs `mcp__bosch-jira-mcp__jira_transition`) is the only tracker-branched element of the error handler

---

### Requirement: 1a Clarify rubric stated once

The 8-dimension clarification rubric SHALL appear exactly once in the generated `SKILL.md` — at the start of Phase 1a or in a dedicated reference block. The autonomy-level subsections (`autopilot`, `balanced`, `guided`, `manual`) SHALL reference the canonical list and describe their behavior with respect to it, instead of restating the full 8-dimension enumeration.

The 3-dimension guided rubric MAY remain stated explicitly within the `guided` subsection given its distinct shape.

#### Scenario: Rubric not restated three times

- **GIVEN** the generated `SKILL.md`
- **WHEN** the 8-dimension list (Target service / User-facing impact / Constraints / Actors / Error cases / Authorization / Integration / Validation) is searched
- **THEN** the full enumeration appears at most once in the document

---

### Requirement: AC template lives in a shared reference file

The `## Goal / ## Acceptance Criteria / ## Context` ticket-description template SHALL live in `references/ticket-description-template.md` within the generated `feature-workflow/` directory.

The generated `SKILL.md` SHALL reference this file at description-composition sites (Path A label updates and Path B initial description) instead of inlining the template.

The tracker-specific AC-placement note (Jira: AC goes to custom field; T&R: AC inlined in description body) SHALL be documented within `references/ticket-description-template.md` once, not duplicated in SKILL.md.

#### Scenario: Template lives in references/

- **GIVEN** a project generated by `/claudboard-workflow`
- **WHEN** the generated `feature-workflow/` directory tree is inspected
- **THEN** `references/ticket-description-template.md` exists
- **AND** the SKILL.md instructs the orchestrator to read it at description-composition sites
- **AND** SKILL.md does NOT contain a `## Goal\n...\n## Acceptance Criteria\n...\n## Context` markdown block inlined at those sites

---

### Requirement: Generated SKILL.md size reduction target

For a single-tracker, single-repo-backend, non-workspace project, the generated `SKILL.md` SHALL be no larger than 1100 lines (~35% reduction from the pre-change baseline of ~1700 lines).

This SHALL be measured by running `/claudboard-workflow` against a craftsphere-equivalent config (TRACKER_JIRA + REPO_ADO + no workspace) and counting lines in the produced `SKILL.md`.

If the actual reduction is below 30%, the change is incomplete and additional consolidation is required before merge.

#### Scenario: Craftsphere-equivalent generation hits target

- **GIVEN** the slimmed template tree
- **WHEN** `/claudboard-workflow` runs against a single-repo config with `TRACKER_JIRA + REPO_ADO + no workspace`
- **THEN** the generated `SKILL.md` is at most 1100 lines
- **AND** if it exceeds 1100 lines, the change is not ready for merge

---

### Requirement: No runtime behavioral regression

The slimmed `SKILL.md` SHALL drive the same external orchestrator behavior as the pre-change template:

- Same agents spawned in the same order with the same INPUT CONTEXT shapes
- Same `mcp__bosch__*` lifecycle signals emitted under `gate=mcp` (verified by signal count and ordering against a recorded baseline run)
- Same Phase 7 ticket comment shape (the cost-analysis output is byte-identical to a recorded baseline, modulo timestamps and dollar values)
- Same gate semantics in both `gate=mcp` and `gate=interactive` modes

#### Scenario: Eval run reproduces baseline orchestration

- **GIVEN** a Bosch-style repo and a pre-recorded baseline workflow run from the verbose template
- **WHEN** the same feature is run end-to-end against the slimmed template under `gate=mcp`
- **THEN** the bosch UI receives the same set and order of `mcp__bosch__*` lifecycle signals as the baseline
- **AND** every Agent spawn has the same `name`, `action`, and `allowedTools` as the corresponding baseline spawn
- **AND** the Phase 7 ticket comment shape matches the baseline (allowing variance in actual cost numbers and timestamps)
