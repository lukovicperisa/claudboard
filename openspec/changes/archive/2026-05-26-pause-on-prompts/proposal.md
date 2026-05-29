## Why

The `clarify-autonomy-and-synthesis` change (already merged) introduced two interactive checkpoints in the generated `feature-workflow` skill — the autonomy-level entry prompt and the synthesis-confirmation HALT — but described both with prose ("prompt the user", "Accept the response", "HALT") that does not map to the Claude Code harness's actual pause mechanics. Plain text printed by the assistant does NOT pause the CLI; only `AskUserQuestion` or an explicit end-of-turn returns control to the user.

Result: in real invocations the orchestrator prints the autonomy prompt and continues executing tools in the same turn, so the user sees a question they cannot answer and the workflow appears to "end" before it began. The user has reported this multiple times. The same risk exists at every other "halt / wait for user" point that relies on prose alone (1-syn confirm/correct loop, manual-mode `proceed`, blocker recovery).

This is a documentation-level defect in the SKILL template — no new feature, no behavior change beyond "actually pause when the spec says to pause."

## What Changes

- **REWRITTEN autonomy prompt section** in `SKILL.md.template`: replace the bare "print this line / accept the response" prose with an explicit instruction to use `AskUserQuestion` (primary path) with a documented fallback that requires ending the turn immediately after printing the prompt — and an inline note that text alone does NOT pause the CLI.

- **REWRITTEN synthesis-blocking rows** in the autonomy-behavior table: keep `HALT` as the marker but add a paragraph immediately under the table defining what HALT means mechanically (end of turn, no further tool calls until the user replies). Apply the same definition to all "wait for user", "halt and tell the user", and `proceed`-gated points elsewhere in the template.

- **NEW "Halt mechanics" callout** near the top of the SKILL template (right after "Project configuration"): one short subsection that states the two-mechanism rule (`AskUserQuestion` OR end-of-turn) once, so every later HALT/wait/prompt instruction can reference it.

- **NO config changes, NO substitution changes, NO new phases.** Pure clarification of existing instructions.

- **Already-generated SKILL files** in downstream projects (e.g. `craftsphere.cloud/.claude/skills/feature-workflow/SKILL.md`) are out of scope for this proposal — they are downstream artifacts of the prior generation run. Per the existing "v1 has no upgrade path" caveat in `CLAUDE.md`, those projects must re-run `/claudboard-workflow` to pick up the fix, or hand-patch in place.

## Migration for already-generated `feature-workflow/SKILL.md` files

Operators with an existing `.claude/skills/feature-workflow/SKILL.md` choose one of two paths:

**Path 1 — Regenerate (preferred when no feature is mid-flight):**
1. Delete `.claude/skills/feature-workflow/` in the downstream project.
2. Run `/claudboard-workflow` — the new generation includes the Halt-mechanics callout, the `AskUserQuestion`-based autonomy prompt, the HALT definition paragraph, and the audited halt/wait wording.

**Path 2 — Hand-patch in place (use when a feature is mid-flight in `.claude/changes/<TICKET>/` and you do not want to disturb phase state):**

Patch the existing `SKILL.md` at three locations. Line numbers below are from a freshly-generated file as of this change; in modified files, search by section heading.

| # | Location | Edit |
|---|---|---|
| 1 | Insert a new `## Halt mechanics` subsection immediately before `## Clarification autonomy` (around line 191 in the craftsphere copy, line 386 in the template). | Copy the "Halt mechanics" paragraph from the template verbatim. |
| 2 | In the `## Clarification autonomy` section, replace the "prompt the user … Accept the response and hold" prose block with the `AskUserQuestion` primary instruction + the "If `AskUserQuestion` is unavailable" end-of-turn fallback. | Copy the rewritten section from the template verbatim. |
| 3 | In the "Blocking behavior by autonomy level" table (around line 457 in the craftsphere copy, line 743 in the template), insert the "**HALT means: end the turn immediately after printing the synthesis.**" paragraph immediately below the table and before "**Correction loop**". | Copy the HALT-definition paragraph from the template verbatim. |

Optionally also patch the two audited halt points: the T&R "Halt immediately and tell the user" block and the failed-agent "wait for guidance" block — both gain "and end the turn" qualifiers. These are lower-frequency hits than the autonomy prompt but worth folding in to avoid the same defect recurring under different conditions.

After hand-patching, no further action is required; the orchestrator picks up the new wording on the next workflow invocation.

## Capabilities

### Modified Capabilities

- `feature-workflow-generation`: Generated `feature-workflow` skills SHALL pause the CLI at every documented interactive checkpoint by using `AskUserQuestion` or by ending the turn immediately after printing the prompt; the template SHALL state the two-mechanism rule explicitly and reference it from every HALT/wait/prompt point.

## Impact

- **Files modified:**
  - `skills/claudboard-workflow/references/feature-workflow.template/SKILL.md.template` — rewrite autonomy prompt section; add "Halt mechanics" callout; add HALT-definition paragraph under the autonomy behavior table; audit other "wait for user" / `proceed` points for the same wording.

- **Out of scope (explicit):**
  - Backfilling already-generated `.claude/skills/feature-workflow/SKILL.md` files in downstream projects (manual patch or re-generation by operator).
  - Any change to autonomy semantics, the synthesis phase, the Clarify rubric, or the 1d gate.
  - Any change outside the clarification flow (Phases 2-7, blocker recovery, PR phase, etc.).

- **No version bump implied** — patch-level docs fix.
