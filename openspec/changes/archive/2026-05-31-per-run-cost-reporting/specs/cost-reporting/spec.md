## ADDED Requirements

### Requirement: Cost script SHALL compute precise per-slice cost from a Claude Code session JSONL

The system SHALL provide a `compute-cost.sh` script that reads a Claude Code session JSONL transcript, sums the five token-usage fields per API call, multiplies each field by the per-model price table, and emits a single computed total cost.

The script SHALL dedup assistant turns by `requestId` before summing. Each assistant API call writes one JSONL line per content block (thinking, text, every `tool_use`) — all lines for one call share the same `requestId` and the same `usage` object. Naive sums over assistant lines over-count by 3-4×; the dedup is non-negotiable.

The five token fields summed per unique `requestId` SHALL be: `input_tokens`, `cache_creation.ephemeral_5m_input_tokens`, `cache_creation.ephemeral_1h_input_tokens`, `cache_read_input_tokens`, `output_tokens`. Missing fields SHALL be treated as zero.

The model used for pricing each call SHALL be taken from that call's `message.model` field, not from a global default. Calls with different models in the same JSONL SHALL be priced per-call and summed.

#### Scenario: Dedup eliminates per-content-block over-counting
- **WHEN** the JSONL contains an assistant API call with three content blocks (thinking, text, tool_use) written as three JSONL lines sharing one `requestId`
- **THEN** the script counts the call's usage exactly once, not three times

#### Scenario: Mixed-model session priced per call
- **WHEN** the JSONL contains 10 calls on `claude-opus-4-7` and 5 calls on `claude-sonnet-4-6`
- **THEN** the Opus calls are priced at Opus rates and the Sonnet calls at Sonnet rates; the total is the sum

#### Scenario: Missing usage subfield treated as zero
- **WHEN** a call's `usage` object lacks the `cache_creation` key entirely
- **THEN** `cache_creation.ephemeral_5m_input_tokens` and `cache_creation.ephemeral_1h_input_tokens` are both treated as 0 and the call is still priced (the other fields are used)

---

### Requirement: Cost script SHALL accept the JSONL path as an argument, not auto-discover from cwd

The script SHALL take the JSONL file path as a positional argument. If the positional argument is absent, the script SHALL fall back to the `CLAUDE_SESSION_JSONL` environment variable. If neither is provided, the script SHALL exit non-zero with an error message naming both inputs.

The script SHALL NOT attempt to derive the JSONL path from the current working directory or any other implicit source. This rule exists so that Claude Agent SDK runs (which may use custom session IDs and arbitrary cwd) work without modification.

#### Scenario: JSONL path passed as argument
- **WHEN** the script is invoked as `compute-cost.sh /path/to/session.jsonl`
- **THEN** it reads the file at that path and emits the cost

#### Scenario: JSONL path from environment variable
- **WHEN** the script is invoked with no positional argument but `CLAUDE_SESSION_JSONL=/path/to/session.jsonl` is set
- **THEN** it reads that path and emits the cost

#### Scenario: Neither argument nor env var provided
- **WHEN** the script is invoked with no positional argument and `CLAUDE_SESSION_JSONL` is unset
- **THEN** it exits with non-zero status and an error message naming both expected inputs

---

### Requirement: Cost script SHALL support time-slice bounds via `--since` and `--until`

The script SHALL accept optional `--since <ISO-8601-timestamp>` and `--until <ISO-8601-timestamp>` flags. When `--since` is provided, only assistant turns with `timestamp >= <since>` SHALL be included. When `--until` is provided, only turns with `timestamp < <until>` SHALL be included. The default `--until` is "no upper bound" (read to end of file).

These bounds enable per-task slicing within a session that contains multiple tasks.

#### Scenario: --since narrows the slice to a single task
- **WHEN** the JSONL contains `/analyse` at 13:06:00 and `/generate` at 13:30:00, and the script is invoked with `--since 2026-05-31T13:06:00Z --until 2026-05-31T13:30:00Z`
- **THEN** only the `/analyse` task's API calls are included in the cost total

#### Scenario: --since without --until reads to end of file
- **WHEN** the script is invoked with `--since 2026-05-31T13:30:00Z` and no `--until`
- **THEN** all turns from 13:30 onward are included

---

### Requirement: Cost script SHALL support `one-line` and `json` output formats

The script SHALL accept `--format one-line` (default) or `--format json`.

The `one-line` format SHALL emit exactly one line to stdout of the form:

```
Cost for /<cmd>: $<total> (<Model>, <N> calls, <K> out)
```

Where `<cmd>` is the task trigger derived from the matching user message (lowercase, no leading slash if no user message context is provided externally), `<total>` is the dollar total formatted with two decimal places, `<Model>` is the human-readable model name (e.g. `Opus 4.7`, `Sonnet 4.6`), `<N>` is the unique-requestId count in the slice, and `<K>` is the output-token total formatted with `K` suffix.

The `json` format SHALL emit a single JSON object to stdout with fields: `total_usd`, `model`, `api_calls`, `tokens` (object with `input_uncached`, `cache_write_5m`, `cache_write_1h`, `cache_read`, `output`), `cost_breakdown_usd` (object with the same five keys), `slice` (object with `since`, `until`).

When multiple models are present in the slice, the `<Model>` field in one-line format SHALL render as `mixed` and the `model` field in json format SHALL be an array of model IDs.

#### Scenario: Default one-line output for /analyse
- **WHEN** the script processes a 25-call Opus 4.7 slice totalling $8.17 with 28K output tokens
- **THEN** it emits `Cost for /analyse: $8.17 (Opus 4.7, 25 calls, 28K out)`

#### Scenario: JSON output is machine-parseable
- **WHEN** the script is invoked with `--format json`
- **THEN** stdout contains a single valid JSON object with the documented fields

#### Scenario: Multi-model slice rendered as "mixed"
- **WHEN** the slice contains both Opus and Sonnet calls
- **THEN** the one-line output renders `(mixed, ...)` and the json output's `model` is an array

---

### Requirement: Cost script SHALL warn loudly on unknown model IDs

When the script encounters a `message.model` value not present in the price table, it SHALL emit a warning to stderr of the form:

```
WARN: unknown model "<model-id>" — pricing as Sonnet 4.6 fallback. Add to references/pricing.md.
```

The warning SHALL be emitted at most once per unique unknown model ID per invocation. The script SHALL continue execution using Sonnet 4.6 rates as fallback (not abort).

#### Scenario: New unreleased model in JSONL
- **WHEN** the JSONL contains turns with `model: "claude-opus-5-0"` which is absent from the price table
- **THEN** the script emits one warning line to stderr and prices those turns at Sonnet 4.6 rates

#### Scenario: Multiple unknown models warned once each
- **WHEN** the JSONL contains turns from two unknown models
- **THEN** the script emits exactly two warning lines (one per unique model), not one per turn

---

### Requirement: Price table SHALL be versioned with `effective_from` dates per model

The price table at `skills/claudboard/references/pricing.md` SHALL be a static Markdown document with one entry per supported model. Each entry SHALL include: the canonical model ID string used in `message.model`, a human-readable display name, an `effective_from` ISO-8601 date, and the five per-million-token rates (base input, cache_write_5m, cache_write_1h, cache_read, output).

The table SHALL be the single source of truth referenced by `compute-cost.sh`. The script SHALL parse the table at invocation time (no compile step).

Initial entries SHALL cover at minimum:
- `claude-opus-4-7`: Opus 4.7 — $15.00 / $18.75 / $30.00 / $1.50 / $75.00
- `claude-sonnet-4-6`: Sonnet 4.6 — $3.00 / $3.75 / $6.00 / $0.30 / $15.00
- `claude-haiku-4-5-20251001`: Haiku 4.5 — $1.00 / $1.25 / $2.00 / $0.10 / $5.00

#### Scenario: Adding a new model requires only a price-table edit
- **WHEN** Anthropic releases a new model and a new row is appended to `references/pricing.md`
- **THEN** the script picks up the new rates on the next invocation without code changes

#### Scenario: Effective-from date documents historical rates
- **WHEN** a model's rate changes and the table is updated with a new `effective_from` row
- **THEN** the script uses the row whose `effective_from` is the latest date ≤ the JSONL turn's timestamp

---

### Requirement: Stop hook SHALL fire end-of-task cost emission only when a claudboard task trigger gated the slice

A `Stop` hook SHALL be documented in the claudboard `README.md` as an opt-in `settings.json` block. When installed, the hook SHALL run on every Stop event and:

1. Locate the current session JSONL (using `CLAUDE_SESSION_JSONL` if exposed by the harness, else compute from `CLAUDE_CODE_SESSION_ID` and cwd).
2. Identify the most recent `type: user` message in the JSONL whose text content begins with one of: `/analyse`, `/generate`, `/refresh`, `/techdebt` (allowing optional whitespace before the slash).
3. If no such message is found, exit silently (no output).
4. If a matching message is found, invoke `compute-cost.sh --since <matching-prompt-timestamp>` and print exactly the script's stdout to the user-visible transcript.

The hook SHALL NOT issue any model API call and SHALL NOT add any input/output tokens to the conversation.

#### Scenario: Hook silent when no claudboard trigger in last user prompt
- **WHEN** the user's last message was conversational ("ok thanks") and the Stop event fires
- **THEN** the hook produces no output

#### Scenario: Hook emits one line at end of /analyse
- **WHEN** the user invoked `/analyse`, Claude completed the task, and the final Stop event fires
- **THEN** the hook emits the cost line covering the slice from the `/analyse` prompt's timestamp to now

#### Scenario: New `/generate` resets the slice
- **WHEN** the user runs `/analyse` (emitting a cost line), then `/generate` in the same session, and `/generate` completes
- **THEN** the second emission covers only the `/generate` slice — costs do not accumulate across the two tasks

#### Scenario: Conversational replies during a task do not change the matched prompt
- **WHEN** `/analyse` is running and the user replies "Yes proceed" to a clarification, then Claude continues and eventually finishes
- **THEN** the final emission's slice still starts at the original `/analyse` prompt timestamp, not the "Yes proceed" reply

---

### Requirement: Hook-emitted cost line SHALL include "(in progress)" when Claude is paused for user input

When the hook fires and the most recent assistant message's content includes a `tool_use` block whose `name` is `AskUserQuestion`, the emitted line SHALL be suffixed with ` (in progress)` after the closing parenthesis.

This heuristic communicates that the emission is a partial-task snapshot, not the final cost.

#### Scenario: Topology-confirm pause shows in-progress
- **WHEN** `/analyse` pauses to ask the user to confirm detected topology via `AskUserQuestion`, the Stop event fires
- **THEN** the emitted line ends with `(in progress)`

#### Scenario: Final emission has no in-progress suffix
- **WHEN** `/analyse` completes its final report-saved message and the Stop event fires
- **THEN** the line has no `(in progress)` suffix

---

### Requirement: Hook installation SHALL be opt-in and documented in the claudboard README

The `README.md` SHALL include a clearly-marked "Per-task cost reporting (optional)" section that contains a copy-pasteable `settings.json` Stop-hook block, the path to `compute-cost.sh`, and one example of the resulting output line.

The hook SHALL NOT be auto-installed by `/claudboard`, `/analyse`, `/generate`, or any other claudboard skill. Users opt in by editing their own `settings.json`.

#### Scenario: Fresh claudboard install has no hook by default
- **WHEN** a user installs the claudboard plugin for the first time
- **THEN** no cost-reporting hook is registered in their `settings.json` automatically

#### Scenario: README snippet is self-contained
- **WHEN** a user copies the documented `settings.json` block and the script path is correct for their install
- **THEN** the next `/analyse` run emits a cost line at task end without further configuration
