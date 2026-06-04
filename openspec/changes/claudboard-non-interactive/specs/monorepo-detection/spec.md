## MODIFIED Requirements

### Requirement: Present detected topology before proceeding
The system SHALL print the detected monorepo topology to the user before proceeding with per-service analysis, and SHALL proceed immediately without waiting for confirmation.

The printed topology MUST include, for each detected build root: directory path, detected stack, classification (service or library), and any signals that drove an ambiguous classification.

The printed topology MUST be followed by a single line stating the recovery path: "If a service is misclassified, edit `.claudboard/catalog.json` after the run completes, or re-run `/analyse` from a different level."

The system MUST NOT block on user input at this point. The system MUST NOT ask for confirmation, corrections, or any other interactive response.

#### Scenario: Topology presentation in monorepo mode
- **WHEN** monorepo structure is detected with 2+ build roots
- **THEN** the system SHALL display "Found N services + M libraries:" followed by a list with names, detected stack, and classification, then proceed with per-service analysis without waiting for user input

#### Scenario: Topology presentation in workspace mode
- **WHEN** workspace structure is detected (multiple build roots, each with its own `.git/`)
- **THEN** the system SHALL display the workspace topology with per-repo stack and classification, then proceed without waiting for user input

#### Scenario: Misclassification recovery path printed
- **WHEN** the topology is printed
- **THEN** the printed output SHALL include a single recovery hint line directing the user to edit `.claudboard/catalog.json` or re-run `/analyse`

#### Scenario: No blocking confirmation prompt
- **WHEN** monorepo or workspace topology has been printed
- **THEN** the system SHALL NOT pause execution to ask "Proceed?", "Confirm?", or any equivalent interactive question, and SHALL begin per-service analysis on the next step
