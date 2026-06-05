## MODIFIED Requirements

### Requirement: Present graph before injection
The system SHALL print the full dependency graph to the user before writing any ecosystem files, and SHALL proceed immediately to write `ecosystem.md` without waiting for confirmation.

The printed graph MUST include: every cross-service edge with source, target, protocol family, coupling strength, and a one-line warning per TIGHT edge or detected synchronous chain or circular dependency.

The printed graph MUST be followed by a single line stating the recovery path: "If an edge is missing or wrong, edit `.claudboard/catalog.json` or `.claude/memories/ecosystem.md` after the run completes."

The system MUST NOT block on user input at this point. The system MUST NOT ask "Proceed?", "Edit?", or any equivalent interactive question.

#### Scenario: Graph printed and pipeline proceeds
- **WHEN** graph construction is complete in monorepo or workspace mode
- **THEN** the system SHALL print the full dependency graph with edges, coupling classifications, and warnings, then immediately proceed to write `ecosystem.md` without waiting for user input

#### Scenario: Warnings remain visible in printed output
- **WHEN** the graph contains TIGHT edges, synchronous chains, or circular dependencies
- **THEN** the warnings SHALL be printed prominently (one per line, prefixed with a marker such as "⚠") so the user sees them in the run output

#### Scenario: Recovery path printed
- **WHEN** the graph has been printed
- **THEN** the printed output SHALL include a single recovery hint line directing the user to edit `.claudboard/catalog.json` or `.claude/memories/ecosystem.md`

#### Scenario: No blocking confirmation prompt
- **WHEN** the graph has been printed
- **THEN** the system SHALL NOT pause execution to ask for confirmation or corrections, and SHALL begin writing `ecosystem.md` on the next step
