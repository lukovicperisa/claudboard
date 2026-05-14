## 1. Config schema and template

- [x] 1.1 Update `skills/claudboard-workflow/references/feature-workflow.template/config.json.template`: add `jira.transitions` block with `start`/`success` required and `failure`/`pause` optional, defaults `"In Progress"`/`"In Review"`/`"Blocked"`/`null`
- [x] 1.2 Update `config.json.template`: add `jira.labels` block with `ai: ["AI", "AI_CLI"]`, `area` as either `null` or per-area map (default: full Craftsphere map), and `preserveExisting: true`
- [x] 1.3 Add inline JSON comments in the template marking `jira.transitions.pause` as reserved-for-future-use

## 2. jira-agent template rewrite

- [x] 2.1 Edit `skills/claudboard-workflow/references/feature-workflow.template/agents/jira-agent.md`: remove the literal `"In Progress"` and `"In Review"` strings in `create`, `fetchAndPrepare`, and `transition` actions
- [x] 2.2 Replace those strings with config-driven lookups: actions accept `lifecycleState: "start" | "success" | "failure" | "pause"` and resolve to the configured Jira status name from `<config:jira.transitions.{state}>`
- [x] 2.3 Document a new `Action: applyLabels` section that takes `ticketKey` and a fully-resolved `labels` array and writes it via `editJiraIssue` — explicitly state jira-agent SHALL NOT modify the array
- [x] 2.4 Modify `fetchAndPrepare` to return `existingLabels: []` (empty array when no labels) in its result block; remove Step 3d (the prose merge) — defer label writing to the orchestrator's `applyLabels` call
- [x] 2.5 Modify `create` to accept a pre-computed `labels` array from the orchestrator; remove the hardcoded area-label map and the `["<area_label>", "AI", "AI_CLI"]` literal
- [x] 2.6 Remove the `Backend → "BE" | Frontend → "FE" | DevOps → "DevOps" | Docs → "Docs"` map from the agent prose entirely
- [x] 2.7 Update the `transition` action to accept `lifecycleState` instead of `targetStatus`; on missing transition match, return a structured error JSON block including the available transition names so the orchestrator can surface the diagnostic

## 3. Orchestrator (SKILL.md.template) updates

- [x] 3.1 Replace literal `"In Progress"`/`"In Review"` references in `SKILL.md.template` with lifecycle-state names; update the action invocations in Phases 1-pre and 7c
- [x] 3.2 Add an orchestrator-side label-merge step before any jira-agent label call: compute `union(existingLabels, ai_labels, resolved_area_label_for_work_type)` skipping any `null` entries
- [x] 3.3 Replace the `editJiraIssue` label calls (currently routed through `create` / `fetchAndPrepare` body prose) with explicit `applyLabels` invocations using the orchestrator-computed list
- [x] 3.4 Add area-label resolution helper documentation: given the work area (`backend`/`frontend`/`devops`/`docs`) and `jira.labels.area`, return either the configured label or `null` (skip)
- [x] 3.5 Add the top-level try/catch wrapper around the workflow execution; document the recoverable vs non-recoverable distinction inline with the exact lists from the design doc
- [x] 3.6 In the catch block: if the failure is non-recoverable AND `jira.transitions.failure` is non-null, invoke jira-agent with `{ action: "transition", lifecycleState: "failure" }`; always surface the original error to the user; always halt
- [x] 3.7 Audit the existing implementation phase iterate loop to confirm test/lint/build/review failures stay inside it and never bubble into the new try/catch

## 4. Phase 2 prompt flow

- [x] 4.1 Add prompt entries to `skills/claudboard-workflow/references/jira-config-prompts.md` for `jira.transitions.start`, `jira.transitions.success`, `jira.transitions.failure`, `jira.transitions.pause` with Craftsphere defaults and "stub with TODO" escapes
- [x] 4.2 Add prompt entry for the top-level "Does this project use area labels? (y/n)" question; document the short-circuit behavior to `area: null` on "no"
- [x] 4.3 Add per-area prompts for `backend`/`frontend`/`devops`/`docs` (only shown when the y/n answer is "y"); blank input maps to `null` for that area; defaults match Craftsphere on Enter
- [x] 4.4 The `pause` prompt SHALL include explicit "reserved for future use — no v1 command fires this" copy
- [x] 4.5 Add stub-with-TODO field-key entries: `JIRA_TRANSITION_START`, `JIRA_TRANSITION_SUCCESS`, `JIRA_TRANSITION_FAILURE`, `JIRA_TRANSITION_PAUSE`, `JIRA_LABELS_AREA_BACKEND`, etc.

## 5. Verification

- [x] 5.1 Hand-render the template with Craftsphere-style defaults (accept all Enter prompts) and diff against the current Craftsphere `feature-workflow/` to confirm only intended differences (config additions, lifecycle-state references, applyLabels calls) — no behavioral regression
- [x] 5.2 Hand-render with MEAS-style answers (`start: "Doing"`, `success: "Code Review"`, `area: null`) and confirm the rendered `SKILL.md` and `jira-agent.md` contain no `"In Progress"`/`"In Review"`/`"BE"` literals
- [x] 5.3 Trace through each spec scenario against the rendered MEAS output (existing-labels preserved, area:null skips area label, missing failure_transition skips the call, etc.) and confirm the rendered text instructs the orchestrator/agent correctly
- [x] 5.4 Confirm the `pause` field appears in the rendered config with the reserved-for-future-use comment
- [x] 5.5 Update `openspec/changes/jira-agent-project-portability/proposal.md` "Impact" section if any new file is touched that wasn't anticipated
- [x] 5.6 Run `openspec validate jira-agent-project-portability --strict` and resolve any reported issues
