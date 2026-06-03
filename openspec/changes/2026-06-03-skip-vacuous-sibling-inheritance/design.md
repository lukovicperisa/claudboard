## Context

The sibling-repo inheritance mechanism was introduced to let a workspace's
second, third, … repos copy shared Jira/ADO values from the first repo's
already-filled `feature-workflow/config.json`, rather than re-prompting per
repo. It assumes the first repo has been filled in by a real human — the
TODO escape ("type 's' to stub") was added as a *defer* mechanism, not as a
normal end state.

In practice the TODO escape is taken often, especially during the first
exploratory run of `claudboard-workflow` against a workspace. The first
sibling then becomes a noise generator for every subsequent repo: a
config.json full of `[TODO: …]` strings that the orchestrator dutifully
offers up as "inheritable". The user's only response is `n`, because `y`
would copy useless stubs into the new repo's config.

A second flavor of vacuousness: even when the sibling's value is not a
stub, it may exactly match the documented default that Phase 2c would
otherwise have inserted. The two custom-field IDs (`customfield_10001` for
Sprint, `customfield_12206` for Acceptance Criteria) are the canonical
examples — most repos in a Jira Cloud instance share them, so detect.sh
sees them in the sibling and emits them as "inheritable", but the
orchestrator was going to write those exact values anyway.

Both flavors share a property: **the resolved config.json is bit-identical
whether the user answers `y` or `n`.** That's the definition of vacuous —
the prompt's information content is zero.

## Goals / Non-Goals

**Goals:**
- A `claudboard-workflow` run against a workspace whose only sibling has
  an all-TODO config goes from Phase 2a directly to Phase 2c with no
  Phase 2b prompt and no narration about siblings.
- A run where the sibling's only non-TODO fields exactly match the
  documented defaults behaves identically (no Phase 2b prompt).
- A run where the sibling has at least one non-TODO non-default value
  behaves identically to today (Phase 2b offer fires with the inheritable
  set displayed).
- The "documented default" map lives next to the `INHERITABLE` array in
  `detect.sh` so future drift between detect.sh and the prompt-reference
  files surfaces as a one-line change in one place.

**Non-Goals:**
- Suppressing the offer when only *some* fields are vacuous but others
  carry information (mixed siblings still prompt — the displayed set will
  just be smaller).
- Auto-applying the inheritance silently (silent state changes are worse
  UX than no prompt; the user should explicitly opt in to any non-default
  inheritance).
- Changing the format of the `config_summary` block in the JSON output
  (consumers downstream of detect.sh see only the filter effect, not a
  new shape).
- Backporting the fix into already-generated `feature-workflow/` skills —
  the bug is in the *generator*, not in any produced artifact, so there
  is nothing to backport.
- Extending the filter logic to `repos` map fields (the workspace mode
  `repos: { ... }` block has its own resolution path that is not affected
  by this change).

## Decisions

### D1. Filter happens in `detect.sh`, not in `SKILL.md` Phase 2b

**Considered:**
- **(A) detect.sh filters TODO-stub and default-matching values out of
  `config_summary`, drops siblings that filter down to empty.** Result:
  the `siblings` array exposed to SKILL.md only contains siblings worth
  offering. SKILL.md's Phase 2b stays unchanged.
- **(B) detect.sh emits the raw summary; SKILL.md filters at offer time.**
  SKILL.md gains a "for each sibling, count non-TODO non-default fields;
  skip the offer if total is zero" routine.
- **(C) Both detect.sh and SKILL.md filter (belt-and-braces).**

**Decision: A.** detect.sh already parses every `config_summary` field one
at a time — adding two extra `[[ ... ]]` checks per field is mechanical.
SKILL.md prose currently has no "compare values to defaults" routine and
adding one would require either embedding the default map in the prompt
text or referencing the prompt-reference files (which themselves describe
the default in human prose, not in a machine-readable place). Single
source of truth in detect.sh is cleaner.

C is rejected because it doubles the maintenance surface (two places to
update when a new field or default is added) for no extra safety —
detect.sh's output is deterministic.

### D2. Default map is a static bash associative array in `detect.sh`

**Considered:**
- **(A) Hardcoded associative array near the `INHERITABLE` array** with a
  one-line comment pointing at the prompt-reference files as authority.
- **(B) Parse the defaults out of `tracker-config-prompts.md` and
  `repo-config-prompts.md` at runtime.**
- **(C) Move the defaults into a separate `defaults.json` consumed by both
  detect.sh and the orchestrator.**

**Decision: A.** Three values qualify for the default map today
(`jira.customFields.sprint = customfield_10001`,
`jira.customFields.acceptanceCriteria = customfield_12206`,
`github.linkingKeyword = Closes`). Two are Jira custom-field IDs that are
not strictly mandated by Atlassian but are the conventional defaults
documented in our prompt files. One (`Closes`) is the GitHub-issue
linking keyword. The set is small, stable, and lives in one shell file —
parsing markdown at runtime to extract these values would be more code,
more failure modes, and slower. B and C are out of scope for this change.

Defaults map (initial population):

```bash
declare -A DEFAULT_VALUE=(
  [jira.customFields.sprint]="customfield_10001"
  [jira.customFields.acceptanceCriteria]="customfield_12206"
  [github.linkingKeyword]="Closes"
)
```

When a new field gains a default, the entry is added to both the
relevant prompt-reference file and this map in the same change. The
adjacent comment in detect.sh makes the dual-update obvious.

### D3. TODO-stub filter is a regex match, not a literal string match

**Considered:**
- **(A) Regex `^\[TODO: .*\]$`** — matches every stub the orchestrator
  could write (the stub key is per-field, so the body of the brackets
  varies).
- **(B) Literal `[TODO:` prefix check.** Looser; would catch a value the
  user typed by hand that begins with `[TODO:` but lacks the closing
  bracket. Unlikely to matter in practice.

**Decision: A.** Anchored regex is the safest interpretation of
"matches the stub format". It also documents the stub format in
detect.sh, making the connection between the orchestrator's stub-escape
and this filter explicit. The cost of being strict (a malformed stub
slips through and triggers a vacuous offer) is bounded: the prompt fires
once, the user answers `n`, and the malformed stub gets noticed.

### D4. Filter sequence is "drop stubs first, then check against defaults"

A field whose value is `[TODO: JIRA_CLOUD_ID]` should be dropped because
it's a stub, regardless of whether `jira.cloudId` has a default
(it doesn't — see prompt reference). A field whose value is
`customfield_10001` should be dropped because it matches the default
for `jira.customFields.sprint`. Order: stub-check first (cheap, no map
lookup), then default-check (one associative-array probe per field).

### D5. SKILL.md Phase 2b gains an explicit "if empty, skip" line

Today's SKILL.md effectively skips the offer when `siblings` is empty
(there is no sibling to display), but the prose at line 78 ("If
`siblings` is non-empty, load `references/sibling-inheritance.md` for
the field allowlist and exact inheritance offer wording, then present
the offer.") is the only normative statement. Without an explicit "if
empty, proceed silently" sibling, a future SKILL.md edit could
accidentally introduce a "no siblings detected" narration that
re-creates the noise we just removed.

The added line in Phase 2b will be:

> If the post-filter `siblings` array is empty, proceed to Phase 2c
> without narrating the absence (the goal is silent skip, not a
> "no siblings" status line).

## Risks / Trade-offs

- **[Default-map drift]** The map in detect.sh and the prose in
  `tracker-config-prompts.md`/`repo-config-prompts.md` can diverge. A
  prompt file that updates a default without updating detect.sh would
  cause detect.sh to keep emitting the old default as "inheritable",
  re-creating vacuous offers. → **Mitigation:** the adjacent comment in
  detect.sh names both reference files; a periodic grep in CI
  (`grep -F 'customfield_' detect.sh tracker-config-prompts.md`) would
  catch drift but is not part of this change. Acceptable risk — the map
  is three entries and updates are rare.
- **[Stub regex over-matches]** A real value that happens to be a
  literal `[TODO: SOMETHING]` would be filtered out. Vanishingly unlikely
  given the surrounding tooling, but possible if a user reuses our stub
  format in an unrelated field. → **Mitigation:** none required — if it
  ever happens the user re-runs and notices the missing inheritable
  value in the offer.
- **[Silent skip hides legitimate inheritance gone wrong]** If a sibling
  config has been corrupted such that detect.sh's `jq` parse fails, the
  sibling is already skipped today (with a `warn` line). After this
  change, a sibling whose parse succeeds but whose fields are all
  stubbed-or-default is silently skipped with no warn. → **Mitigation:**
  acceptable — the silent skip is the *point*. A user who wants to know
  what siblings are in scope can run `detect.sh` directly and read the
  JSON; the orchestrator's job is to suppress noise.
- **[Missed regressions in the orchestrator]** If a future SKILL.md edit
  reorders Phase 2b or moves the sibling check, the new D5 normative
  line might end up in the wrong place. → **Mitigation:** the
  spec.md scenarios added in this change exercise both the
  all-TODO and all-default cases against the orchestrator output, not
  just detect.sh, so a SKILL.md regression that re-introduces the offer
  fails the spec.
