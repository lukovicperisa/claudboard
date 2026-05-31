## MODIFIED Requirements

### Requirement: Informational pre-write summary

The system SHALL present a summary of what will be generated (file tree, enabled capability blocks, resolved config values) inline as printed text, then SHALL proceed directly to the write phase without calling `AskUserQuestion` and without ending the orchestrator's turn at the summary point.

The summary SHALL end with a one-line hint that the user can interrupt: `I'll proceed now — interrupt with Esc to abort or adjust.` (exact wording).

The summary SHALL NOT include a `[y/n]`, `[y/n/edit]`, `[y/n/selective]`, or similar prompt token, because the user already expressed intent by invoking the skill.

#### Scenario: Summary printed, write proceeds without pause

- **WHEN** the orchestrator has resolved capability flags and config values and is ready to write
- **THEN** the orchestrator SHALL print the summary (files, capabilities, resolved values)
- **AND** SHALL print the interrupt hint as the last line of the summary block
- **AND** SHALL proceed directly to the next phase without calling `AskUserQuestion`
- **AND** SHALL NOT end its turn at the summary point

#### Scenario: User interrupts after seeing the summary

- **WHEN** the user reads the summary and interrupts the orchestrator before files are written
- **THEN** the orchestrator SHALL stop its current operation
- **AND** SHALL accept the user's redirection (e.g., "fix the TODO stub for repositoryId before writing", or "skip the workspace-mode block")
- **AND** SHALL re-render the summary after applying the user's change before resuming the write phase

#### Scenario: Pause-on-real-decision is unaffected

- **WHEN** a mutually-exclusive-flag conflict (per the `Mutually-exclusive repo agents` requirement), a missing-required-config error, or another genuine decision point is detected
- **THEN** the orchestrator SHALL still halt at that point and ask the user via `AskUserQuestion` or by ending its turn after printing the prompt
- **AND** the removal of the proceed-step gate SHALL NOT affect these decision-point halts
