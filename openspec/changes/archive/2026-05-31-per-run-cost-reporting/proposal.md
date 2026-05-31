## Why

Today users only see Claude Code cost as a 24h rolling total via `/usage` — there is no way to know what a single `/analyse`, `/generate`, `/refresh`, or `/techdebt` run cost. A 2026-05-31 measurement of `/analyse` on GardenMind came to **$8.17 on Opus 4.7**, against the `speed-up-analyse` proposal's stated "$1-2 single-project" baseline that implicitly assumed Sonnet pricing. The measurement proved two things: (1) per-run cost is computable from the session JSONL on disk, deterministically and at zero API cost; (2) the dollar-impact of model choice and prompt-cache patterns is currently invisible, which makes it impossible to reason about whether perf optimisations actually save money or which tasks are expensive. Cost visibility per task is the foundation for treating cost as a first-class engineering signal.

The same measurement also surfaced a latent bug: the existing `automated-cost-computation` spec (used by feature-workflow Phase 7b) carries Opus 4.7 rates of $5 base / $25 output, ~3× under the actual $15 / $75. Tracker cost comments posted by Phase 7b for Opus-run workflows have been silently wrong; fixing the price table in that spec is bundled here as a corrective Modified Capability.

## What Changes

- **NEW** `skills/claudboard/scripts/compute-cost.sh` — bash + jq script that parses a Claude Code session JSONL, dedups by `requestId` (each assistant API call writes one line per content block — thinking, text, each tool_use — sharing the same `usage` object; naive sums over-count 3-4×), sums the five token fields, multiplies by the per-model price table, emits a one-line summary. Accepts `--since <ISO-timestamp>`, `--until <ISO-timestamp>`, `--format one-line|json`, and the JSONL path as a positional argument (or `$CLAUDE_SESSION_JSONL`).
- **NEW** `skills/claudboard/references/pricing.md` — versioned static price table with `effective_from` dates per model, covering Opus 4.7 ($15 / $18.75 / $30 / $1.50 / $75 per M for input / cache_write_5m / cache_write_1h / cache_read / output), Sonnet 4.6 ($3 / $3.75 / $6 / $0.30 / $15), Haiku 4.5 ($1 / $1.25 / $2 / $0.10 / $5). Single source of truth for both this change and the future Modified-Capability migration of `automated-cost-computation`.
- **NEW** opt-in `Stop` hook documented in the claudboard README for `settings.json`. Hook is gated: it fires only when the most recent user message in the JSONL begins with `/analyse`, `/generate`, `/refresh`, or `/techdebt`. When the gate matches, it invokes `compute-cost.sh --since <matching-prompt-timestamp>` and prints `Cost for /<cmd>: $X.XX (Model, N calls, K out)`. Costs $0 in API tokens — the hook runs outside the model.
- **NEW** in-progress detection: when the gate matches but the most recent assistant content includes an `AskUserQuestion` tool_use (Claude is paused waiting on the user), the line is suffixed with `(in progress)`.
- **MODIFIED** `automated-cost-computation` spec — correct the Opus 4.7 price row from `$5 / $6.25 / $10 / $0.50 / $25` to `$15 / $18.75 / $30 / $1.50 / $75`. No other change to that spec's behaviour in this proposal; deeper refactor (pointing Phase 7b at the shared `references/pricing.md`) is deferred to a follow-up to keep this change tightly scoped.
- **No change** to existing `claudboard-analyse`, `claudboard-generate`, `claudboard-refresh`, `claudboard-techdebt` sub-skill SKILL.md files. The hook attaches at the harness level, not inside the skills.

## Capabilities

### New Capabilities

- `cost-reporting`: precise per-task cost computation from the Claude Code session JSONL, with hooked emission on claudboard task boundaries and a versioned model price table. Covers the dedup-by-requestId contract, the slice semantics (matching-trigger user prompt → now), the in-progress detection heuristic, the unknown-model warning behaviour, and the SDK-compatible script invocation contract (JSONL path passed as argument, not auto-discovered from cwd).

### Modified Capabilities

- `automated-cost-computation`: pricing-rates table correction — Opus 4.7 rates restated to current Anthropic published rates. The behavioural requirements of the spec (locate JSONL, sum usage, build per-phase breakdown, post tracker comment) are not modified.

## Impact

- **Affected files (new):**
  - `skills/claudboard/scripts/compute-cost.sh` — new
  - `skills/claudboard/references/pricing.md` — new
  - `README.md` — append a documented opt-in hook block teammates can copy into their `settings.json`
- **Affected files (modified):**
  - `openspec/specs/automated-cost-computation/spec.md` — pricing rates row for Opus 4.7 corrected (via delta in this change's `specs/automated-cost-computation/spec.md`)
- **Affected files (unchanged):**
  - `skills/claudboard-analyse/SKILL.md`, `skills/claudboard-generate/SKILL.md`, `skills/claudboard-refresh/SKILL.md`, `skills/claudboard-techdebt/SKILL.md` — no edits; the hook attaches at the harness level, not inside the skills
  - `skills/claudboard-workflow/**` — feature-workflow Phase 7b consumers will inherit the corrected Opus 4.7 rates when the `automated-cost-computation` spec is re-read; no template changes are required by this proposal
- **SDK compatibility:** The Claude Agent SDK writes JSONL to the same `~/.claude/projects/<slug>/` location and honors `settings.json` Stop hooks. The script accepts the JSONL path as an argument (or reads `$CLAUDE_SESSION_JSONL`) so SDK runs with custom session IDs work without modification. No SDK-specific code path is added.
- **Downstream consumers:** none required to change. Users opt in to the hook by editing their own `settings.json`; the README documents the snippet.
- **Risks:**
  - *JSONL schema drift* — if the harness changes the `usage` block shape, the script breaks. Mitigation: assert on presence of expected fields, emit a clear error pointing at the assumed schema, log the unrecognised field shape for debugging.
  - *Pricing-table staleness* — Anthropic price changes require a manual edit to `references/pricing.md`. Mitigation: `effective_from` dates per entry, plus the script warns loudly when `.message.model` is not in the table (so a newly-released model surfaces the gap on the first run).
  - *Hook over-emission* — the gate ("last user message starts with a known trigger") is a heuristic. False positives are possible (e.g. a user types `/analyse` in chat without invoking the skill). Documented as a known limitation; revisit if it produces noise in practice.
  - *Modifying `automated-cost-computation`* — the price-row correction changes a number, not a behaviour, so no Phase 7b runs need to be replayed; future runs will use the corrected rates. Past tracker comments that quoted under-priced Opus 4.7 totals are left as-is.
- **Out of scope (deferred to follow-up changes):**
  - Feature-workflow per-phase cost emission (the workflow has multiple phase boundaries per session; hook gating becomes ambiguous).
  - Live cost-estimation agent that projects cost of prospective actions before they run.
  - Cost reporting for non-claudboard tasks (`/code-review`, `/security-review`, etc.) — same script could be wired up but trigger list is claudboard-scoped for v1.
  - Refactoring `automated-cost-computation` to consume `references/pricing.md` as its source of truth instead of the in-spec table.
  - Per-model cost dashboards or time-series analysis.
