## Requirements

### Requirement: Locate session JSONL autonomously
The system SHALL compute the session JSONL path using the `CLAUDE_CODE_SESSION_ID` environment variable and the current working directory, without any user input.

Path formula: `~/.claude/projects/<cwd-with-slashes-replaced-by-dashes>/<CLAUDE_CODE_SESSION_ID>.jsonl`

#### Scenario: JSONL found and readable
- **WHEN** Phase 7b runs and `CLAUDE_CODE_SESSION_ID` is set
- **THEN** the system reads the JSONL at the computed path without prompting the user

#### Scenario: JSONL not found
- **WHEN** the computed JSONL path does not exist
- **THEN** the system outputs `Actual session cost: unavailable (session log not found)` and continues without blocking Phase 7b

---

### Requirement: Compute actual total cost from JSONL
The system SHALL sum all `usage` fields across every assistant turn in the session JSONL and apply per-model pricing to produce the actual total cost.

Token fields to sum per turn: `input_tokens` (base input), `cache_creation.ephemeral_5m_input_tokens` (5-min cache write), `cache_creation.ephemeral_1h_input_tokens` (1-hour cache write), `cache_read_input_tokens` (cache read), `output_tokens`.

Pricing rates (from `claude-pricing.md`):

| Model | Base input | Cache write 5m | Cache write 1h | Cache read | Output |
|-------|-----------|----------------|----------------|------------|--------|
| Sonnet 4.6 | $3.00 | $3.75 | $6.00 | $0.30 | $15.00 |
| Haiku 4.5  | $1.00 | $1.25 | $2.00 | $0.10 | $5.00  |
| Opus 4.7   | $5.00 | $6.25 | $10.00 | $0.50 | $25.00 |

Unknown model IDs SHALL fall back to Sonnet 4.6 rates.

#### Scenario: Session with mixed models
- **WHEN** the JSONL contains turns from both Sonnet 4.6 and Haiku 4.5
- **THEN** costs are computed per model and summed to produce a single total

#### Scenario: Malformed turn in JSONL
- **WHEN** a line in the JSONL fails to parse or has no `usage` field
- **THEN** that line is silently skipped; other turns are still counted

---

### Requirement: Track spawn counts per phase during workflow execution
The orchestrator SHALL maintain a running spawn-count memo updated at the end of each phase, recording the agent type and spawn count for that phase.

Memo format (held in conversation context):
```
SPAWN_LOG:
  phase1: jira-agent×1, sdd-expert×1, architect×1
  phase2: git-agent×1
  phase3: impl-agent×3 (baseline×1, CP×2)
  phase4: git-agent×3
  phase5: spec-reviewer×1, design-reviewer×1
  phase6: pr-agent×1, git-agent×1
```

The JSONL path SHALL be recorded at Phase 1 kickoff (before any directory change) as `SESSION_JSONL_PATH` and referenced in Phase 7b.

#### Scenario: Spawn count available at Phase 7b
- **WHEN** Phase 7b runs after a complete workflow
- **THEN** the orchestrator can read the SPAWN_LOG memo without scanning tool history

#### Scenario: Partial workflow (phases not all completed)
- **WHEN** some phases were skipped or not yet run
- **THEN** missing phase entries in the SPAWN_LOG are treated as zero spawns for that phase

---

### Requirement: Build per-phase/per-agent breakdown table
The system SHALL build a per-phase breakdown table using: spawn count (from SPAWN_LOG) × mid-range token profile (from `claude-pricing.md`) = estimated cost per agent row. The orchestrator row SHALL equal `actual_total − Σ(all sub-agent row estimates)`, ensuring the table sums to the actual total.

#### Scenario: Table reconciles to actual total
- **WHEN** sub-agent estimates are summed and subtracted from the actual total
- **THEN** the orchestrator row is a non-negative value and the table total equals the actual total exactly

#### Scenario: Orchestrator row would be negative (profiles overestimate)
- **WHEN** `Σ(sub_agent_estimates) > actual_total`
- **THEN** the orchestrator row is set to $0.00 and a note is appended: `(sub-agent profiles overestimated; orchestrator cost absorbed)`

---

### Requirement: Post non-blocking cost comment
The system SHALL compose the cost comment and post it to the tracker ticket without any user interaction. The `/cost` command SHALL NOT be mentioned as a requirement or prompt.

The comment SHALL include:
1. `**Actual session cost:** $X.XX` (from JSONL computation)
2. Per-phase/per-agent breakdown table with columns: Phase, Agent, Model, Spawns, Est. Cost
3. Pricing rates table (Sonnet/Haiku, cache write / cache read / output)
4. Footer note: `> Actual total from session token log. Phase 7 finalization (~$0.05–0.15) not included. Per-agent rows are profile estimates × actual spawn count.`

#### Scenario: Cost comment posted autonomously
- **WHEN** Phase 7b runs
- **THEN** the comment is composed and posted without asking the user for any input

#### Scenario: Total displayed with two decimal places
- **WHEN** the computed total is e.g. 12.4500
- **THEN** the comment displays `$12.45`
