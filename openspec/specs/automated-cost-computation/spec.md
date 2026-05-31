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
| Opus 4.7   | $15.00 | $18.75 | $30.00 | $1.50 | $75.00 |

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
The system SHALL build a per-phase cost summary as a flat bullet list using: Σ(spawn count × mid-range token profile) across all agents in that phase = estimated cost for that phase bullet. The orchestrator bullet SHALL equal `actual_total − Σ(all phase bullet estimates)`, ensuring the bullets sum to the actual total.

The bullet set SHALL always include all of: Phase 1, Phase 2, Phase 3, Phase 4, Phase 5, Phase 6, Orchestrator — even if a phase had zero spawns (in which case its bullet renders `$0.00`). Per-agent rows SHALL NOT be rendered in the comment.

#### Scenario: Bullets reconcile to actual total
- **WHEN** phase estimates are summed and subtracted from the actual total
- **THEN** the orchestrator bullet is a non-negative value and the sum of all 7 bullets equals the actual total exactly

#### Scenario: Orchestrator bullet would be negative (profiles overestimate)
- **WHEN** `Σ(phase_estimates) > actual_total`
- **THEN** the orchestrator bullet is set to $0.00 and a note `(sub-agent profiles overestimated; orchestrator cost absorbed)` is appended to the footnote blockquote

#### Scenario: Phase with zero spawns still renders
- **WHEN** Phase 5 had no agent spawns in this workflow run (SPAWN_LOG `phase5:` empty)
- **THEN** the Phase 5 bullet still appears in the comment body as `- Phase 5 — Review: $0.00`

---

### Requirement: Post non-blocking cost comment
The system SHALL compose the cost comment and post it to the tracker ticket without any user interaction. The `/cost` command SHALL NOT be mentioned as a requirement or prompt.

The comment body SHALL be a flat-markdown shape composed of exactly these elements, in this order:

1. A level-2 markdown heading with text `AI-Assisted Development — Cost Analysis`.
2. A bold meta line of the form `Session total: $<total>` (rendered with `**` around `Session total:`).
3. A bold meta line of the form `This ticket's share: $<share> (<n> of <N>)` (rendered with `**` around `This ticket's share:`).
4. A level-3 markdown heading with text `Per-phase cost`.
5. Exactly seven bullets, in the following fixed order and label form: `Phase 1 — Spec + Plan: $<p1>`, `Phase 2 — Branch: $<p2>`, `Phase 3 — Implement: $<p3>`, `Phase 4 — Commit: $<p4>`, `Phase 5 — Review: $<p5>`, `Phase 6 — PR: $<p6>`, `Orchestrator: $<orch>`.
6. A blockquote footnote with text `Estimated from session token log. Phase 7 finalization not included.`

The comment body SHALL NOT contain: markdown tables, a pricing-rates section, a model name (e.g. "Sonnet 4.6"), per-phase token counts, per-agent rows, PR links, merge-order text, "Total time logged" sentences, out-of-scope notes, or any other content beyond the six elements above. Dollar values SHALL be formatted with two decimal places (e.g. `$1.08`, `$0.00`).

The share line (element 3) SHALL always render, including in single-ticket runs where `<n>` = `<N>` = 1.

#### Scenario: Cost comment posted autonomously
- **WHEN** Phase 7b runs
- **THEN** the comment is composed and posted without asking the user for any input

#### Scenario: Total displayed with two decimal places
- **WHEN** the computed total is e.g. 12.4500
- **THEN** the comment displays `$12.45`

#### Scenario: Single-ticket run renders share line
- **WHEN** Phase 7b runs against a single ticket (not a batch)
- **THEN** the share line renders as `**This ticket's share:** $<total> (1 of 1)` — the line is not omitted

#### Scenario: Batch run divides share equally
- **WHEN** Phase 7b runs against a batch of N tickets sharing one session
- **THEN** each ticket's comment renders `**This ticket's share:** $<total/N> (<n> of <N>)` with `<n>` being that ticket's 1-indexed position

#### Scenario: Comment contains no tables or pricing rates
- **WHEN** the comment body is composed
- **THEN** it SHALL NOT contain any `|`-delimited markdown table syntax, any "Pricing" or "Pricing Rates" heading, or any model identifier string
