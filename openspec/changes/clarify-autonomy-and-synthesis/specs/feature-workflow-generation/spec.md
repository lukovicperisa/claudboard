## ADDED Requirements

### Requirement: Clarification autonomy lever at workflow entry
Generated `feature-workflow` skills SHALL prompt the user to choose a clarification autonomy level at workflow entry, after configuration validation and before Phase 1-pre. The prompt SHALL show the project default (sourced from `config.clarify.defaultAutonomy`, fallback `balanced`) and accept one-letter overrides `a` (autopilot), `b` (balanced), `c` (guided), `d` (manual). The resolved level SHALL be held throughout the workflow and SHALL gate Clarification-phase behavior only.

#### Scenario: Default autonomy presented
- **WHEN** the user invokes `/start-feature` and `config.clarify.defaultAutonomy` is `"balanced"`
- **THEN** the orchestrator SHALL print "Clarification autonomy: balanced — accept [Enter] or override [a / b / c / d]?" and accept the user's response

#### Scenario: Per-invocation override
- **WHEN** the project default is `balanced` and the user responds with `a`
- **THEN** the orchestrator SHALL set the resolved autonomy level to `autopilot` for this invocation only; the config file SHALL NOT be modified

#### Scenario: Override does not persist to next invocation
- **WHEN** the user overrode the autonomy level in a previous invocation of `/start-feature` for this project
- **THEN** the next invocation SHALL still prompt with the unchanged `config.clarify.defaultAutonomy` value; the orchestrator SHALL NOT remember the previous override

#### Scenario: No per-feature autonomy state
- **WHEN** the user runs `/start-feature TICKET-X` and previously ran `/start-feature TICKET-X` with a non-default autonomy level
- **THEN** the orchestrator SHALL NOT read any per-ticket autonomy state from `.claude/changes/<TICKET>/` or elsewhere; the autonomy choice SHALL come solely from the config default and any current-invocation override

#### Scenario: Config missing autonomy field
- **WHEN** `config.json` does not include `clarify.defaultAutonomy`
- **THEN** the orchestrator SHALL default to `balanced` and prompt as if the project default were `balanced`

#### Scenario: Resolved level printed for traceability
- **WHEN** the user has confirmed or overridden the autonomy level
- **THEN** the orchestrator SHALL print a one-line summary describing the chosen level's behavior (e.g., "Clarification autonomy: autopilot — Clarify phase will be skipped; synthesis will print without blocking")

#### Scenario: Autonomy scope is clarification only
- **WHEN** any non-clarification phase runs (Phase 2 branch, Phase 3 implementation, Phase 4 commit, Phase 5 review, Phase 6 PR, Phase 7 finalize)
- **THEN** the autonomy level SHALL have no effect on that phase's behavior; only Phase 1-syn, 1a, and 1a-ws (in workspace mode) SHALL be gated by autonomy

#### Scenario: 1d gate always fires regardless of autonomy
- **WHEN** the resolved autonomy level is `autopilot`
- **THEN** the 1d spec+plan gate SHALL still fire and block for explicit user approval; autonomy MUST NOT bypass the 1d gate

### Requirement: Stated synthesis phase (1-syn) between ticket setup and Clarify
Generated `feature-workflow` skills SHALL include a Phase 1-syn that fires after Phase 1-pre (ticket setup) and before Phase 1a (Clarify scope). The phase SHALL emit a 2-3 paragraph plain-English synthesis of the orchestrator's understanding of the feature, including its proposed slicing when the user has provided multiple ticket keys.

#### Scenario: Single-ticket synthesis emitted
- **WHEN** the user invokes `/start-feature TICKET-123`
- **THEN** the orchestrator SHALL emit a synthesis containing: a 2-3 paragraph plain-English summary of the feature derived from the ticket text, and stated scope boundaries (what's in, what's out — best-effort)

#### Scenario: Multi-ticket synthesis includes proposed slicing
- **WHEN** the user invokes `/start-feature TICKET-1 TICKET-2 ... TICKET-9` (multiple ticket keys)
- **THEN** the orchestrator SHALL emit a synthesis that explicitly states the orchestrator is treating the tickets as one feature, AND lists its proposed slicing (one bullet per slice with a one-line justification)

#### Scenario: Synthesis blocks for confirmation in balanced, guided, manual
- **WHEN** the resolved autonomy level is `balanced`, `guided`, or `manual` AND the synthesis has been printed
- **THEN** the orchestrator SHALL HALT and wait for user input matching `confirm` or `correct: <feedback>`

#### Scenario: Guided mode confirms slicing alongside prose for multi-ticket input
- **WHEN** the resolved autonomy level is `guided` AND the input contained multiple ticket keys AND the synthesis includes both prose summary and proposed slicing
- **THEN** the orchestrator's blocking confirmation SHALL require explicit confirmation of BOTH the prose AND the proposed slicing in a single exchange; the orchestrator SHALL NOT auto-accept slicing in guided mode

#### Scenario: Synthesis prints without blocking in autopilot
- **WHEN** the resolved autonomy level is `autopilot` AND the synthesis has been printed
- **THEN** the orchestrator SHALL continue immediately to Phase 1a without waiting for user input; the synthesis SHALL remain visible in the trace for after-the-fact review

#### Scenario: Correction loop on user feedback
- **WHEN** the user responds to a blocking synthesis with `correct: <feedback text>`
- **THEN** the orchestrator SHALL re-synthesize the feature incorporating the user's feedback verbatim, re-print the new synthesis, and re-block for user input; this loop SHALL continue until the user responds with `confirm`

#### Scenario: Synthesis output becomes the basis for Clarify
- **WHEN** the user confirms the synthesis (or the level is autopilot and synthesis was printed)
- **THEN** the synthesis text SHALL be held as the orchestrator's working understanding and SHALL be passed to subsequent phases as the basis for the BDD spec scope

#### Scenario: Synthesis grounded in project context when available
- **WHEN** Phase 1-syn begins AND any of `CLAUDE.md`, `.claude/memories/ecosystem.md`, or (in workspace mode) per-repo analysis reports under `.claude/reports/` are present
- **THEN** the orchestrator SHALL read those files before synthesizing AND SHALL use the project's documented architecture, vocabulary, and ecosystem topology to ground the synthesis (e.g., naming services that actually exist, flagging "the ticket implies a service named X but no such service is documented")

#### Scenario: Synthesis falls back to ticket text when context absent
- **WHEN** Phase 1-syn begins AND none of `CLAUDE.md`, `.claude/memories/ecosystem.md`, or per-repo analysis reports are present
- **THEN** the orchestrator SHALL synthesize from ticket text alone AND SHALL note in the synthesis output that project context was unavailable

#### Scenario: Ambiguous user correction triggers clarifying question
- **WHEN** the user responds to a blocking synthesis with a `correct: <feedback>` that the orchestrator cannot translate into a concrete revision (e.g., "this is wrong" with no specifics, or a feedback that could apply to multiple parts of the synthesis)
- **THEN** the orchestrator SHALL ask a targeted clarifying question about the feedback BEFORE re-synthesizing; it SHALL NOT guess at the user's meaning and re-synthesize blindly

### Requirement: Enumeration rubric in 1a Clarify for balanced and guided levels
Generated `feature-workflow` skills SHALL implement an enumeration rubric in Phase 1a Clarify when the resolved autonomy level is `balanced` or `guided`. The orchestrator MUST emit, for every dimension in the level's rubric, either `clear: <statement of understanding>` or `unclear: <statement of what is missing>` before asking any question. Every `unclear` dimension MUST become a question to the user.

#### Scenario: Balanced rubric covers eight dimensions
- **WHEN** the resolved autonomy level is `balanced` and Phase 1a begins
- **THEN** the orchestrator SHALL enumerate all eight dimensions: (1) target service/repo, (2) user-facing impact, (3) constraints and related tickets, (4) actors and roles, (5) error and edge cases, (6) authorization requirements, (7) integration/event boundaries, (8) input validation rules

#### Scenario: Guided rubric covers three dimensions
- **WHEN** the resolved autonomy level is `guided` and Phase 1a begins
- **THEN** the orchestrator SHALL enumerate only three direction-level dimensions: (1) target service/repo, (2) change shape (new feature / refactor / bugfix / removal), (3) scope boundary (what's in, what's deferred)

#### Scenario: Every unclear dimension becomes a question
- **WHEN** the orchestrator marks any dimension as `unclear: <description>`
- **THEN** the orchestrator MUST ask the user a question targeted at resolving that specific dimension; it MAY NOT proceed to Phase 1b while any dimension remains `unclear`

#### Scenario: Rubric reasoning visible to user
- **WHEN** the orchestrator emits the rubric in `balanced` or `guided` mode
- **THEN** the full rubric (each dimension with its `clear` or `unclear` mark and the explanatory statement) SHALL be visible in the orchestrator's user-facing output, allowing the user to push back on any `clear` they disagree with

#### Scenario: Rubric re-evaluation after user answers
- **WHEN** the user has answered the orchestrator's questions for `unclear` dimensions
- **THEN** the orchestrator SHALL re-evaluate the rubric in light of the new information; any dimensions that remain `unclear` SHALL generate follow-up questions; the loop SHALL continue until every dimension is `clear`

#### Scenario: Guided defers lower-priority dimensions to downstream hatches
- **WHEN** the resolved autonomy level is `guided` and Phase 1a completes with only the three direction-level dimensions clarified
- **THEN** the orchestrator SHALL accumulate the five deferred dimensions (4-8 from the balanced rubric) as "assumed from ticket text" entries in the 1d gate's assumptions list

### Requirement: Autopilot skips 1a Clarify entirely
Generated `feature-workflow` skills SHALL skip Phase 1a Clarify entirely when the resolved autonomy level is `autopilot`. The orchestrator SHALL proceed directly from Phase 1-syn to Phase 1b (spec writing) using the post-synthesis scope as the clarified scope.

#### Scenario: Autopilot bypasses Clarify
- **WHEN** the resolved autonomy level is `autopilot`
- **THEN** the orchestrator SHALL NOT enumerate any clarification rubric, SHALL NOT ask any clarification questions, and SHALL proceed directly to Phase 1b using the post-synthesis scope as input

#### Scenario: Autopilot accumulates all dimensions as assumptions
- **WHEN** the resolved autonomy level is `autopilot` and Phase 1a is skipped
- **THEN** the orchestrator SHALL accumulate all eight clarification dimensions as "assumed from synthesis" entries in the 1d gate's assumptions list

### Requirement: Manual level uses free-form clarification
Generated `feature-workflow` skills SHALL implement Phase 1a as free-form conversational clarification when the resolved autonomy level is `manual`. The orchestrator SHALL begin by asking the canonical eight clarification questions and SHALL continue asking follow-ups until the user responds with `proceed`.

#### Scenario: Manual asks the canonical eight
- **WHEN** the resolved autonomy level is `manual` and Phase 1a begins
- **THEN** the orchestrator SHALL ask questions covering all eight canonical clarification dimensions, in conversation form (not a structured rubric)

#### Scenario: Manual continues until user proceeds
- **WHEN** the user has answered the orchestrator's initial questions in manual mode
- **THEN** the orchestrator SHALL ask any follow-up questions it identifies, and SHALL NOT proceed to Phase 1b until the user responds with `proceed` (or an equivalent affirmative)

### Requirement: 1a-ws workspace affected-repos confirmation gated by autonomy
In workspace mode, generated `feature-workflow` skills SHALL gate Phase 1a-ws affected-repos user confirmation on the resolved autonomy level.

#### Scenario: Autopilot auto-confirms inferred repos
- **WHEN** the resolved autonomy level is `autopilot` and the architect-agent has inferred the affected repos
- **THEN** the orchestrator SHALL auto-confirm the inferred list without prompting the user and SHALL add the auto-confirmation to the gate assumptions list

#### Scenario: Balanced and manual require explicit confirmation
- **WHEN** the resolved autonomy level is `balanced` or `manual` and the architect-agent has inferred the affected repos
- **THEN** the orchestrator SHALL present the inferred list to the user and SHALL block for an explicit `confirm` or `add <repo>` / `remove <repo>` response

#### Scenario: Guided auto-confirms unless inference is uncertain
- **WHEN** the resolved autonomy level is `guided` and the architect-agent has inferred the affected repos
- **THEN** the orchestrator SHALL auto-confirm IF the architect's justifications contain no hedge language AND the inferred list has five or fewer repos; OTHERWISE the orchestrator SHALL block for explicit user confirmation

### Requirement: 1d gate payload includes assumptions field
Generated `feature-workflow` skills SHALL include an `assumptions` field in the `mcp__bosch__gate_request` payload for Phase 1d. The field SHALL contain a markdown list of decisions the orchestrator made without explicit user input, accumulated across Phase 1-syn, 1a, and 1a-ws.

#### Scenario: Gate payload shape with assumptions
- **WHEN** the orchestrator constructs the Phase 1d gate request
- **THEN** the payload SHALL conform to the shape `{ kind: "spec+plan", payload: { ticket, spec, plan, assumptions } }` where `assumptions` is a markdown-formatted string

#### Scenario: Empty assumptions when nothing inferred
- **WHEN** the resolved autonomy level was `manual` and the user explicitly answered every clarification question with no inferred decisions
- **THEN** the `assumptions` field MAY be an empty string (or contain only "No assumptions made — every decision was user-directed")

#### Scenario: Full assumptions enumeration under autopilot
- **WHEN** the resolved autonomy level was `autopilot`
- **THEN** the `assumptions` field SHALL contain one bulleted entry per clarification dimension, each stating the orchestrator's inferred interpretation derived from the synthesis

#### Scenario: Partial assumptions under guided
- **WHEN** the resolved autonomy level was `guided`
- **THEN** the `assumptions` field SHALL contain bulleted entries for the five deferred dimensions (4-8 from the balanced rubric) and for any workspace-repo auto-confirmation that occurred

#### Scenario: Gate blocking behavior unchanged
- **WHEN** the gate request is sent with any value of `assumptions`
- **THEN** the gate SHALL still block for explicit user `approved` or `rejected` response, exactly as today; the `assumptions` field SHALL NOT short-circuit gate approval

### Requirement: config.json includes clarify.defaultAutonomy field
Generated `feature-workflow` config.json files SHALL include a top-level `clarify` object with a `defaultAutonomy` field. The default value SHALL be `"balanced"`.

#### Scenario: Generated config shape
- **WHEN** the `claudboard-workflow` skill generates a `config.json` for any new project
- **THEN** the file SHALL contain `"clarify": { "defaultAutonomy": "balanced" }` as a top-level field alongside `jira`, `git`, and other existing fields

#### Scenario: Valid autonomy values
- **WHEN** a user edits `clarify.defaultAutonomy` in their `config.json`
- **THEN** the orchestrator SHALL accept any of `"autopilot"`, `"balanced"`, `"guided"`, `"manual"` as valid values; any other value SHALL trigger a warning at workflow entry and fall back to `balanced`

### Requirement: Substitution catalog documents CLARIFY_AUTONOMY_DEFAULT
The `claudboard-workflow` substitution catalog SHALL document the `{{CLARIFY_AUTONOMY_DEFAULT}}` substitution variable, sourced from `config.clarify.defaultAutonomy` with fallback `balanced`.

#### Scenario: Catalog entry present
- **WHEN** a reader inspects `skills/claudboard-workflow/references/substitution-catalog.md`
- **THEN** the catalog SHALL contain an entry for `{{CLARIFY_AUTONOMY_DEFAULT}}` listing its source (`config.clarify.defaultAutonomy`), fallback (`balanced`), and example value (`balanced`)

#### Scenario: Substitution rendered at generation time
- **WHEN** the `claudboard-workflow` skill renders `SKILL.md.template` for a target project
- **THEN** all occurrences of `{{CLARIFY_AUTONOMY_DEFAULT}}` SHALL be replaced with the resolved default value for that project
