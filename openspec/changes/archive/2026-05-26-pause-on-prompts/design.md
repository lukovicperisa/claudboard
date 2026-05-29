## Context

The Claude Code harness pauses the CLI in exactly two ways:

1. The orchestrator calls `AskUserQuestion` (structured prompt with options).
2. The orchestrator ends its turn — no further tool calls, no further text in the same response.

Plain text output does NOT pause the CLI. The harness treats text as streaming output, not as a synchronous read; control only returns to the user at the end of a turn or via an explicit interactive tool.

The `clarify-autonomy-and-synthesis` change (already merged) added two interactive checkpoints to the generated `feature-workflow` skill — an autonomy-level entry prompt and a synthesis-confirmation HALT — but described them with prose that doesn't reflect those mechanics:

```
Clarification autonomy: {{CLARIFY_AUTONOMY_DEFAULT}} — accept [Enter] or
override [a / b / c / d]?
```
> "Accept the response and hold the resolved level…"

The orchestrator reads "prompt the user" and "accept the response" as English instructions, not as a halt directive. In practice the orchestrator prints the prompt, immediately calls more tools (or summarizes, or transitions phases), and the user sees a question they cannot answer. The workflow appears to "end" before it began. The same hole exists at every other prose-only pause point in the template: the 1-syn `HALT. Wait for user to respond…` rows, the manual-mode `continues only when user types proceed`, the `halt and tell the user` blocker recovery, and the `wait for guidance before retrying` of the failed-agent path.

The earlier change shipped four documented blocking checkpoints; in real invocations none of them block reliably.

## Goals / Non-Goals

**Goals:**
- Every documented interactive checkpoint in the generated `feature-workflow` actually pauses the CLI.
- The template states the harness's pause mechanics once, centrally, so future authors don't repeat the same wording mistake.
- Existing semantics (autonomy levels, synthesis loop, gate behavior, blocker recovery) are unchanged — pure docs/wording fix.

**Non-Goals:**
- Backfilling already-generated `feature-workflow/SKILL.md` files in downstream projects (operator hand-patch or re-generation per existing "v1 has no upgrade path" convention).
- Changing the prompt copy itself (the user-facing prompt strings stay byte-identical; only the surrounding instructions to the orchestrator change).
- Replacing the four-level autonomy model, the 1-syn phase, the rubric, the assumptions list, or any other artifact of the prior change.
- Adding a sub-agent or a new phase. This is a template wording fix; no new orchestration surface.
- Building a lint check that scans generated SKILL.md files for compliance (worthwhile follow-up, but out of scope here).

## Decisions

### Decision 1: `AskUserQuestion` is the primary pause mechanism

Where the prompt has a small, enumerable option set, the orchestrator uses `AskUserQuestion`:

```
AskUserQuestion({
  question: "Clarification autonomy: <default> — accept default or override?",
  header: "Autonomy",
  options: [
    "Accept default (<default>)",
    "a — autopilot",
    "b — balanced",
    "c — guided",
    "d — manual"
  ]
})
```

**Why:**
- `AskUserQuestion` is the harness's purpose-built interactive primitive — discoverable in the UI, structured for the user, and unambiguously halting for the orchestrator.
- The four autonomy levels are exactly the kind of small, fixed enumeration `AskUserQuestion` is designed for.
- The "Accept default" entry as the first option mirrors the existing "press Enter to accept" UX from the prose prompt.

**Why not "always AskUserQuestion":**
- Synthesis confirmation accepts free-form text (`confirm` or `correct: <feedback>` with an open-ended feedback string). `AskUserQuestion` is poorly suited to free text — its strength is the option list.
- Manual-mode `proceed` is similarly open-ended.
- Blocker-recovery `wait for guidance` is open-ended.

So `AskUserQuestion` covers the autonomy prompt cleanly, but the rest need the second mechanism.

### Decision 2: End-of-turn is the universal fallback

For every prompt where `AskUserQuestion` is unsuitable, OR where `AskUserQuestion` is unavailable (e.g., the orchestrator is running under a sub-agent context that doesn't expose it), the instruction becomes: **print the prompt, then end the turn immediately — no further tool calls, no further text.**

**Why:**
- End-of-turn is universal: it always returns control to the user, regardless of context, sub-agent depth, or tool availability.
- It's the natural pause point for free-form responses (synthesis correction, `proceed`, blocker guidance) — the user types freely; the orchestrator picks up on the next turn.
- It requires no new tooling, no new template machinery, only correct wording.

**Why explicit "do not call another tool, do not summarize":**
- The orchestrator's failure mode is helpful continuation — it sees "print the prompt" and assumes a natural follow-up is allowed (e.g., "While we're waiting, let me prepare X…").
- Explicit negation closes the loophole. The instruction must be a clear "stop here" rather than "ask and continue".

### Decision 3: One central "Halt mechanics" callout, referenced from every prompt point

Rather than annotate every HALT / wait / `proceed` / prompt instruction with the full two-mechanism rule, the template gets a single new subsection near the top:

```
## Halt mechanics

The CLI pauses ONLY when the orchestrator calls AskUserQuestion or ends its
turn (no further tool calls, no further text in the same response). Plain
text output does NOT pause the CLI. Every later instruction in this
document using the words "prompt", "HALT", "wait for user", "halt and tell
the user", or `proceed` MUST be interpreted under this rule.
```

Every later prompt point then either uses the new wording inline (autonomy prompt, synthesis HALT row) or references this section ("see Halt mechanics").

**Why centralize:**
- DRY — the rule is identical at every point; restating it in eight places invites drift.
- A single normative statement is easier to keep accurate over time than eight scattered restatements.
- Adding new prompt points in the future is a one-line reference, not a copy-paste of mechanics.

**Why also annotate the high-traffic points inline:**
- The autonomy prompt is the first interactive checkpoint a user hits; the wording there has been demonstrably misread, so it gets explicit inline instructions in addition to the central reference. Belt-and-suspenders only at the most-failing point.
- The synthesis HALT table row needs an inline paragraph because the table format makes a cross-reference awkward.

### Decision 4: Keep the `HALT` vocabulary; add a definition paragraph

The existing template uses `HALT` as a marker word in the autonomy behavior table. Rather than replace it with a verbose instruction in each row, add one paragraph immediately below the table:

```
**HALT means: end the turn immediately after printing.** Do not call any
further tool until the user replies. The CLI does not pause on plain text —
only AskUserQuestion or end-of-turn returns control.
```

**Why:**
- `HALT` reads well as a state marker in the per-level behavior table; replacing it row-by-row bloats the table.
- A definition paragraph attached to the table is a familiar pattern (legend below a chart).
- It binds the abstract marker to the concrete mechanic without restructuring the table.

### Decision 5: No backfill of downstream projects in this change

Already-generated `feature-workflow/SKILL.md` files in downstream projects (e.g., `craftsphere.cloud/.claude/skills/feature-workflow/SKILL.md`) are not touched by this change. The proposal documents two hand-patch locations for operators who need an immediate fix; otherwise they re-run `/claudboard-workflow` after this change merges.

**Why:**
- The repo's standing convention (`CLAUDE.md`: "v1 has no upgrade path") puts the regeneration burden on the operator.
- The template fix and the downstream backfill are independently risky — coupling them would force a coordinated rollout for a docs change.
- Operators with active feature work mid-flight may prefer to hand-patch the in-place file rather than regenerate (which could disturb in-progress phase state in `.claude/changes/<TICKET>/`). The migration note in `tasks.md §6` supports both options.

## Risks / Trade-offs

- **[Risk] The orchestrator may still "helpfully continue" past an end-of-turn instruction.** The fix relies on model discipline — there's no harness-side enforcement of "this prompt point requires end-of-turn." → **Mitigation:** the wording is explicit and negation-based ("do not call another tool, do not summarize"). For the autonomy prompt — the demonstrated failure point — `AskUserQuestion` provides harness-enforced halting and is the primary mechanism. End-of-turn is only the fallback path or used where `AskUserQuestion` doesn't fit (free-form replies).

- **[Risk] `AskUserQuestion` may not be available in all orchestrator contexts.** If the generated workflow runs under a sub-agent that doesn't expose `AskUserQuestion`, the primary mechanism silently fails. → **Mitigation:** the fallback path is explicit and self-sufficient (end-of-turn requires nothing). The wording lists both mechanisms in priority order, so the orchestrator always has a working option.

- **[Risk] Centralizing the rule in one subsection means a reader who jumps directly to a later phase may miss it.** → **Mitigation:** the high-traffic prompt points (autonomy section, HALT table row) get inline annotations in addition to the central reference. The central subsection is short and high in the document, so a top-to-bottom reading hits it before any prompt point.

- **[Risk] Adding the "Halt mechanics" subsection shifts line numbers in the generated SKILL.md; any tooling or test that greps by line number breaks.** → **Mitigation:** no known tooling depends on line numbers in generated SKILL.md files. The substitution catalog operates on `{{VAR}}` markers, not positions.

- **[Trade-off] Keeping the `HALT` vocabulary vs replacing with imperative "end the turn".** Keeping it preserves the existing table shape and is less invasive; replacing would be more direct but bloats the table and forces edits to other documents that reference HALT terminology. Decision: keep + define.

- **[Trade-off] Single-change scope (autonomy + synthesis + miscellaneous waits) vs splitting per checkpoint.** Splitting would isolate the autonomy fix from the synthesis fix from the blocker-recovery fix. Decision: keep as one change — the root cause is identical, the wording fix is identical, and operators would not benefit from staged rollout of a docs change.

## Migration Plan

This is a template-only docs change. No runtime data, no config schema, no API surface.

**For new projects (post-merge):**
- Run `/claudboard-workflow` — the generated `feature-workflow/SKILL.md` includes the Halt-mechanics callout, the `AskUserQuestion`-based autonomy prompt, and the HALT definition under the table.

**For existing projects with previously-generated `feature-workflow/`:**

Two options for the operator:

1. **Regenerate (preferred):** remove `.claude/skills/feature-workflow/` and re-run `/claudboard-workflow`. Per the standing v1 convention.
2. **Hand-patch in place:** apply the same wording edits to the existing file. Two patch locations:
   - The `## Clarification autonomy` section — replace the "prompt the user / Accept the response" instruction with the `AskUserQuestion` + end-of-turn fallback wording.
   - Immediately under the autonomy-behavior table — insert the one-paragraph HALT definition.

   Operators with an in-flight feature in `.claude/changes/<TICKET>/` should prefer hand-patch to avoid disturbing phase state.

**Backward compatibility:**
- Generated SKILL.md files that don't have the new wording continue to work standalone (they're already-running template output). They will continue to exhibit the pause-failure bug until patched or regenerated.
- No config changes, no payload changes, no migration of persistent state.

**Rollback:**
- Revert this change. New generations revert to old (broken) wording. Existing generated files keep whatever wording they were generated with.

## Resolved Questions

- **Is `AskUserQuestion` available in the orchestrator's runtime context?** YES for the top-level `/start-feature` orchestrator. For sub-agent contexts, availability is not universal — hence the end-of-turn fallback is mandated in the wording for the autonomy prompt itself, not just for the free-form prompts.

- **Why not enforce halting harness-side instead of via wording?** Out of scope — harness-side enforcement would require changes to Claude Code itself. The wording fix is a self-contained template-level remedy and the right granularity for this defect.

- **Should the central "Halt mechanics" subsection live in the template or in the `block-catalog.md` reference?** In the template. The catalog is a reference for the generator; the SKILL.md is what the orchestrator actually reads at runtime. The rule must be in the runtime-loaded file.

- **Do we add a lint/test that scans generated SKILL.md files for prose-only prompts?** Worthwhile but out of scope for this change. Tracked separately if the pattern recurs.
