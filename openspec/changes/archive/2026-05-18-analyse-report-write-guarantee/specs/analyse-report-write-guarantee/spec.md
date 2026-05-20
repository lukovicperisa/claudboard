## MODIFIED Requirements

### Requirement: Report directory creation is unconditional and precedes the write

The system SHALL create `.claude/reports/` (or `<workspace>/.claude/reports/` in workspace mode) before attempting any report write. Directory creation SHALL use idempotent semantics (equivalent to `mkdir -p`) so re-runs do not fail if the directory already exists.

#### Scenario: Directory does not exist
- **WHEN** Phase 3 begins and `.claude/reports/` does not exist
- **THEN** the system SHALL create it before writing any file, without prompting the user

#### Scenario: Directory already exists
- **WHEN** Phase 3 begins and `.claude/reports/` already exists
- **THEN** the system SHALL proceed without error or modification to the directory

---

### Requirement: Report file write is unconditional and precedes the user prompt

The system SHALL write the analysis report to disk using an explicit file-write operation BEFORE asking the user whether to generate artifacts now or defer. The write is not conditional on the user's answer.

The file path for each mode:
- **Single-project:** `.claude/reports/claudboard-analysis.md` (relative to project root)
- **Monorepo:** `.claude/reports/claudboard-analysis.md` (global) + `.claude/reports/claudboard-analysis-<service>.md` per service
- **Workspace:** `<workspace>/.claude/reports/claudboard-analysis-workspace.md` (orchestrator) + `<workspace>/.claude/reports/claudboard-analysis-<repo>.md` per repo (sub-agent written, orchestrator verifies)

#### Scenario: Analysis complete, user has not been asked about generation yet
- **WHEN** the system finishes presenting the Phase 2 analysis report to the user
- **THEN** the system SHALL write the report file(s) to disk BEFORE asking "Would you like to generate artifacts now?"
- **AND** the system SHALL NOT skip or defer the write based on any anticipated user response

#### Scenario: Report file write succeeds
- **WHEN** the Write tool call completes successfully for the report file
- **THEN** the system SHALL confirm the write to the user ("Analysis saved to [path]") and then present the generate-now-or-defer prompt

#### Scenario: Report file write fails
- **WHEN** the Write tool call fails (permission error, disk full, path conflict)
- **THEN** the system SHALL report the error to the user and stop; it SHALL NOT proceed to the generate prompt or claim the analysis is saved

---

### Requirement: Instruction ordering in Phase 3 is unambiguous

The Phase 3 instructions in `claudboard-analyse/SKILL.md` SHALL be expressed as a numbered, imperative sequence so the model cannot reorder or skip steps:

1. Create the reports directory (idempotent)
2. Write the report file(s) using the Write tool
3. Confirm save to the user
4. Ask the user about artifact generation

No other ordering is permitted. Steps 1 and 2 are not optional and are not conditional on the user's future choice.

#### Scenario: Model tempted to show content without writing
- **WHEN** the system has presented the analysis to the user and the user has read it
- **THEN** the system SHALL still invoke the Write tool for the report file; displaying the content to the user does NOT substitute for writing the file

---

### Requirement: Workspace sub-agent report verification precedes workspace summary write

In workspace mode, the orchestrator SHALL verify that all per-repo sub-agent report files exist on disk before writing the workspace summary (`claudboard-analysis-workspace.md`). If any per-repo report is missing, the orchestrator SHALL recover it (serial re-run per the parallelisation protocol) before proceeding.

The workspace summary SHALL be written after all per-repo reports are confirmed present.

#### Scenario: All per-repo reports present
- **WHEN** all expected `claudboard-analysis-<repo>.md` files exist in `<workspace>/.claude/reports/`
- **THEN** the orchestrator SHALL write `claudboard-analysis-workspace.md` and proceed to the user prompt

#### Scenario: One or more per-repo reports missing
- **WHEN** one or more expected per-repo report files are absent after sub-agents return
- **THEN** the orchestrator SHALL re-run the missing repo's analysis serially, write the missing file, then proceed to write the workspace summary
- **AND** SHALL NOT write the workspace summary until all per-repo reports are confirmed present
