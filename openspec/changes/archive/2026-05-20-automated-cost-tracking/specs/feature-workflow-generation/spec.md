## MODIFIED Requirements

### Requirement: Phase 7b cost comment — JIRA variant
The generated feature-workflow SKILL.md SHALL instruct the orchestrator to compute the actual session cost autonomously from the Claude Code session JSONL and post a per-phase/per-agent cost breakdown comment to the JIRA ticket. The orchestrator SHALL NOT prompt the user for `/cost` output or any cost-related input.

Phase 7b (JIRA) steps:
1. Read `claude-pricing.md`
2. Run the JSONL cost script (see `automated-cost-computation` capability) to obtain `ACTUAL_TOTAL`
3. Build the per-phase/per-agent table from SPAWN_LOG × profile estimates, with orchestrator row = `ACTUAL_TOTAL − Σ(sub_agent_estimates)`
4. Compose the comment and post it via jira-agent; proceed immediately to Phase 7c

#### Scenario: JIRA cost comment posted without user interaction
- **WHEN** the feature-workflow reaches Phase 7b (JIRA variant)
- **THEN** the orchestrator computes the cost, composes the comment, and posts it without asking the user anything

#### Scenario: JIRA comment includes actual total and breakdown table
- **WHEN** the cost comment is posted
- **THEN** it contains `**Actual session cost:** $X.XX`, a per-phase/per-agent table with Spawns and Est. Cost columns, and a footer note explaining the computation source

---

### Requirement: Phase 7b cost comment — T&R variant
The generated feature-workflow SKILL.md SHALL instruct the orchestrator to apply the same autonomous cost computation to the T&R Phase 7b summary comment. The `$XX.XX (from /cost)` placeholder SHALL be replaced with the JSONL-computed actual total. The orchestrator SHALL NOT prompt the user for `/cost` output.

#### Scenario: T&R cost comment posted without user interaction
- **WHEN** the feature-workflow reaches Phase 7b (T&R variant)
- **THEN** the orchestrator computes the cost and posts the comment without any user prompt

#### Scenario: T&R comment cost section shows actual total
- **WHEN** the T&R summary comment is composed
- **THEN** the Cost Analysis section displays `**Actual session cost:** $X.XX` from the JSONL computation, not `$XX.XX (from /cost)`

---

### Requirement: Spawn-count tracking across phases
The generated feature-workflow SKILL.md SHALL instruct the orchestrator to record a SPAWN_LOG memo at the end of each phase and to capture `SESSION_JSONL_PATH` at Phase 1 kickoff.

SPAWN_LOG format:
```
SPAWN_LOG:
  phase1: <agent>×<n>, ...
  phase2: <agent>×<n>, ...
  ...
```

`SESSION_JSONL_PATH` = `~/.claude/projects/$(pwd | sed 's|/|-|g')/$CLAUDE_CODE_SESSION_ID.jsonl`, recorded before any directory change.

#### Scenario: SPAWN_LOG available at Phase 7b
- **WHEN** the workflow has run through Phase 6
- **THEN** the orchestrator holds a SPAWN_LOG covering all spawned agents per phase

#### Scenario: SESSION_JSONL_PATH captured at kickoff
- **WHEN** Phase 1 begins
- **THEN** the orchestrator records `SESSION_JSONL_PATH` using `$CLAUDE_CODE_SESSION_ID` and the current working directory
