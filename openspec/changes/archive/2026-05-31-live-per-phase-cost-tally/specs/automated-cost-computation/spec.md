## ADDED Requirements

### Requirement: Emit per-phase cost tick at end of phases 1-6
The orchestrator SHALL emit a one-line cost tick at the end of each of phases 1, 2, 3, 4, 5, and 6, before transitioning to the next phase. The tick SHALL invoke the bundled `compute-cost.sh` with a `--since <PHASE_N_START>` slice, where `PHASE_N_START` is a timestamp recorded at the start of phase N.

Tick output line format (printed to the user):
```
Phase N (<phase-label>): $X.XX │ session $Y.YY
```

Where:
- `N` is the phase number (1 through 6).
- `<phase-label>` is the phase's human label: `Spec+Plan`, `Branch`, `Implement`, `Commit`, `Review`, `PR`.
- `$X.XX` is the cost incurred between `PHASE_N_START` and the moment of the tick.
- `$Y.YY` is the running session total (sum of `$X.XX` across phases 1..N).

The tick SHALL be invoked via bash (not via a spawned sub-agent) and SHALL incur zero additional API token cost beyond the orchestrator's normal turn arithmetic.

`PHASE_N_START` SHALL be recorded as an ISO 8601 UTC timestamp at the entry of phase N, immediately after the prior phase's tick (or, for phase 1, at workflow kickoff alongside `SESSION_JSONL_PATH`).

#### Scenario: Tick fires at end of each completed phase
- **WHEN** the orchestrator finishes the work of phase N (N ∈ {1..6}) and before phase N+1 begins
- **THEN** the orchestrator runs `compute-cost.sh --since <PHASE_N_START>` against `SESSION_JSONL_PATH` and prints the formatted tick line to the user

#### Scenario: Phase 1 records start timestamp at kickoff
- **WHEN** phase 1 begins
- **THEN** the orchestrator records `PHASE_1_START` as an ISO 8601 UTC timestamp before any sub-agent is spawned

#### Scenario: Subsequent phase start timestamps recorded after prior tick
- **WHEN** the tick for phase N completes
- **THEN** the orchestrator records `PHASE_(N+1)_START` as an ISO 8601 UTC timestamp before entering phase N+1

#### Scenario: Tick uses bundled script
- **WHEN** the tick invokes the cost computation
- **THEN** it calls the `compute-cost.sh` bundled in the generated workflow's `scripts/` directory; it SHALL NOT embed inline jq or inline Python and SHALL NOT call any script outside the generated workflow

#### Scenario: Phase skipped or aborted mid-phase
- **WHEN** the workflow aborts during phase N (before the phase completes) or skips phase N entirely
- **THEN** no tick is emitted for phase N; the ticks already emitted for phases 1..N-1 remain valid and visible to the user

---

### Requirement: Maintain SESSION_COST_LOG memo
The orchestrator SHALL maintain a `SESSION_COST_LOG` memo in conversation context, alongside the existing `SPAWN_LOG`. The orchestrator SHALL append one line per phase tick.

Memo format (held in conversation context):
```
SESSION_COST_LOG:
  phase1: $0.42 │ session $0.42
  phase2: $0.03 │ session $0.45
  phase3: $1.18 │ session $1.63
  phase4: $0.07 │ session $1.70
  phase5: $0.31 │ session $2.01
  phase6: $0.09 │ session $2.10
```

The line format SHALL match the printed tick output. Phases not yet reached SHALL be absent from the memo (not zero-valued placeholders).

#### Scenario: Memo grows monotonically as phases complete
- **WHEN** phase N's tick completes
- **THEN** the `SESSION_COST_LOG` memo contains exactly N entries (one per completed phase) and Phase 7b can read it without scanning tool history

#### Scenario: Partial workflow has partial log
- **WHEN** the workflow runs only through phase 3 (aborted, ticket-only, or batch-suspended)
- **THEN** `SESSION_COST_LOG` contains exactly three entries (phase1, phase2, phase3)

---

### Requirement: Reconcile session total against tick sum at Phase 7b
Phase 7b SHALL run `compute-cost.sh` once over the full session (no `--since` slice) to obtain `ACTUAL_TOTAL`, then compute `RECONCILIATION = ACTUAL_TOTAL − Σ(per-phase ticks from SESSION_COST_LOG)`.

If `|RECONCILIATION| > $0.01`, the comment footnote SHALL include the annotation `(unaccounted: $<RECONCILIATION>.XX)` with the value formatted to two decimal places (the absolute value is rendered; the sign is implied by the annotation's presence — positive drift means measured exceeded ticks).

If `|RECONCILIATION| ≤ $0.01`, no annotation SHALL be added (clean footnote).

The reconciliation SHALL NOT block Phase 7b. If the script fails or `SESSION_COST_LOG` is empty, Phase 7b SHALL fall back to the existing behavior (post the comment with `ACTUAL_TOTAL` only and no per-phase breakdown).

#### Scenario: Ticks reconcile within tolerance
- **WHEN** `|ACTUAL_TOTAL − Σ(ticks)| ≤ $0.01`
- **THEN** the comment footnote contains no `(unaccounted: ...)` annotation

#### Scenario: Drift exceeds tolerance
- **WHEN** `|ACTUAL_TOTAL − Σ(ticks)| > $0.01` (e.g. a tick was skipped, or Phase 7 finalization itself adds measurable cost)
- **THEN** the footnote includes ` (unaccounted: $X.XX)` appended after the existing footnote sentence

#### Scenario: SESSION_COST_LOG empty (no ticks recorded)
- **WHEN** Phase 7b runs and `SESSION_COST_LOG` is empty
- **THEN** the comment is composed with `ACTUAL_TOTAL` as the session total, each per-phase bullet renders `$0.00`, and the footnote includes ` (no per-phase ticks recorded — session total only)`

## MODIFIED Requirements

### Requirement: Compute actual total cost from JSONL
The system SHALL invoke the bundled `compute-cost.sh` script (shipped in the generated workflow's `scripts/` directory) to sum all `usage` fields across every assistant turn in the session JSONL and apply per-model pricing to produce the actual total cost. The system SHALL NOT embed inline jq or inline Python for this computation.

Token fields summed per turn (handled by the script): `input_tokens` (base input), `cache_creation.ephemeral_5m_input_tokens` (5-min cache write), `cache_creation.ephemeral_1h_input_tokens` (1-hour cache write), `cache_read_input_tokens` (cache read), `output_tokens`. The script SHALL dedup by `requestId` before summing (one JSONL line per content block share the same usage object — summing all lines over-counts 3-4×).

Pricing rates are sourced from the bundled `references/pricing.md` (verbatim copy of `claudboard/references/pricing.md`):

| Model | Base input | Cache write 5m | Cache write 1h | Cache read | Output |
|-------|-----------|----------------|----------------|------------|--------|
| Sonnet 4.6 | $3.00 | $3.75 | $6.00 | $0.30 | $15.00 |
| Haiku 4.5  | $1.00 | $1.25 | $2.00 | $0.10 | $5.00  |
| Opus 4.7   | $15.00 | $18.75 | $30.00 | $1.50 | $75.00 |

Unknown model IDs SHALL fall back to Sonnet 4.6 rates and the script SHALL emit a one-time stderr warning naming the unknown model.

The script SHALL accept a `--since <ISO8601 timestamp>` argument that filters input to lines with `timestamp >= <since>`. When `--since` is omitted, the script processes the full JSONL.

#### Scenario: Session with mixed models
- **WHEN** the JSONL contains turns from both Sonnet 4.6 and Haiku 4.5
- **THEN** the script computes costs per model and sums them into a single total

#### Scenario: Malformed turn in JSONL
- **WHEN** a line in the JSONL fails to parse or has no `usage` field
- **THEN** the script silently skips that line; other turns are still counted

#### Scenario: requestId dedup applied
- **WHEN** the JSONL contains multiple lines sharing the same `requestId` (one per content block in a multi-block assistant message)
- **THEN** the script counts that request's usage exactly once

#### Scenario: Bundled script invoked, not inline computation
- **WHEN** Phase 7b or any per-phase tick computes cost
- **THEN** the invocation is `<workflow>/scripts/compute-cost.sh`; the orchestrator SHALL NOT execute inline jq or inline Python for cost computation

### Requirement: Build per-phase/per-agent breakdown table
The system SHALL build the per-phase cost summary in the Phase 7b tracker comment from the **measured** per-phase totals in `SESSION_COST_LOG`. The orchestrator residual bullet SHALL equal `ACTUAL_TOTAL − Σ(per-phase measured ticks from SESSION_COST_LOG)`, with negative values clamped to `$0.00`.

The bullet set SHALL always include all of: Phase 1, Phase 2, Phase 3, Phase 4, Phase 5, Phase 6, Orchestrator — even if a phase had no tick recorded (in which case its bullet renders `$0.00` and the reconciliation requirement surfaces the gap in the footnote). Per-agent rows SHALL NOT be rendered in the comment. SPAWN_LOG × profile estimation for cost purposes SHALL NOT be used; agent profiles in `claude-pricing.md` remain available for orchestrator agent-selection reasoning but are not part of the cost-comment computation.

#### Scenario: Per-phase rows from measured ticks
- **WHEN** the comment is composed and `SESSION_COST_LOG` contains entries for all six phases
- **THEN** each `Phase N` bullet shows the measured `$X.XX` from `SESSION_COST_LOG.phaseN` (the per-phase value, not the cumulative session value)

#### Scenario: Phase with no recorded tick renders zero
- **WHEN** `SESSION_COST_LOG` has no entry for phase N (e.g. the orchestrator skipped the tick)
- **THEN** the Phase N bullet still appears as `- Phase N — <label>: $0.00` and the reconciliation surfaces the gap in the footnote

#### Scenario: Orchestrator residual non-negative
- **WHEN** the orchestrator bullet is computed as `ACTUAL_TOTAL − Σ(measured ticks)`
- **THEN** the value is clamped to `$0.00` if negative; under normal operation the residual covers orchestrator-side cost between phases and is a small positive number

### Requirement: Post non-blocking cost comment
The system SHALL compose the cost comment and post it to the tracker ticket without any user interaction. The `/cost` command SHALL NOT be mentioned as a requirement or prompt.

The comment body SHALL be a flat-markdown shape composed of exactly these elements, in this order:

1. A level-2 markdown heading with text `AI-Assisted Development — Cost Analysis`.
2. A bold meta line of the form `Session total: $<total>` (rendered with `**` around `Session total:`).
3. A bold meta line of the form `This ticket's share: $<share> (<n> of <N>)` (rendered with `**` around `This ticket's share:`).
4. A level-3 markdown heading with text `Per-phase cost`.
5. Exactly seven bullets, in the following fixed order and label form: `Phase 1 — Spec + Plan: $<p1>`, `Phase 2 — Branch: $<p2>`, `Phase 3 — Implement: $<p3>`, `Phase 4 — Commit: $<p4>`, `Phase 5 — Review: $<p5>`, `Phase 6 — PR: $<p6>`, `Orchestrator: $<orch>`.
6. A blockquote footnote with text `Measured per phase from session token log. Phase 7 finalization included in Orchestrator.` The footnote SHALL be extended with ` (unaccounted: $X.XX)` when the reconciliation requirement triggers the annotation, and with ` (no per-phase ticks recorded — session total only)` when `SESSION_COST_LOG` is empty.

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

#### Scenario: Footnote reflects measured-source semantics
- **WHEN** the comment is composed
- **THEN** the footnote sentence reads `Measured per phase from session token log. Phase 7 finalization included in Orchestrator.` (not the prior "Estimated from session token log. Phase 7 finalization not included." wording)
