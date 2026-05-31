## Tasks

### Bucket A — claudboard-generate

- [ ] Rename Phase 2 in `skills/claudboard-generate/SKILL.md` from `Confirmation` to `Pre-write summary` (or equivalent)
- [ ] Remove the `Generate these artifacts? [y/n]` line and the `If n: which parts should I skip or change?` line
- [ ] Remove the `**Pause here.** Wait for user confirmation before proceeding.` statement
- [ ] Append the standard hint after the summary block: `I'll proceed now — interrupt with Esc to abort or adjust.`
- [ ] Verify Phase 3 error handling still pauses on `ASK USER markers` (line 225 of original — `Report contains unresolved ambiguities or "ASK USER" markers`)
- [ ] Verify the stale-report warning in Phase 1b still pauses (line 55 of original)

### Bucket B — claudboard-refresh

- [ ] Rename Phase 4 in `skills/claudboard-refresh/SKILL.md` from `Confirmation` (or current title) to `Pre-write summary`
- [ ] Remove the `Apply these updates? [y/n/selective]` line and the `If selective: which parts should I apply?` line
- [ ] Remove the `**Pause here.** Wait for user confirmation.` statement
- [ ] Rename Phase 5 from `Selective Generation` to `Generation` (the `Selective` framing assumed a `selective` branch that no longer exists)
- [ ] Update all internal references that say "selective" or "confirmed updates" to reflect that all proposed updates are applied unconditionally
- [ ] Append the standard hint after the summary block: `I'll proceed now — interrupt with Esc to abort or adjust.`
- [ ] Verify the feature-workflow skill exclusion logic (Phase 5 "Exclusion: feature-workflow skill") is preserved verbatim

### Bucket C — claudboard-workflow

- [ ] Rename Phase 5 in `skills/claudboard-workflow/SKILL.md` from `Confirmation Gate` to `Pre-write summary`
- [ ] Remove the `Proceed? [y/n/edit]` line
- [ ] Remove the `**On `n`:** ...` and `**On `edit`:** ...` and `**On `y`:** Proceed to Phase 6.` branch handlers
- [ ] Append the standard hint after the summary block: `I'll proceed now — interrupt with Esc to abort or adjust.`
- [ ] Verify the mutex-error halt described in `feature-workflow-generation` spec (Requirement: Mutually-exclusive repo agents, line 270-272) is unaffected — it's a separate halt at a different decision point, not the proceed gate
- [ ] Verify the per-repo `feature-workflow` skill listing (workspace mode, lines 296-298) still appears in the summary so users can see it before files write

### Bucket D — Spec delta (`feature-workflow-generation`)

- [ ] Replace the `Requirement: User-facing confirmation gate` requirement (line 274 of `openspec/specs/feature-workflow-generation/spec.md`) with `Requirement: Informational pre-write summary`
- [ ] Replace the `Scenario: User confirms` scenario with `Scenario: Summary printed, write proceeds without pause`
- [ ] Remove the `Scenario: User declines` scenario (the y/n decline branch no longer exists)
- [ ] Remove the `Scenario: User edits a field` scenario (the `edit` branch no longer exists; users redirect via interrupt)
- [ ] Add a `Scenario: User interrupts after seeing the summary` scenario covering the new interrupt-and-converse model
- [ ] Add a `Scenario: Pause-on-real-decision is unaffected` scenario as a guardrail
- [ ] Verify `Requirement: Mutually-exclusive repo agents` (line 270-272) is unchanged
- [ ] Verify `Requirement: Completion report` (line 289) is unchanged
- [ ] Verify `Requirement: Refresh exclusion` (line 304) is unchanged

### Bucket E — Verification

- [ ] Manually invoke `/generate` against a real project (e.g., a fresh clone of GardenMind); confirm no y/n pause, summary printed, files written
- [ ] Manually invoke `/refresh` against a project with existing `.claude/` (e.g., claudboard itself); confirm no y/n pause, summary printed, files written
- [ ] Manually invoke `/claudboard-workflow` against a project ready for it (e.g., GardenMind after `/generate`); confirm no y/n pause, summary printed, files written
- [ ] Trigger an `ASK USER` marker case in `/generate` by manually adding an `ASK USER:` marker to a test report; confirm pause still fires
- [ ] Trigger the mutex error in `/claudboard-workflow` by manually setting both `REPO_ADO` and `REPO_GITHUB` to true in a test report; confirm error halt still fires
- [ ] Run `openspec validate remove-redundant-confirmation-gates` and confirm clean

### Bucket F — Documentation

- [ ] If `CLAUDE.md` or `README.md` references the y/n confirmation pattern, update those references
- [ ] No changes to `skills/claudboard/SKILL.md` (dispatcher) needed unless it explicitly documents the gate (verify before closing the change)
