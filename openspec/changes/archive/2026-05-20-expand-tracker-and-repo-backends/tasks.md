## 1. Capability-flag renaming and catalog updates

- [x] 1.1 Rename `JIRA_AVAILABLE` → `TRACKER_JIRA` in `skills/claudboard-workflow/references/block-catalog.md` (entry, scenarios, flag-summary table)
- [x] 1.2 Rename `ADO_AVAILABLE` → `REPO_ADO` in `skills/claudboard-workflow/references/block-catalog.md`
- [x] 1.3 Add `TRACKER_TR` entry to `block-catalog.md` (resolution rule, source, capability blocks that reference it, when-false behaviour)
- [x] 1.4 Add `REPO_GITHUB` entry to `block-catalog.md` (resolution rule, source, capability blocks that reference it, when-false behaviour)
- [x] 1.5 Update the flag-summary table at bottom of `block-catalog.md` with the four new flag names and a note that tracker/repo dimensions are mutually exclusive
- [x] 1.6 Replace every `<!-- IF JIRA_AVAILABLE -->` → `<!-- IF TRACKER_JIRA -->` in the entire `skills/claudboard-workflow/references/feature-workflow.template/` tree (orchestrator SKILL.md.template, all agent templates, config.json.template)
- [x] 1.7 Replace every `<!-- IF ADO_AVAILABLE -->` → `<!-- IF REPO_ADO -->` in the entire `feature-workflow.template/` tree

## 2. MCP detection logic (orchestrator Phase 1d)

- [x] 2.1 Confirm the canonical "official" GitHub MCP server name(s) (open question from design.md) and pin in `mcp-detection/spec.md` and `block-catalog.md`
- [x] 2.2 Extend Phase 1d detection in `skills/claudboard-workflow/SKILL.md` to scan for 4 MCPs (Atlassian, Bosch T&R, ADO, GitHub) per the keyword rules in `mcp-detection` spec
- [x] 2.3 Implement project-vs-user precedence (project-level `.mcp.json` wins) in Phase 1d detection
- [x] 2.4 Implement mutually-exclusive resolution per dimension: when two tracker MCPs detected, prompt the user; when two repo MCPs detected, prompt the user
- [x] 2.5 Add halt-on-conflict logic: if both flags in a dimension end up true after prompts, refuse to write files and surface a "precedence resolution error"
- [x] 2.6 Add dimension-stub warnings: when no tracker MCP detected emit the "No tracker MCP detected …" warning; when no repo MCP detected emit the "No repo MCP detected …" warning
- [x] 2.7 Add "MCP detection" section to the completion report listing each backend's detection result and source config path

## 3. T&R agent (`tr-agent.md`)

- [x] 3.1 Create `skills/claudboard-workflow/references/feature-workflow.template/agents/tr-agent.md` as a verbatim file (no `.template` suffix), structured to mirror the action contract in `jira-agent.md` (Configuration, Action: `fetchAndPrepare`, Action: `updateDescription`, Action: `addLabels`, Action: `addComment`, Action: `transition`)
- [x] 3.2 Implement `Action: create` block that returns the structured error `"Action create unavailable on TRACKER_TR — Path A (existing ticket key) is the only supported entry point"` and halts
- [x] 3.3 Implement `Action: fetchAndPrepare` against `mcp__bosch-jira-mcp__jira_get_issue` + `jira_transition` (no-args + with-target modes) + `jira_get_myself` + `jira_update_issue` for assignee; skip sprint assignment and note `sprintAssigned: false, reason: "TRACKER_TR — no custom field write support"` in result
- [x] 3.4 Implement `Action: updateDescription` against `mcp__bosch-jira-mcp__jira_update_issue` with `description` field
- [x] 3.5 Implement `Action: addLabels` via read-modify-write: `jira_get_issue` → union with `labelsToAdd` (deduplicated) → `jira_update_issue` with merged labels; return `{preLabels, added, postLabels}`
- [x] 3.6 Implement `Action: addComment` against `mcp__bosch-jira-mcp__jira_add_comment`
- [x] 3.7 Implement `Action: addWorklog` block that returns the structured error `"Action addWorklog unavailable on TRACKER_TR — time is folded into Phase 7 final summary comment"` (orchestrator should not call this action under T&R, but the safeguard prevents silent improvisation)
- [x] 3.8 Implement `Action: transition` against `mcp__bosch-jira-mcp__jira_transition` using `targetStatus` resolution mode
- [x] 3.9 Document at top of `tr-agent.md` the assumed MCP server name (`bosch-jira-mcp`), expected tool prefix (`mcp__bosch-jira-mcp__*`), and authentication note (bearer token in `~/.config/bosch-jira-mcp/config.json`, handled by MCP)
- [x] 3.10 Add result-block schemas matching `jira-agent.md` conventions so the orchestrator can parse uniformly

## 4. GitHub PR agent (`pr-agent-github.md`)

- [x] 4.1 Rename existing `skills/claudboard-workflow/references/feature-workflow.template/agents/pr-agent.md.template` to `pr-agent-ado.md` (verbatim, no `.template` suffix)
- [x] 4.2 Remove the `gh` CLI fallback block from `pr-agent-ado.md` (GitHub is now first-class via its own file)
- [x] 4.3 Create `skills/claudboard-workflow/references/feature-workflow.template/agents/pr-agent-github.md` as a verbatim file implementing the repo-backend action contract (`createPullRequest`, `linkTicket`, `verifyPipelineRun`, `getPullRequestStatus`)
- [x] 4.4 Implement `Action: createPullRequest` via the official GitHub MCP's PR-creation tool; append `<linkingKeyword> #<N>` to PR description when ticket reference is numeric and `github.linkingKeyword` is configured (default keyword: `Closes`)
- [x] 4.5 Implement `Action: linkTicket` by editing the existing PR's description body to include the linking-keyword line; do NOT mutate any other GitHub fields
- [x] 4.6 Implement `Action: verifyPipelineRun` by listing GitHub Actions workflow runs for the PR branch and returning the latest run's status
- [x] 4.7 Implement `Action: getPullRequestStatus` via the GitHub MCP's PR-get tool
- [x] 4.8 Document at top of `pr-agent-github.md` the assumed GitHub MCP server name (pinned in task 2.1) and the canonical tool prefix

## 5. git-agent updates

- [x] 5.1 In `skills/claudboard-workflow/references/feature-workflow.template/agents/git-agent.md.template`, wrap the existing ADO branch-policy guidance in `<!-- IF REPO_ADO -->...<!-- ENDIF -->`
- [x] 5.2 Add a parallel `<!-- IF REPO_GITHUB -->...<!-- ENDIF -->` block with guidance for GitHub Branch Protection Rules / Rulesets (advisory: document in PR description any rule-protected branches encountered; do not mutate rules)
- [x] 5.3 Verify the rest of `git-agent.md.template` remains backend-agnostic

## 6. Shared agent updates (architect, implementation, spec-reviewer)

- [x] 6.1 In `architect-agent.md.template`, generalize the `IF TRACKER_JIRA` AC-handling block: when generating the ticket description on T&R, inline the `## Acceptance Criteria` heading into the description body rather than writing to a separate field
- [x] 6.2 Add an `IF TRACKER_TR` companion block in `architect-agent.md.template` that documents the description-body AC convention
- [x] 6.3 In `implementation-agent.md.template`, generalize the ticket cross-reference in commit-message instructions: change the wrapping from `IF JIRA_AVAILABLE` to `IF TRACKER_JIRA OR TRACKER_TR` (use an OR-block convention — confirm the template engine supports it or otherwise duplicate the block under each flag)
- [x] 6.4 In `spec-reviewer.md.template`, generalize the AC-completeness check: under `IF TRACKER_JIRA` check against the AC custom field, under `IF TRACKER_TR` check against the AC section in the description body

## 7. Orchestrator `SKILL.md.template` updates

- [x] 7.1 Add `IF TRACKER_TR` paired blocks for every existing `IF TRACKER_JIRA` block in `SKILL.md.template` (Phase 1-pre, Phase 1a updateDescription, Phase 1d worklog, error handler transitions, Phase 7 finalize, capability summary table)
- [x] 7.2 Add `IF REPO_GITHUB` paired blocks for every existing `IF REPO_ADO` block (Phase 6 PR creation, capability summary table)
- [x] 7.3 In Phase 1-pre Path B (auto-create), wrap the entire branch in `IF TRACKER_JIRA` since T&R has no create action; add a parallel `IF TRACKER_TR` Path B that prints "Auto-create ticket unavailable on T&R — please provide an existing ticket key with `/start-feature TR-XXXXX`" and halts
- [x] 7.4 In Phase 1d, wrap the worklog call in `IF TRACKER_JIRA` (T&R skips this); under `IF TRACKER_TR`, hold the refinement-elapsed time in a variable for inclusion in Phase 7's final comment
- [x] 7.5 In Phase 7a, wrap the worklog call in `IF TRACKER_JIRA`; under `IF TRACKER_TR`, fold both refinement and implementation time data into the Phase 7b comment body
- [x] 7.6 In Phase 7b, ensure the comment composition includes time data when the active tracker is T&R (the only place time is recorded under TRACKER_TR)
- [x] 7.7 Update the agent-orchestration ASCII diagram at the top of `SKILL.md.template` to show both tracker paths and both repo paths via paired `IF` annotations

## 8. config.json schema updates

- [x] 8.1 In `config.json.template`, add top-level `"tracker": "jira"` discriminator under `IF TRACKER_JIRA` and `"tracker": "tr"` under `IF TRACKER_TR`
- [x] 8.2 Wrap the existing `"jira": { ... }` block in `IF TRACKER_JIRA`
- [x] 8.3 Add a parallel `"tr": { baseUrl, projectKey, transitions }` block under `IF TRACKER_TR` (no `customFields`, no `cloudId` — see tracker-backends spec)
- [x] 8.4 Add top-level `"repo": "ado"` under `IF REPO_ADO` and `"repo": "github"` under `IF REPO_GITHUB`
- [x] 8.5 Wrap the existing `"azureDevOps": { ... }` block in `IF REPO_ADO`
- [x] 8.6 Add a parallel `"github": { owner, repo, linkingKeyword }` block under `IF REPO_GITHUB` with `linkingKeyword` defaulting to `"Closes"`

## 9. Substitution variables

- [x] 9.1 Add `TR_BASE_URL`, `TR_PROJECT_KEY` to `references/substitution-catalog.md` (source: user prompt during config gathering; example values)
- [x] 9.2 Add `GITHUB_OWNER`, `GITHUB_REPO`, `GITHUB_LINKING_KEYWORD` to `references/substitution-catalog.md` (source: auto-extracted from git remote; `GITHUB_LINKING_KEYWORD` defaults to `"Closes"`)
- [x] 9.3 Update `REPOS_MAP_JSON` documentation to describe both ADO (`repositoryId`) and GitHub (`owner`/`repo`) shapes depending on active repo backend

## 10. Config-prompts reference split

- [x] 10.1 Create `skills/claudboard-workflow/references/tracker-config-prompts.md` with two sections: "Jira (TRACKER_JIRA)" with the existing prompts copied verbatim, and "Bosch Track & Release (TRACKER_TR)" with prompts for `tr.baseUrl`, `tr.projectKey`, `tr.transitions.{start,success,failure,pause}`
- [x] 10.2 Create `skills/claudboard-workflow/references/repo-config-prompts.md` with two sections: "Azure DevOps (REPO_ADO)" with the existing prompts copied verbatim, and "GitHub (REPO_GITHUB)" with prompts for `github.owner`, `github.repo`, `github.linkingKeyword` (default: Closes)
- [x] 10.3 Delete the old `references/jira-config-prompts.md` once tracker- and repo-config-prompts.md exist and all references to it are updated
- [x] 10.4 Update references to `jira-config-prompts.md` in `skills/claudboard-workflow/SKILL.md` to point to the two new split files

## 11. Auto-detection extensions

- [x] 11.1 Extend the git-remote auto-detection in Phase 2 of `claudboard-workflow/SKILL.md` to match GitHub URL patterns (`github.com:{owner}/{repo}` and `https://github.com/{owner}/{repo}`) and extract `github.owner` + `github.repo`
- [x] 11.2 Add T&R config-gathering prompts (no auto-detection — T&R baseUrl and projectKey come from user)

## 12. Completion report extensions

- [x] 12.1 Update the completion report template in `claudboard-workflow/SKILL.md` to list which tracker and which repo backend were resolved, including any precedence prompts asked
- [x] 12.2 Add a "T&R v1 limitations" section to the completion report that appears only when `TRACKER_TR` is the active backend, enumerating the five accepted gaps from `tracker-backends/spec.md`
- [x] 12.3 Add a "Migrated from legacy flag names" note when the regenerator detects an older generated tree had existed prior, listing the old-to-new flag mapping

## 13. Documentation and CLAUDE.md updates

- [x] 13.1 Update the project root `CLAUDE.md` "Skill Anatomy" tree to reflect the new agent files (`tr-agent.md`, `pr-agent-github.md`, renamed `pr-agent-ado.md`) and the split prompt-reference files
- [x] 13.2 Add a "Backend support" section to `claudboard-workflow/SKILL.md` (visible to the agent at runtime) summarizing the 4 supported backends and the mutual-exclusion rule per dimension

## 14. Verification and regression checks

- [ ] 14.1 Test generation on a project with Atlassian + ADO MCPs (the existing baseline): verify the output is functionally equivalent to today (same files, same agent contents modulo the renamed flag-block fences), with new top-level `tracker: "jira"`, `repo: "ado"` discriminators in config.json
- [ ] 14.2 Test generation on a project with Bosch T&R + ADO MCPs: verify `tr-agent.md` is written, `jira-agent.md` is NOT written, `pr-agent-ado.md` is written, and the SKILL.md orchestrator drops Phase 1d worklog and Phase 7a worklog
- [ ] 14.3 Test generation on a project with Atlassian + GitHub MCPs: verify `jira-agent.md` is written, `pr-agent-github.md` is written, `pr-agent-ado.md` is NOT written, and config.json contains `github.owner/repo` auto-detected from the git remote
- [ ] 14.4 Test generation on a project with Bosch T&R + GitHub MCPs: verify the full T&R + GitHub combination renders correctly and the completion report includes the T&R limitations section
- [ ] 14.5 Test generation when both Atlassian and Bosch T&R MCPs are present: verify the user prompt fires and selection determines the active tracker
- [ ] 14.6 Test generation when both ADO and GitHub MCPs are present: verify the user prompt fires and selection determines the active repo backend
- [ ] 14.7 Test generation when no tracker MCP is detected: verify both tracker flags are false, the warning is emitted, the SKILL.md tracker phases are omitted, and `config.json` has no `tracker` discriminator and no `jira`/`tr` blocks
- [ ] 14.8 Test generation when no repo MCP is detected: verify Phase 6 is omitted from SKILL.md and `config.json` has no `repo`/`azureDevOps`/`github` blocks
- [ ] 14.9 Run a `/start-feature` end-to-end on a freshly generated TRACKER_TR + REPO_GITHUB project against a real T&R ticket: verify no comment spam (single summary comment at Phase 7), labels are additive (not overwritten), and the PR is created with `Closes #N` linking
