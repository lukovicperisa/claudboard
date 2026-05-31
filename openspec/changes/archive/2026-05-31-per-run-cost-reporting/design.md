## Context

Claude Code persists every turn of every session to a JSONL transcript at `~/.claude/projects/<cwd-slug>/<session-id>.jsonl`. Each line of that transcript is a turn event with a precise `timestamp`, an authoritative `requestId`, and — for assistant turns — a full `usage` object enumerating `input_tokens`, two flavours of `cache_creation` writes, `cache_read_input_tokens`, and `output_tokens`. The Claude Agent SDK writes to the same location with the same shape. Pricing per model is published by Anthropic and stable enough to be embedded as a versioned static table.

Together those facts mean per-task cost is **already on disk** for every run; the only thing missing is the convention by which a task slice gets sliced, summed, priced, and surfaced. Today the only cost signal a user sees is `/usage`'s 24h rolling total — too coarse to attribute cost to a specific `/analyse`, too late to inform decisions.

A second-order observation: the existing `automated-cost-computation` spec (which feature-workflow Phase 7b uses to post tracker comments) carries Opus 4.7 rates from an older publication ($5 base / $25 output), ~3× under current rates. This change corrects that as a strictly local edit.

## Goals / Non-Goals

**Goals:**

- Provide a single, reusable script (`skills/claudboard/scripts/compute-cost.sh`) that turns a session JSONL + time slice into a precise cost number, with zero estimation.
- Emit a one-line cost summary at the end of every `/analyse`, `/generate`, `/refresh`, `/techdebt` run via a Stop hook that costs $0 in API tokens.
- Make the price table a versioned static document at `skills/claudboard/references/pricing.md` so corrections (like the Opus 4.7 fix being bundled here) are documented and auditable.
- Work identically for interactive CLI users and Claude Agent SDK consumers (Node.js, etc.).
- Surface the dollar-impact of model choice — every emission names the model.
- Fix the Opus 4.7 rate in `automated-cost-computation` so feature-workflow Phase 7b tracker comments stop under-pricing Opus-run workflows.

**Non-Goals:**

- Feature-workflow per-phase cost lines (Phase 1, Phase 2, etc.). The workflow has multiple Stop events per session and the hook gating becomes ambiguous; deferred to a follow-up change.
- A live cost-estimation agent that projects cost of prospective actions before they run. Deferred — needs Layer 1 + Layer 2 as foundation and historical run data to be useful.
- Cost reporting for non-claudboard tasks (`/code-review`, `/security-review`, etc.).
- Refactoring `automated-cost-computation` to consume `skills/claudboard/references/pricing.md` as its source of truth (it currently embeds rates in the spec text). Pricing duplication is documented as known debt; consolidation is a follow-up.
- Per-model dashboards, time-series analysis, budget alerts.
- Auto-installing the hook into the user's `settings.json`. Opt-in only.

## Decisions

### D1. Emission via Stop hook, not skill convention

Two emission mechanisms were considered:

- **(A) Stop hook in `settings.json`** — bash script runs at task end, outside the model. Costs $0 in API tokens. ~0.5-1s wall-clock per fire.
- **(B) Skill convention** — each claudboard sub-skill's SKILL.md instructs the model to call `compute-cost.sh` near the end of its run. Costs one extra model turn per task end, ~$0.13 on Opus 4.7 (mostly cache_read for the cached prefix), ~$0.025 on Sonnet, ~5-15s wall-clock.

**Decision: Option A.** The four v1-targeted tasks (`/analyse`, `/generate`, `/refresh`, `/techdebt`) each have exactly one clean end point. Stop hook gated on "last user message begins with a known trigger" handles that boundary cleanly with no measurement tax. The skill-convention's ~$0.13 per emission is small but ironic given this change is partly motivated by a prior proposal (`speed-up-analyse`) about *reducing* cost.

Option B becomes more attractive when extending to feature-workflow per-phase emission (multiple ends per session, harder to detect from a hook) — that's deferred and out of scope.

### D2. Dedup by `requestId`, not by JSONL line

The session JSONL writes **one line per assistant content block** (one for the `thinking` block, one for the `text` block, one for each `tool_use` block). All those lines share the same `requestId` and the same `usage` object. Summing usage per-line over-counts by 3-4× (typical assistant turn has 3-4 blocks).

**Decision: the script dedups by `requestId` before summing.** Every requirement and every implementation reads from a `requestId`-deduped projection of the JSONL.

This is documented as a first-class requirement in `specs/cost-reporting/spec.md` and as the first listed "common pitfall" in the script's header comment, because it was the bug in my own first-pass estimate today and would have been the bug in any naive future re-implementation.

### D3. Slice semantics: matching-trigger user prompt → now

Two slice models were considered:

- **(A) Whole-session running total.** What `/cost` shows. Trivial to compute. Useless for per-task attribution.
- **(B) Slice from last user prompt → now.** Per-segment cost. Mid-task user clarifications would reset the slice and break attribution.
- **(C) Slice from matching-trigger user prompt → now.** Walks back through user messages to find the most recent one that starts with `/analyse`, `/generate`, `/refresh`, or `/techdebt`. Mid-task clarifications (like "Yes proceed") are ignored.

**Decision: Option C.** Matches the user's stated requirement ("when I run /claudboard-analyse, I want cost only for that, even if it's in the same session as /claudboard-generate"). Handles multi-prompt tasks (clarifications) naturally. Implementation is a single jq pass back through `type: user` entries.

### D4. In-progress detection via `AskUserQuestion` tool_use heuristic

The Stop hook fires on every model "stop" event, including intermediate ones where Claude has asked the user a question and is awaiting reply. We need to distinguish "task done" from "task paused for input."

The cleanest deterministic signal in the JSONL is: the most recent assistant message's content includes a `tool_use` block whose `name == "AskUserQuestion"`. When present, the emission is suffixed `(in progress)`.

**Decision: ship D4 as a labelled heuristic, not a hard guarantee.** A task could pause for user input via other means (e.g. waiting for the next message because Claude completed but the user is mid-thought). Those cases will emit without the suffix, which is harmless — the final emission on actual task completion will overwrite the user's mental model.

### D5. Versioned static price table, not fetched

Three options considered:

- **(A) Fetch from Anthropic pricing endpoint at runtime.** No such public endpoint exists. Would require scraping the pricing page, which is fragile and adds a network failure mode to every cost emission.
- **(B) Hard-coded constants in the script.** Easy. Updates require code edits and have no audit trail.
- **(C) Versioned static Markdown table** at `skills/claudboard/references/pricing.md` with one row per model per rate-change, each carrying an `effective_from` ISO date. Loud `WARN` to stderr when the script sees an unknown model ID.

**Decision: Option C.** Manual updates are acceptable because the unknown-model warning surfaces staleness on the next run after a new model release. The `effective_from` column enables future support for historical re-pricing (price a turn at the rate in effect when it occurred) if Anthropic ever does a rate change mid-session.

For v1 the script SHALL pick the row with the latest `effective_from` ≤ the turn's timestamp, which is identical to "pick the latest row" for the initial single-row-per-model table. The historical-pricing capability falls out for free if multiple rows accumulate over time.

### D6. Script location: `skills/claudboard/scripts/compute-cost.sh`

Three options considered:

- **(A) New top-level `skills/claudboard-cost/`** sub-skill. Discoverable via the index. Adds another sub-skill which is overhead for what is currently a single script.
- **(B) Shared `skills/claudboard/scripts/compute-cost.sh`** alongside the dispatcher SKILL.md. Reusable by all sibling sub-skills via relative path. No new index entry.
- **(C) Start under `skills/claudboard-analyse/scripts/`**, generalise later. Lowest commitment but creates a duplication burden once `/generate` and `/refresh` want it.

**Decision: Option B.** Matches the user's locked choice. The script is utility infrastructure, not a user-invokable skill. Top-level promotion can happen later if a `claudboard-cost` skill ever ships with multiple scripts and references.

### D7. Bundle the Opus 4.7 price correction with this change

The existing `automated-cost-computation` spec lists Opus 4.7 at $5 base / $25 output (~3× under actual $15 / $75). Feature-workflow Phase 7b has been posting under-priced tracker comments for Opus runs.

**Decision: include a MODIFIED delta for `automated-cost-computation` in this change, scoped strictly to the price-row correction.** No behavioural change. No refactor to share `references/pricing.md` as the source of truth (deferred). This keeps the change tightly scoped while preventing the new `cost-reporting` capability from shipping with a contradictory rate live elsewhere in the repo.

## Risks / Trade-offs

- **[JSONL schema drift]** If the harness changes the `usage` block shape (e.g. renames `cache_creation.ephemeral_1h_input_tokens` or removes the `requestId` field), the script breaks silently or noisily depending on which way the change happens. **→ Mitigation:** the script asserts on the presence of every required field on the first turn it processes; missing fields emit a clear error pointing at the expected schema and the path to update the script. Schema-version regression caught on the first run, not silently amortised across weeks of wrong numbers.

- **[Pricing-table staleness]** Anthropic rate changes require a manual edit to `references/pricing.md`. **→ Mitigation:** the script's unknown-model warning catches new model IDs the first time they're seen. For silent rate-changes on existing models (no new ID), no automatic detection — relies on user awareness. The `effective_from` column documents when each rate was confirmed accurate; combined with a periodic manual sweep, this is good enough for v1.

- **[Hook over-emission]** The gate "last user message starts with a known trigger" is a heuristic. False positive: user types `/analyse` in chat without invoking the skill, then continues conversationally — the next Stop emits a (mostly-zero) cost line. False negative: user invokes `/analyse` via some indirect mechanism that doesn't begin the user message with literal `/analyse` (rare). **→ Mitigation:** documented as a known limitation in the README hook block. Revisit if it produces noticeable noise in practice.

- **[Spec duplication debt — pricing rates]** This change leaves rates duplicated between `references/pricing.md` (new) and `automated-cost-computation/spec.md` (existing, corrected). Future Anthropic rate change requires editing both. **→ Mitigation:** documented as known debt in the proposal's Out of Scope; the follow-up change to consolidate is named in the same section. Short-term acceptable because the cost of the bundling-with-this-change is small (a few rows, one model needs correction).

- **[`(in progress)` heuristic false negatives]** Tasks can pause for user input without invoking `AskUserQuestion` (model completed, user is composing reply). These emissions would not show the suffix. **→ Mitigation:** accept as a known limitation; user expectation is "in-progress is best-effort, final emission is authoritative." The final-on-completion emission overrides the mental model anyway.

- **[Versioned-pricing complexity for `effective_from`]** The "pick the row with latest `effective_from` ≤ turn timestamp" rule is overkill for v1's single-row-per-model table. Risk: implementation complexity exceeds the v1 benefit. **→ Mitigation:** for v1 the rule degenerates to "pick the latest row," same as "pick the single row." The infrastructure is in place for future historical pricing without adding implementation complexity today.

- **[Hook installation friction]** Opt-in means many users will never install the hook and never see cost lines. **→ Mitigation:** documented prominently in README. Consider auto-suggesting installation when claudboard first runs in a session (separate UX concern; not in this change).
