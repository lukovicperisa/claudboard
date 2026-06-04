## 1. Add Phase 2a-bis silent auto-fill

- [x] 1.1 Edit `skills/claudboard-workflow/SKILL.md` and insert a new "2a-bis. Silent auto-fill" section between Phase 2a (git remote) and Phase 2b (sibling inheritance)
- [x] 1.2 Document the single Atlassian MCP call (`mcp__atlassian__getAccessibleAtlassianResources`) and the population of `jira.cloudId` + `jira.urlBase` from its result; degradation rule on failure (silent `[TODO: …]` stub for both)
- [x] 1.3 Document the `jira.projectKey` heuristic: `uppercase(basename($PROJECT_PATH))` IF it matches `^[A-Z]+$` (after uppercasing) else `[TODO: JIRA_PROJECT_KEY]`. For workspace mode: always `[TODO: JIRA_PROJECT_KEY]` (per D7's workspace clarification)
- [x] 1.4 Document the documented-default writes for every remaining field per D2: `jira.customFields.sprint = customfield_10001`, `jira.customFields.acceptanceCriteria = customfield_12206`, `jira.transitions = {start: "In Progress", success: "In Review", failure: "Blocked"}`, `jira.labels.area = {backend: "BE", frontend: "FE", devops: "DevOps", docs: "Docs"}`, `azureDevOps.repositoryId = [TODO: ADO_REPO_ID]`, `github.linkingKeyword = "Closes"`, `git.branchTypes = ["feature","bugfix","hotfix"]`, `git.branchPattern = "{type}/{ticket}/{slug}"` if any tracker active else `"{type}/{slug}"`, `git.ticketRegex = "[A-Z]+-[0-9]+"`
- [x] 1.5 Add a one-line summary print after Phase 2a-bis completes: `Auto-filled N fields (M stubbed for manual editing)` — do not list each field inline; the completion report covers the stub list

## 2. Delete Phase 2c

- [x] 2.1 Remove the entire "### 2c. Prompt for remaining fields" section from `skills/claudboard-workflow/SKILL.md` (currently lines ~213-244)
- [x] 2.2 Remove the reference-load gates: `Load references/tracker-config-prompts.md only when …` and `Load references/repo-config-prompts.md only when …`
- [x] 2.3 Remove the "Shared git fields (always prompted)" table — the values are now written silently in Phase 2a-bis
- [x] 2.4 Update the SKILL.md "Reference load gates" summary table near the bottom of the file to mark the two prompt files as `documentation only — never loaded at runtime`

## 3. Add invocation-hint pre-resolution to Phase 1d

- [x] 3.1 Edit `skills/claudboard-workflow/SKILL.md` Phase 1d (currently lines ~112-165): insert a new sub-step before the `If mcp.ambiguities is non-empty` block titled "Invocation-hint pre-resolution"
- [x] 3.2 Document the case-insensitive whole-word match against the four token tables (per D4)
- [x] 3.3 Document the suppression behaviour: matched hint → set the chosen flag true, the other false, record `"chosen via invocation hint"` in `sources`, REMOVE the corresponding entry from `mcp.ambiguities` so the conflict prompt does not fire
- [x] 3.4 Document the both-tokens-matched conflict case (silently ignore both hints for that dimension; let the conflict prompt fire)
- [x] 3.5 Document the no-MCP-for-hint case (hint silently ignored)
- [x] 3.6 Wire the orchestrator to read the invocation text — clarify that "invocation text" means the full message that triggered the skill, not just args after `/claudboard-workflow`

## 4. Add stub-list to completion report

- [x] 4.1 Edit `skills/claudboard-workflow/SKILL.md` Phase 7 (completion report): add a new "## Unfilled config values" subsection that lists every `[TODO: …]` in the resolved `config.json`, one per line with `<json_path> [TODO: …]`
- [x] 4.2 Add the exact `config.json` filesystem path under each stub for copy-paste navigation
- [x] 4.3 Omit the entire subsection when zero stubs were written (silence = success)

## 5. Reclassify the prompt files as documentation

- [x] 5.1 Edit `skills/claudboard-workflow/references/tracker-config-prompts.md`: add a documentation-only header per D6 at the top of the file
- [x] 5.2 Edit `skills/claudboard-workflow/references/repo-config-prompts.md`: same treatment
- [x] 5.3 Do NOT remove any field documentation — the body content stays valuable for users editing `config.json` by hand
- [x] 5.4 Add a forward-reference at the top of each file pointing to the completion-report stub list as the canonical post-run discovery channel

## 6. Spec deltas

- [x] 6.1 Write `openspec/changes/claudboard-workflow-non-interactive/specs/feature-workflow-generation/spec.md` with the MODIFIED scenarios for `config.json input flow` and the new ADDED scenarios for silent auto-fill and silent stubbing
- [x] 6.2 Write `openspec/changes/claudboard-workflow-non-interactive/specs/mcp-detection/spec.md` with the MODIFIED scenario for "Precedence-prompt when two MCPs in a dimension are detected" (gain pre-resolution step) plus an ADDED requirement "Invocation-hint pre-resolution"
- [x] 6.3 Run `openspec validate claudboard-workflow-non-interactive --strict` and resolve any failures

## 7. Verification

- [x] 7.1 Smoke test: invoke `/claudboard-workflow` on a single repo with both tracker MCPs configured and NO hint in the invocation — confirm exactly one prompt (Phase 1d tracker conflict) appears
- [x] 7.2 Smoke test: invoke `/claudboard-workflow use jira` on the same setup — confirm zero prompts; confirm `config.json` has `jira.*` populated and `tr` block absent; confirm completion report says "chosen via invocation hint" in the MCP detection table
- [x] 7.3 Smoke test: invoke `/claudboard-workflow` on a repo whose name is not `^[A-Z]+$` (e.g. `my-cool-service`) — confirm `jira.projectKey` is stubbed `[TODO: JIRA_PROJECT_KEY]` and the completion report lists it under "Unfilled config values"
- [x] 7.4 Smoke test: invoke `/claudboard-workflow` with the Atlassian MCP disconnected (kill the MCP process or revoke OAuth) — confirm `jira.cloudId` and `jira.urlBase` are stubbed silently and the completion report lists both
- [x] 7.5 Smoke test: invoke `/claudboard-workflow` in workspace mode on a workspace with multiple sibling configs — confirm Phase 2b inheritance offer still fires when at least one sibling has non-default explicit values (per R4 ordering decision)
- [x] 7.6 Re-read every modified `SKILL.md` section end-to-end and confirm no stale references to the deleted Phase 2c, the deleted prompt-load gates, or the deleted "Shared git fields (always prompted)" table

## 8. Documentation

- [x] 8.1 Update `CLAUDE.md` (root) "Key Design Decisions" section: extend the existing "Non-interactive by default" bullet to cover `/claudboard-workflow` as well, with the one-line "happy path = zero prompts; conflicting MCPs without a hint = one prompt"
- [x] 8.2 Update the dispatcher `skills/claudboard/SKILL.md` "Where to run /analyse" guidance to add a parallel "Hinting tracker/repo backend" subsection documenting the invocation-hint tokens for users
- [x] 8.3 Update plugin version in `plugin.json` to `4.0.0-beta.10`
