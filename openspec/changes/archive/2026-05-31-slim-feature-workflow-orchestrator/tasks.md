## Tasks

### Bucket A — Agent invocation contract

- [x] Add "Agent invocation contract" section to `SKILL.md.template` near the top (after Agent architecture, before Error handling)
- [x] Define the canonical spawn shape (prompt = agent.md + INPUT CONTEXT, allowedTools from per-call list, gate=mcp wrapping rule)
- [x] Define the `→ spawn <agent>` shorthand notation used at per-call sites
- [x] Replace all 39 `Tool: Agent / Parameters: / prompt: |` blocks with the shorthand notation
- [x] Verify every spawn site retains: agent name, action, INPUT CONTEXT fields, `allowedTools` list

### Bucket B — Lifecycle signals consolidation

- [x] Add "Lifecycle signals (gate=mcp only)" subsection to the Gate mode block
- [x] Encode the signal-emission rule as a table (phase_start/_complete, agent_start/_complete, checkpoint_start/_complete)
- [x] Remove all 42 inline `**If gate=mcp:** Call mcp__bosch__*` reminders throughout the document
- [x] Verify the Gate mode block's "Hard contract" rules remain unchanged
- [x] Verify gate=interactive guidance is unaffected

### Bucket C — Phase 7 cost-analysis unification

- [x] Decide capability-flag strategy: introduce `||` compound condition support OR use shared `references/phase7-cost-analysis.md` snippet referenced by two single-flag blocks
- [ ] If using `||`: update `references/block-catalog.md` to document the compound-condition syntax and update generator's flag-resolution logic
- [x] If using snippet: create `references/phase7-cost-analysis.md` with the Python script, computation rules, markdown template (single source of truth)
- [x] Restructure Phase 7 to: 7a worklog (tracker-branched), 7b cost analysis (shared), 7c transition (tracker-branched at leaf)
- [x] Remove the duplicate Python cost script from the second tracker path
- [x] Verify final-report-to-user blocks remain tracker-aware (different reminder text for T&R about worklog absence)

### Bucket C — Phase 1-pre and Error handler unification

- [x] Restructure Phase 1-pre with shared Path A "fetchAndPrepare" structure; tracker-specific tool invocations at leaf only
- [x] Keep Path B (auto-create) as a JIRA-only block — T&R explicitly does not support
- [x] Restructure Error handler with shared recoverable/non-recoverable taxonomy; tracker-specific failure transition tool invocation at leaf

### Bucket D — Tightening

- [x] Move the 8-dimension list to a single canonical block at the start of Phase 1a Clarify
- [x] Have `autopilot`, `balanced`, `manual` subsections reference the canonical list instead of restating
- [x] Reduce Halt mechanics restatement: state once in the Halt mechanics section; downstream sections reference it
- [x] Create `references/ticket-description-template.md` with the `## Goal / ## Acceptance Criteria / ## Context` template + tracker-specific AC placement note
- [x] Update SKILL.md to reference the new file at description-composition sites instead of inlining the template
- [x] (Note: agent-side updates to jira-agent and architect-agent are in the sibling `slim-feature-workflow-agents` change — coordinate landing order)

### Verification

- [ ] Generator dry-run on craftsphere-style config — verify generated SKILL.md is 30-45% smaller and contains no remaining `Tool: Agent / Parameters:` blocks or `**If gate=mcp:** Call mcp__bosch__*` inline reminders (except in the canonical sections)
- [ ] Generator dry-run on MEAS workspace config (workspace mode + T&R + ADO) — verify capability-flag resolution still produces the right tracker/workspace blocks
- [ ] Full feature-workflow eval against a Bosch-style repo with gate=mcp — verify every spawn lands with the right INPUT CONTEXT and `allowedTools`; verify the bosch UI receives every expected lifecycle signal at the expected boundaries
- [ ] Full feature-workflow eval with gate=interactive — verify no `mcp__bosch__*` calls are emitted and gates use AskUserQuestion/end-of-turn correctly
- [ ] Compare a Phase 7 ticket comment from before/after to confirm shape is byte-identical (the cost-analysis output should not have drifted)

### Documentation

- [x] Update `skills/claudboard-workflow/SKILL.md` orchestrator description (if it documents template size/content)
- [x] Add a note to `CLAUDE.md` "Generated feature-workflow" section that the template was slimmed in this change — no behavior change, runtime artifact differs in shape only
- [ ] Note in change-archive entry: any new project generated after this change will get the slim version; existing generated projects keep the verbose version until they re-run `/claudboard-workflow`
