## Context

Three skills (`claudboard-generate`, `claudboard-refresh`, `claudboard-workflow`) each pause at the same architectural point — right before files write — and ask the user to confirm the operation they just invoked. This change removes those pauses while preserving the summary content. The design questions are about which adjacent affordances to keep, drop, or replace.

## Decision 1: Drop or keep the `selective` / `edit` options?

`claudboard-refresh` offers `[y/n/selective]` and `claudboard-workflow` offers `[y/n/edit]`. These options DO encode real user intent that plain y/n doesn't.

Options considered:

1. **Drop them entirely.** Users who want partial application or to fix a TODO stub interrupt mid-stream and converse with the skill.
2. **Keep them as opt-in non-blocking hints.** Print "If you want to edit a value or skip parts, interrupt and tell me." Then proceed.
3. **Convert them to upstream prompts.** Move "selective?" / "edit?" earlier in the workflow as part of the planning phase, where they're decisions rather than gates.

**Decision: Option 1 (drop them).** Rationale:

- In practice the `selective` / `edit` flows are rarely used. The static structure has no recovery loop or retry beyond "re-show the summary" — they read more like designed-for-completeness affordances than designed-for-use.
- The interrupt-and-converse model matches Claude Code's natural interaction pattern better than a structured y/n/edit branch.
- The summary is still printed inline, so a user who spots a TODO stub or wrong scope can interrupt immediately and redirect.

If usage data later shows users want a structured edit affordance, it can be added back as a separate, opt-in prompt in a future change.

## Decision 2: How "informational" is the summary?

Two interpretations:

1. **Print and pause briefly** (e.g., wait 2-3 seconds) so the user can see what's about to happen.
2. **Print and proceed** with no artificial pause.

**Decision: Option 2 (print and proceed).** Rationale:

- The summary prints before file writes start; the user sees it before any side effect occurs.
- File writes themselves take noticeable wall time (multiple `Write` and `Edit` tool calls in sequence), giving the user a natural reading window to catch a problem and interrupt.
- Artificial pauses are friction without information.

## Decision 3: Which gates STAY?

The pause-on-real-decision behavior must be preserved. These all stay exactly as today:

| Trigger | Skill | Why it stays |
|---|---|---|
| Analysis report has `ASK USER` markers | claudboard-generate | Report author explicitly deferred a decision to the user |
| Stale-report warning (>24h) | claudboard-generate | Information the user needs before proceeding |
| Mutually-exclusive repo flags both true | claudboard-workflow | Config conflict that can't be auto-resolved; mutex error halt is a separate requirement in the spec |
| Generated `feature-workflow`'s autonomy / synthesis / 1d gates | (lives inside generated skill, not invoked here) | Different design surface; not affected by this change |

## Decision 4: New cross-cutting capability spec, or modify the one existing spec only?

`claudboard-generate` and `claudboard-refresh` have no spec coverage today. Options:

1. **Create a new cross-cutting capability** (e.g., `informational-pre-write-summary`) and add requirements for all three skills.
2. **Modify only `feature-workflow-generation`** (the one spec that already covers this) and treat the generate/refresh changes as tasks-only.

**Decision: Option 2 (modify one spec, tasks-only for the others).** Rationale:

- Avoids creating a tiny capability just for one rule.
- Generate/refresh have no spec coverage for any of their behavior today; backfilling spec coverage selectively for one requirement creates a half-spec'd skill, which is worse than no spec.
- The change's `proposal.md` and `tasks.md` document the consistent behavior across all three skills, so the intent is recorded even though only one spec is delta'd.

A full spec-backfill for `claudboard-generate` and `claudboard-refresh` would be a separate, larger change.

## Decision 5: What hint text after the summary?

The hint needs to communicate two things: (1) the orchestrator is about to write files, (2) the user can stop it.

Options:

1. `I'll proceed now — interrupt with Esc to abort or adjust.`
2. `Writing files... press Esc to stop.`
3. No hint — let users discover the affordance.

**Decision: Option 1.** Rationale: explicit, mentions both abort and adjust, frames the upcoming action ("I'll proceed now") so the user knows the summary is the last informational moment. Keep the wording identical across all three skills for consistency.

## Open Questions

None.

## Out of Scope

- Per-file `Write(...)` / `Edit(...)` permission prompts (Claude Code harness / `settings.json` concern).
- Backfilling capability specs for `claudboard-generate` and `claudboard-refresh`.
- The autonomy / synthesis HALT / 1d gates inside generated `feature-workflow` skills (different design surface, fires at workflow runtime not at skill-invocation time).
- The `claudboard-techdebt` skill's Phase 3 confirmation (line 429 of its SKILL.md) — that gate is at a different position in the flow (after generating refactoring tickets, before writing them to disk) and serves a different purpose (review the ticket list, not "do you want to do what you asked"). Separate consideration; not in this change.
