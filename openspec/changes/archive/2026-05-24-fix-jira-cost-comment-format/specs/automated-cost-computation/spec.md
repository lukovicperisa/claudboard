## MODIFIED Requirements

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
