## MODIFIED Requirements

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

#### Scenario: Opus 4.7 turn priced at current published rates
- **WHEN** a JSONL turn has `message.model: "claude-opus-4-7"` with `output_tokens: 1000`
- **THEN** the output-token contribution is priced at $75.00/M (i.e. $0.075 for that turn's output), not the previously-listed $25.00/M
