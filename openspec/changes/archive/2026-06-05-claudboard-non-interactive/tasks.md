## 1. Remove right-level check (Phase 1a Step 0)

- [x] 1.1 Delete the "Step 0: Right-level check" subsection from `skills/claudboard-analyse/SKILL.md` (lines ~62-86), including the prompt text, sibling detection logic, and the YES/NO branches
- [x] 1.2 Renumber the remaining Phase 1a steps: current "Step 1" becomes the new opening step; remove any cross-references to the deleted "Step 0"
- [x] 1.3 Grep the entire repo for references to the removed step (`grep -r "Right-level check\|right-level\|step-up prompt\|step up" skills/ openspec/specs/`) and delete or rewrite each one
- [x] 1.4 Update `openspec/specs/right-level-check/spec.md` per the spec delta (REMOVED Requirements applied at archive time — verify the delta file is correct)

## 2. Make topology presentation non-blocking (Phase 1a Step 3)

- [x] 2.1 Edit `skills/claudboard-analyse/SKILL.md` Phase 1a Step 3 (lines ~124-142): replace "Wait for user to confirm or correct misclassifications before proceeding" with "Print the detected topology and proceed immediately"
- [x] 2.2 Append the recovery hint line after the topology output template: "If a service is misclassified, edit `.claudboard/catalog.json` after the run completes, or re-run `/analyse` from a different level."
- [x] 2.3 Remove the "Wait for user to confirm" sentence
- [x] 2.4 Verify no other place in `skills/claudboard-analyse/SKILL.md` re-introduces a topology confirmation step

## 3. Make graph presentation non-blocking (Phase 1i Step 4)

- [x] 3.1 Edit `skills/claudboard-analyse/SKILL.md` Phase 1i Step 4 (line ~407): replace "Display edges, coupling classifications, and warnings. Wait for user confirmation (or corrections). If user edits, re-present adjusted graph." with "Print edges, coupling classifications, and warnings. Proceed immediately to write `ecosystem.md`."
- [x] 3.2 Append the recovery hint line after the graph print: "If an edge is missing or wrong, edit `.claudboard/catalog.json` or `.claude/memories/ecosystem.md` after the run completes."
- [x] 3.3 Verify the change does not affect Phase 1i Step 5 (write ecosystem.md) — that step should now run unconditionally after Step 4

## 4. Tighten Phase 2 ambiguity trigger

- [x] 4.1 Edit `skills/claudboard-analyse/SKILL.md` Phase 2 (line ~513-518): replace the open-ended "If patterns are ambiguous or inconsistent, ask the user now" with a strict trigger: "Ask the user ONLY when a convention is split at 40-60% per variant AND the dimension is one of: DI style, error-handling strategy, logging framework, test framework. Routine per-module variation MUST be recorded as 'predominant: X, also seen: Y, Z' in the catalog without a prompt."
- [x] 4.2 Add explicit examples of what does NOT trigger a prompt (naming variations across modules, formatting choices, library versions)

## 5. Ship recommended-permissions bundle

- [x] 5.1 Create `skills/claudboard/references/recommended-permissions.json` with the v1 permission list from design.md D4 and the marker `_claudboard_permissions_version: "1"`
- [x] 5.2 Validate the JSON parses and matches the schema expected by `.claude/settings.json` (the `permissions.allow` field accepts string patterns)
- [x] 5.3 Test the merge logic manually: take a sample `.claude/settings.json` with existing user entries, simulate the merge, confirm dedupe works and existing entries are preserved

## 6. Add dispatcher auto-merge offer

- [x] 6.1 Edit `skills/claudboard/SKILL.md` (dispatcher): add a "Phase 0: First-run permission setup" section that runs before any sub-skill dispatch
- [x] 6.2 Implement the marker check: read `.claude/settings.json`, look for `_claudboard_permissions_version`, branch on present/absent
- [x] 6.3 Implement the one-shot prompt: "Add claudboard's recommended permissions to .claude/settings.json? This eliminates ~20 prompts per analysis run. [y/n]"
- [x] 6.4 Implement the YES branch: load `recommended-permissions.json`, merge into `permissions.allow` (dedupe), stamp marker as "1", print confirmation
- [x] 6.5 Implement the NO branch: stamp marker as "1-declined", print the copy-paste fallback (the bundle JSON contents), proceed
- [x] 6.6 Verify the dispatcher MUST NOT modify any key other than `permissions.allow` and the marker

## 7. Add "Where to run /analyse" guidance

- [x] 7.1 Edit `skills/claudboard/SKILL.md` (dispatcher): add a "Where to run /analyse" section near the top, before the sub-skill routing table
- [x] 7.2 Cover all three modes (single repo / monorepo / workspace) with the exact wording from design.md D5, including the explicit warning against generic dev folders (`~/Projects`, `~/code`)
- [x] 7.3 Include the one-line recovery instruction: "If you run from the wrong level, re-run from the right one. The catalog regenerates in seconds."

## 8. Cleanup and verification

- [x] 8.1 Grep for stale references to removed prompts: `grep -rn "Analyse at ecosystem level\|step-up prompt\|wait for confirmation\|Proceed with ecosystem injection" skills/ openspec/`
- [x] 8.2 Update `skills/claudboard-analyse/SKILL.md` "Constraints" section if it references interactive prompts that are now gone
- [x] 8.3 Update any reference files under `skills/claudboard/references/` that document the old flow (check `stack-detectors.md` for the "Right-Level Check" section and remove/rewrite it)
- [x] 8.4 Run `openspec validate claudboard-non-interactive --strict` and resolve any failures
- [ ] 8.5 Smoke test: invoke `/claudboard:claudboard-analyse` on a fresh test repo with no pre-existing permissions and confirm exactly one prompt (the auto-merge offer) appears in the happy path
- [ ] 8.6 Smoke test: invoke `/claudboard:claudboard-analyse` on `craftsphere.cloud` (which previously triggered Step 0 due to BoschProjects siblings) and confirm zero level-related prompts
- [ ] 8.7 Smoke test: re-invoke after first run completed and confirm no permission prompt re-appears (marker is honored)

## 9. Documentation

- [x] 9.1 Update `CLAUDE.md` (root) "Key Design Decisions" to add: "Non-interactive by default — `/analyse` runs end-to-end with no mid-flow prompts. Wrong-level invocations recover by re-running."
- [x] 9.2 Add a one-paragraph "Permissions" section to `CLAUDE.md` or the dispatcher SKILL.md describing the auto-merge bundle and how to refresh it (manual: delete the marker key and re-run)
