## ADDED Requirements

### Requirement: Interactive checkpoints must actually pause the CLI
Generated `feature-workflow` skills SHALL pause the CLI at every documented interactive checkpoint (autonomy prompt, synthesis HALT, manual-mode `proceed`, blocker recovery, gate confirmation, any other "wait for user" point) using one of exactly two mechanisms: (1) calling `AskUserQuestion`, or (2) ending the orchestrator's turn immediately after printing the prompt with no further tool calls and no further text in the same response. The template SHALL state this two-mechanism rule once, in a top-level "Halt mechanics" subsection, and SHALL reference it from every later HALT/wait/prompt instruction.

#### Scenario: Autonomy prompt pauses via AskUserQuestion
- **WHEN** the orchestrator reaches the clarification-autonomy entry prompt and `AskUserQuestion` is available
- **THEN** the orchestrator SHALL call `AskUserQuestion` with options `Accept default (<default>)`, `a — autopilot`, `b — balanced`, `c — guided`, `d — manual` and SHALL NOT call any other tool in the same response

#### Scenario: Autonomy prompt fallback ends the turn
- **WHEN** the orchestrator reaches the autonomy prompt and `AskUserQuestion` is unavailable
- **THEN** the orchestrator SHALL print the documented prompt line verbatim and SHALL end its turn immediately — no further tool calls, no further text — until the user responds

#### Scenario: Synthesis HALT ends the turn in blocking autonomy levels
- **WHEN** the resolved autonomy level is `balanced`, `guided`, or `manual` AND Phase 1-syn synthesis has been printed
- **THEN** the orchestrator SHALL end its turn immediately after the synthesis output and SHALL NOT call any further tool until the user has replied with `confirm` or `correct: <feedback>`

#### Scenario: Manual-mode proceed waits at end of turn
- **WHEN** the resolved autonomy level is `manual` AND the orchestrator has asked its free-form clarification questions
- **THEN** the orchestrator SHALL end its turn after each question batch and SHALL NOT advance past Phase 1a until the user has replied with `proceed` (or equivalent)

#### Scenario: Blocker recovery and other "wait" points
- **WHEN** any phase reaches a point documented as "halt and tell the user", "wait for guidance", or "stop and ask"
- **THEN** the orchestrator SHALL end its turn immediately after surfacing the blocker text and SHALL NOT call any further tool until the user has provided guidance

#### Scenario: Plain text alone never substitutes for pause
- **WHEN** an interactive checkpoint is reached AND the orchestrator emits only printed text (no `AskUserQuestion`, no end-of-turn)
- **THEN** the implementation SHALL be considered non-conformant with this requirement, because the CLI does not pause on plain text and the user cannot respond

#### Scenario: Halt mechanics subsection is present and referenced
- **WHEN** a newly generated `feature-workflow/SKILL.md` is inspected
- **THEN** it SHALL contain a top-level `## Halt mechanics` subsection that states the two-mechanism rule, AND every later HALT / wait / prompt / `proceed` instruction in the file SHALL either explicitly say "end the turn" / "use AskUserQuestion" or reference the Halt-mechanics subsection
