# Ticket Description Template

Use this template when composing or updating a ticket description from the
clarified scope. The three sections below form the canonical structure.

```markdown
## Goal
<what should be built and why — from the user's perspective>

## Acceptance Criteria
- <criterion 1>
- <criterion 2>

## Context
<background, affected services, constraints, related tickets>
```

## Tracker-specific AC placement

**TRACKER_JIRA:** Acceptance Criteria go to the dedicated Jira custom field.
Do **NOT** include an `## Acceptance Criteria` section in the description body.
The `updateDescription` action receives only the `## Goal` and `## Context` sections.

**TRACKER_TR:** T&R cannot write custom fields. Acceptance Criteria **MUST**
be inlined in the description body under `## Acceptance Criteria` — use the
full three-section template above.
