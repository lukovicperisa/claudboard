## Why

Three claudboard skills — `claudboard-generate`, `claudboard-refresh`, and `claudboard-workflow` — each pause and wait for a `[y/n]`-style confirmation at a "Phase N: Confirmation" step before writing any files. The user already invoked the skill explicitly (typed `/generate`, `/refresh`, or `/claudboard-workflow`). Asking "do you want to do the thing you just asked me to do?" is friction without information.

Concretely:

- `skills/claudboard-generate/SKILL.md` Phase 2 (lines 86-90): `Generate these artifacts? [y/n]` followed by `**Pause here.** Wait for user confirmation before proceeding.`
- `skills/claudboard-refresh/SKILL.md` Phase 4 (lines 209-213): `Apply these updates? [y/n/selective]` followed by `**Pause here.** Wait for user confirmation.`
- `skills/claudboard-workflow/SKILL.md` Phase 5 (lines 262-308): `Proceed? [y/n/edit]` with on-`n` / on-`edit` branches.

Each gate currently conflates two jobs under one UI element:

- **Show the user what's about to happen.** Legitimately useful — lets the user catch a runaway scope before files write.
- **Block until they reply.** Redundant given the explicit invocation.

This change splits those jobs: keep the summary, drop the block. Pause-on-real-decision behavior (analysis-report `ASK USER` markers, mutually-exclusive-flag errors, stale-report warnings) is preserved.

## What Changes

- **`claudboard-generate` Phase 2:** Print the Proposed Artifacts summary inline, then proceed directly to Phase 3 with no `AskUserQuestion` call and no end-of-turn pause. The existing `ASK USER markers` pause in Phase 3 error handling (line 225) and the stale-report warning in Phase 1b (line 55) are unchanged.

- **`claudboard-refresh` Phase 4:** Print the proposed updates summary inline, then proceed directly to Phase 5. The `[y/n/selective]` prompt is removed. The `selective` flow is dropped — users who want partial application can interrupt and direct the skill conversationally.

- **`claudboard-workflow` Phase 5:** Print the "Ready to Generate" summary inline, then proceed directly to Phase 6. The `[y/n/edit]` prompt and the `edit` loop are removed. Users who want to fix a TODO stub before files write can interrupt; the existing mutually-exclusive-repo error halt (line 271-272 of the spec) stays.

- **All three skills:** End the summary with a one-line hint (e.g., `I'll proceed now — interrupt with Esc to abort or adjust.`) so users know the affordance is there.

- **MODIFIED capability spec `feature-workflow-generation`:** The `User-facing confirmation gate` requirement is replaced with an `Informational pre-write summary` requirement — same summary content, no block.

- **NO change to:** the `ASK USER` markers pause in `claudboard-generate`, the stale-report warning in `claudboard-generate`, the mutex-flag error halt in `feature-workflow-generation` (line 271-272), the synthesis HALT in generated `feature-workflow` skills, the Phase 1d gate in generated `feature-workflow` skills, the autonomy-level prompt at workflow entry in generated `feature-workflow` skills.

## Capabilities

### Modified Capabilities

- `feature-workflow-generation`: The `User-facing confirmation gate` requirement SHALL be replaced with an `Informational pre-write summary` requirement that mandates the same summary content (file tree, enabled capability blocks, resolved config values) but explicitly forbids blocking on user input for the proceed step.

## Impact

- **Files modified:**
  - `skills/claudboard-generate/SKILL.md` (Phase 2)
  - `skills/claudboard-refresh/SKILL.md` (Phase 4, and Phase 5 rename — "Selective Generation" → "Generation")
  - `skills/claudboard-workflow/SKILL.md` (Phase 5)
  - `openspec/specs/feature-workflow-generation/spec.md` (one requirement)

- **Friction removed per run:** One mandatory user keystroke per skill invocation, plus the context-switch cost of being interrupted at an arbitrary point in a chain of skill calls.

- **Risk:** Users who relied on the y/n pause to bail out of a wrong invocation lose that explicit stop. Mitigation: the inline summary is preserved before any file writes start, file writes themselves take noticeable wall time, and the `interrupt with Esc` hint makes the bail-out affordance discoverable.

- **Eval requirement:** One smoke test per skill — run end-to-end against a known good project and confirm: (a) the summary prints, (b) no `AskUserQuestion` or end-of-turn pause fires at the proceed step, (c) files are written, (d) genuine decision pauses (`ASK USER` markers, mutex errors) still fire when their triggers are present.

- **Out of scope (explicit):**
  - **Per-file `Write(...)` / `Edit(...)` permission prompts.** That is a Claude Code harness / `settings.json` concern, not a skill-level concern. Addressed separately by the user's permission configuration (e.g., `Write(*/.claude/**)` in `~/.claude/settings.json`, or running with `--permission-mode acceptEdits`).
  - **Backfilling capability specs for `claudboard-generate` and `claudboard-refresh`.** Those skills have no current spec coverage for their confirmation behavior, so the changes there are captured in `tasks.md` only. Spec-coverage backfill is a separate change.
  - **The autonomy / synthesis HALT / 1d gates inside generated `feature-workflow` skills.** Different design surface — those fire at workflow runtime, not at skill-invocation time.
