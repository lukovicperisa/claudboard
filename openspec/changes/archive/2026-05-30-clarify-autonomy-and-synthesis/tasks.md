## 1. Substitution and config plumbing

- [x] 1.1 Add `{{CLARIFY_AUTONOMY_DEFAULT}}` to `skills/claudboard-workflow/references/substitution-catalog.md` (source: `config.clarify.defaultAutonomy`, fallback: `balanced`, example: `balanced`)
- [x] 1.2 Add `clarify: { defaultAutonomy: "balanced" }` to `skills/claudboard-workflow/references/feature-workflow.template/config.json.template`
- [x] 1.3 Update `skills/claudboard-workflow/SKILL.md` orchestrator-output description to mention the new autonomy default in the completion report

## 2. SKILL.md.template — autonomy prompt section

- [x] 2.1 In `SKILL.md.template`, add a new section after the "Project configuration" validation and before "Phase 1: Ticket, clarify, specify, and plan": `## Clarification autonomy`
- [x] 2.2 The section documents the four autonomy levels (`autopilot` / `balanced` / `guided` / `manual`) with one-paragraph behavior description each
- [x] 2.3 The section instructs the orchestrator to read `config.clarify.defaultAutonomy` (fallback `balanced`) and prompt the user at workflow entry: "Clarification autonomy: {{CLARIFY_AUTONOMY_DEFAULT}} — accept [Enter] or override [a / b / c / d]?"
- [x] 2.4 The orchestrator HOLDS the resolved autonomy level (`autopilot` | `balanced` | `guided` | `manual`) throughout the workflow as `<autonomyLevel>`
- [x] 2.5 Document the resolved level is printed at workflow entry (e.g., "Clarification autonomy: autopilot — Clarify phase will be skipped; synthesis will print without blocking")
- [x] 2.6 Document the no-persistence rule explicitly: per-invocation overrides do NOT modify `config.json`; the next invocation re-prompts with the unchanged project default. Users who want a different project default edit `config.json` directly.
- [x] 2.7 Document that the orchestrator does NOT read or write any per-feature autonomy state under `.claude/changes/<TICKET>/`; autonomy is fresh per invocation

## 3. SKILL.md.template — new 1-syn phase

- [x] 3.1 Add `### 1-syn. Stated synthesis` section after `### 1-pre. Ticket setup` and before `### 1a. Clarify scope`
- [x] 3.2 Document the synthesis output shape: 2-3 paragraph plain-English summary; multi-ticket-only proposed slicing list; stated scope boundaries (in/out)
- [x] 3.3 Document blocking behavior by autonomy level: autopilot prints and continues; balanced/guided/manual print and HALT for user `confirm` or `correct: <feedback>`
- [x] 3.4 Document the correction loop: on `correct: <feedback>`, re-synthesize incorporating feedback verbatim, re-print, re-block. No upper limit on correction cycles.
- [x] 3.5 Document the ambiguous-correction rule: if the orchestrator cannot translate `correct: <feedback>` into a concrete revision (vague feedback, ambiguous referent), it MUST ask a targeted clarifying question about the feedback BEFORE re-synthesizing. No blind guessing.
- [x] 3.6 Document the context-grounding rule: before synthesizing, the orchestrator reads `CLAUDE.md`, `.claude/memories/ecosystem.md`, and (in workspace mode) per-repo analysis reports under `.claude/reports/` when present. Synthesis output references the project's actual services, vocabulary, and topology. When no context files exist, the synthesis output notes the fallback explicitly.
- [x] 3.7 Document that in `guided` mode with multi-ticket input, the blocking confirmation MUST cover both the prose summary AND the proposed slicing in a single exchange (no slicing auto-accept in guided)
- [x] 3.8 Update the Phase 1 flow diagram in the SKILL.md template to show 1-syn between 1-pre and 1a
- [x] 3.9 Update the workspace-mode Phase 1 flow diagram to include 1-syn (fires before 1a-ws affected-repos inference)

## 4. SKILL.md.template — rewritten 1a Clarify

- [x] 4.1 Rewrite `### 1a. Clarify scope` to branch on `<autonomyLevel>` (four sub-sections)
- [x] 4.2 `autopilot` sub-section: explicit instruction to skip 1a and proceed directly to 1b. Document the assumptions accumulated for the gate payload.
- [x] 4.3 `balanced` sub-section: define the 8-dimension enumeration rubric (target service, user-facing impact, constraints, actors, error/edge cases, authorization, integration boundaries, validation rules). Require the orchestrator to emit `clear: <statement>` or `unclear: <missing>` for EVERY dimension before any question. Every `unclear` becomes a question. Re-evaluate rubric after user answers; loop until all `clear`.
- [x] 4.4 `guided` sub-section: define the 3-dimension direction-only rubric (target service, change shape, scope boundary). Same emission rule (`clear`/`unclear`). Deferred dimensions (4-8) are added to the assumptions list for the gate.
- [x] 4.5 `manual` sub-section: retain free-form chat. Orchestrator asks the canonical 8 dimensions as conversation; continues only when user types `proceed` (or equivalent).
- [x] 4.6 Document that the rubric reasoning is presented to the user visibly (each dimension and its `clear`/`unclear` mark) in `balanced` and `guided` — the user can push back on a `clear` they disagree with
- [x] 4.7 Update the "After scope is fully clarified" ticket-description update logic to fire after Clarify completion in all autonomy levels (autopilot uses the post-synthesis scope as the clarified scope)

## 5. SKILL.md.template — 1a-ws workspace-mode autonomy gating

- [x] 5.1 In `<!-- IF WORKSPACE_MODE -->` block around `### 1a-ws. Affected repos inference and confirmation`, gate the user-confirmation step on `<autonomyLevel>`
- [x] 5.2 `autopilot`: auto-confirm the inferred repo list; add the auto-confirmation to assumptions
- [x] 5.3 `balanced`/`manual`: present the inferred list and require explicit user confirmation (current behavior)
- [x] 5.4 `guided`: present the list and require confirmation only if the architect-agent's confidence on any repo is low (i.e., justification text contains hedge words OR the inferred list has >5 repos); otherwise auto-confirm and add to assumptions

## 6. SKILL.md.template — 1d gate payload with assumptions

- [x] 6.1 Modify `### 1d. Gate — spec and plan review` to construct an `assumptions` field for the gate payload
- [x] 6.2 Document accumulation rules: autopilot accumulates every dimension as assumption; guided accumulates dimensions 4-8 plus auto-confirmed workspace decisions; balanced/manual accumulate only inferred decisions that the user did NOT explicitly correct during synthesis or clarification
- [x] 6.3 Update the `mcp__bosch__gate_request` call signature in the template to include `assumptions` in the payload object
- [x] 6.4 Document that `assumptions` MAY be an empty string (or empty array) when nothing was inferred without user input

## 7. Validation against real projects

- [ ] 7.1 Regenerate `feature-workflow/` into a single-repo test project (e.g., azure-devops-mcp), inspect the rendered SKILL.md, and verify the four sub-sections render correctly with no `<!-- IF -->` artifacts
- [ ] 7.2 Regenerate `feature-workflow/` into the MEAS workspace meta-repo and verify the workspace-mode 1a-ws section renders with autonomy-gated confirmation
- [ ] 7.3 Run a synthetic `/start-feature` with one ticket on a test project with default `balanced` autonomy: verify 1-syn fires and blocks, then 1a enumerates dimensions and asks about any `unclear`
- [ ] 7.4 Run a synthetic `/start-feature` with multiple ticket keys on a test project with default `balanced` autonomy: verify 1-syn presents proposed slicing in synthesis output and blocks for user confirmation
- [ ] 7.5 Run a synthetic `/start-feature` with `autopilot` override: verify 1-syn prints but does not block, 1a is skipped, and the gate payload includes a non-empty `assumptions` section
- [ ] 7.6 Run a synthetic `/start-feature` with `manual` override: verify 1-syn blocks, 1a runs free-form, and the orchestrator waits for explicit `proceed`

<!-- validation tasks — require manual test runs against real/test projects -->

## 8. Documentation and metadata

- [x] 8.1 Update `CLAUDE.md` "Generated feature-workflow" section to mention the autonomy lever and synthesis phase as part of v1 generation
- [x] 8.2 Update `skills/claudboard-workflow/references/feature-workflow.template/SKILL.md.template` cost-tracking table (if one exists in Phase 7b) to include the synthesis phase in cost estimation
- [x] 8.3 Add to the `claudboard-workflow` completion report a one-line summary like: "Clarification autonomy default set to `balanced` (override per-invocation or edit `clarify.defaultAutonomy` in `config.json`)"
- [x] 8.4 Bump plugin version per repo convention (next minor)
