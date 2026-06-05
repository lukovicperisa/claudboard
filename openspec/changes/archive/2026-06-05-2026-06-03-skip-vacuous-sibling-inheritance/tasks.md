## 1. detect.sh — TODO-stub and default filters

- [x] 1.1 Add a `default_value()` case-statement helper immediately above
  the `INHERITABLE=( ... )` array, populated with the three initial entries
  from `design.md` Decision D2 plus a comment "Keep in sync with
  references/{tracker,repo}-config-prompts.md". *(Implementation note:
  bash 3.2 on macOS does not support `declare -A`, so the original
  associative-array plan was replaced with a `case` statement. Same
  semantics, broader compatibility — see `default_value()` near line 290
  of detect.sh.)*
- [x] 1.2 Inside the per-field summary-build loop, after the
  `[[ -z "$v" ]] && continue` line, add two filters in this order:
    - `[[ "$v" =~ ^\[TODO:\ .*\]$ ]] && continue` (drop stub values)
    - `dv=$(default_value "$f"); [[ -n "$dv" && "$v" == "$dv" ]] && continue`
      (drop values that match the documented default)
- [x] 1.3 After the per-field loop closes, add a guard that skips
  appending the sibling to `SIBLINGS` if `summary == "{}"`:
  `[[ "$summary" == "{}" ]] && continue`
- [x] 1.4 Ran `bash scripts/detect.sh /Users/LUP1BG/Documents/BoschProjects/meas`;
  `.siblings` is `[]` (the all-TODO `Bosch-sdlc-tool` sibling is correctly
  filtered out).
- [x] 1.5 Three-way scratch test with sibling configs (one real value
  + one all-stub + one all-defaults): only the real-value sibling survives
  filtering, with the summary trimmed to the one real field
  (`jira.cloudId`). Stub and defaults siblings filtered out.

## 2. SKILL.md — normative skip when siblings is empty

- [x] 2.1 Phase 2b updated with the explicit "if empty, proceed without
  narration" guidance preceding the existing load-and-offer instruction.
  Fallback paragraph also extended to apply the same filter when detect.sh
  is unavailable.
- [x] 2.2 Re-read surrounding Phase 2a/2c — no other sentence implies a
  "no siblings detected" status line.

## 3. sibling-inheritance.md — load-gate clarification

- [x] 3.1 Added a "Load gate" paragraph at the top of
  `references/sibling-inheritance.md` explaining the file must only be
  loaded when the post-filter `siblings` array is non-empty, and naming
  the three default values to keep the contract explicit.

## 4. Spec sync — feature-workflow-generation

- [x] 4.1 Delta spec authored at
  `openspec/changes/2026-06-03-skip-vacuous-sibling-inheritance/specs/feature-workflow-generation/spec.md`
  with the MODIFIED offer scenario and two ADDED suppression scenarios.
- [x] 4.2 Delta synced into `openspec/specs/feature-workflow-generation/spec.md`:
  preamble paragraph added under the Requirement; offer scenario tightened
  with the non-stub-non-default condition; two new suppression scenarios
  inserted immediately above "Sibling inheritance accepted".

## 5. Manual verification

- [ ] 5.1 Re-run `/claudboard-workflow` against
  `/Users/LUP1BG/Documents/BoschProjects/meas` to confirm Phase 2b does
  NOT print the "Found feature-workflow config in sibling repo(s)" block
  or ask y/n. *(Pending — best done in a fresh session so the workflow
  re-loads cleanly.)*
- [ ] 5.2 Confirm the resolved config still contains `customfield_10001`
  and `customfield_12206` for the two custom-field IDs (their values now
  come from the default path in `tracker-config-prompts.md`, not from
  sibling inheritance). *(Pending — verified together with 5.1.)*
