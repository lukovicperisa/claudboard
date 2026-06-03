## Why

`claudboard-workflow` pauses the orchestrator in Phase 2b to ask
`Inherit shared config from <sibling>? [y/n]` whenever any sibling repo under
the workspace parent contains a `feature-workflow/config.json` — even when the
sibling's config is itself unfilled (every inheritable field is a
`[TODO: …]` stub left behind by a previous workflow run), or when the only
non-stub values exactly match the documented defaults the orchestrator would
otherwise use. Both cases produce a prompt with zero net effect: y and n
produce identical resolved configs.

This was observed live in the `meas` workspace on 2026-06-03: the only
sibling (`../Bosch-sdlc-tool/`) had `cloudId`, `projectKey`, `urlBase`,
`github.owner`, and `github.repo` all stubbed as `[TODO: …]`, and its two
non-stub fields (`customfield_10001`, `customfield_12206`) were the exact
default values for `jira.customFields.sprint` and
`jira.customFields.acceptanceCriteria`. The y/n was unavoidable busywork.

The existing spec wording at
`feature-workflow-generation/spec.md:196-198` ("WHEN at least one sibling
directory … THEN the system SHALL display the inheritable shared values …
and ask …") is too permissive — it does not filter by usefulness, so the
orchestrator obeys it correctly and the user gets a vacuous prompt.

## What Changes

- **MODIFIED** `skills/claudboard-workflow/scripts/detect.sh` — when building
  each sibling's `config_summary`, skip values that match `^\[TODO: .*\]$`
  (treat them as unset). After the per-field loop, also drop any sibling
  whose remaining `config_summary` contains only fields whose values match
  the documented default for that field (see `Decisions D2` for the default
  map). Siblings filtered down to an empty summary SHALL NOT appear in the
  emitted `siblings` array.
- **MODIFIED** `skills/claudboard-workflow/SKILL.md` Phase 2b — keep the
  existing offer wording, but precede it with an explicit guard:
  "If the resolved `siblings` array is empty, skip the offer entirely and
  proceed to Phase 2c with no narration." (Today the SKILL.md implicitly
  skips when the array is empty; this makes it normative so a future
  detect.sh regression cannot reintroduce the prompt.)
- **MODIFIED** `skills/claudboard-workflow/references/sibling-inheritance.md` —
  add a leading "Load gate" line clarifying that the file is only loaded
  when the post-filter `siblings` array is non-empty (matches the existing
  load-gate convention in `SKILL.md` Phase 2c).
- **MODIFIED** `openspec/specs/feature-workflow-generation/spec.md`
  Requirement "config.json input flow" — replace the
  "Sibling-repo inheritance offer" scenario with a stricter one that
  requires "at least one value the user would actually inherit (non-stub
  and different from the documented default)" before the offer fires; add
  two new scenarios for the all-stub and all-defaults cases that assert
  the offer is suppressed.

Out of scope:

- The behaviour of `/start-feature` after a sibling has been chosen (no
  change to that path).
- The shape of the `config_summary` block beyond the filter (display
  formatting, ordering, missing-keys handling all unchanged).
- The standalone `sibling-inheritance.md` text past the new load-gate line.
- Backporting to already-generated `feature-workflow/` skills — they remain
  on their as-built behaviour; the fix is in the generator only.

## Capabilities

### Modified Capabilities

- `feature-workflow-generation` — narrows the "sibling-repo inheritance
  offer" trigger and adds two suppression scenarios. No new capability.

## Impact

- **Affected files (modified):**
  - `skills/claudboard-workflow/scripts/detect.sh` (sibling-summary filter
    + post-filter sibling drop)
  - `skills/claudboard-workflow/SKILL.md` (Phase 2b normative skip)
  - `skills/claudboard-workflow/references/sibling-inheritance.md`
    (load-gate clarification)
- **Affected files (unchanged):**
  - `references/tracker-config-prompts.md`,
    `references/repo-config-prompts.md` (the prompts these drive are
    unchanged; the sibling offer is upstream of them)
  - `references/feature-workflow.template/**` (generator output unchanged)
- **User-visible effect:** runs against workspaces whose siblings have only
  stubbed or default-matching configs go straight from Phase 2a to Phase 2c
  with one fewer prompt. Runs against siblings that DO have at least one
  inheritable non-stub non-default value behave identically to today.
- **Cost of the change at runtime:** $0 additional API tokens — the filter
  is pure shell in `detect.sh`.
- **Risks:**
  - *Default-map drift*: the static "documented default" map in detect.sh
    must stay in sync with `tracker-config-prompts.md` and
    `repo-config-prompts.md`. Mitigation: keep the map adjacent to the
    `INHERITABLE` array in `detect.sh` and add a one-line comment pointing
    at the two prompt-reference files.
  - *Sibling with one real value, four stubs*: still triggers the offer
    today (correct). Filter keeps the one real value, drops the four
    stubs from the summary, the offer fires with the one value displayed.
    No regression.
