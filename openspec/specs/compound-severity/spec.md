## ADDED Requirements

### Requirement: Compound severity lookup table
The scanner SHALL maintain a lookup table in `pattern-catalog.md` mapping pairs of co-occurring anti-patterns to escalated severity levels.

#### Scenario: Compound rule matches
- **WHEN** Phase 2 finds both "return null" (INFO) and "reflection in hot path" (HIGH) in the same codebase
- **THEN** report escalates null returns to HIGH with note: "null returns compound with reflection — silent data loss risk in cascade operations"

#### Scenario: No compound match
- **WHEN** anti-patterns found do not appear together in compound severity table
- **THEN** individual severities remain unchanged

### Requirement: Compound severity reporting format
The scanner SHALL report compound escalations in a distinct subsection of Watch, showing: original severities, compound rule triggered, escalated severity, explanation.

#### Scenario: Compound finding in report
- **WHEN** compound severity triggers
- **THEN** Watch section includes entry like: "[HIGH — compound] return null × 12 + reflection in CRUD hot path → silent data loss risk in cascade operations (individually: INFO + HIGH)"

### Requirement: Initial compound rules
The scanner SHALL ship with these initial compound rules:

| Finding A | Finding B | Escalation | Reason |
|-----------|-----------|------------|--------|
| return null | reflection in hot path | INFO→HIGH | silent data loss in cascades |
| broad catch(Exception) | cascading deletes | MEDIUM→HIGH | swallowed errors propagate bad state |
| god class | no tests for class | MEDIUM→HIGH | untestable complexity |
| no auth on endpoint | PII fields in response DTO | MEDIUM→CRITICAL | data exposure risk |

#### Scenario: Table is extensible
- **WHEN** user or developer adds new rows to compound severity table in pattern-catalog.md
- **THEN** scanner picks them up on next run without code changes
