## 1. Add spawn-count tracking to SKILL.md.template

- [x] 1.1 At the start of Phase 1 (after the `mcp__bosch__phase_start` call, before ticket fetch), add a `SESSION_JSONL_PATH` capture instruction: record `~/.claude/projects/$(pwd | sed 's|/|-|g')/$CLAUDE_CODE_SESSION_ID.jsonl` in the conversation context before any directory change occurs
- [x] 1.2 At the end of Phase 1 (after `mcp__bosch__phase_complete`), add a SPAWN_LOG memo instruction recording which agents were spawned: `phase1: jira-agent×1, sdd-expert×1, architect×1` (or tr-agent×1 if T&R variant)
- [x] 1.3 At the end of Phase 2, add SPAWN_LOG memo: `phase2: git-agent×1`
- [x] 1.4 At the end of Phase 3, add SPAWN_LOG memo: `phase3: impl-agent×N (baseline×1, CP×<checkpoint_count>)` where N is the actual number of impl-agent spawns used
- [x] 1.5 At the end of Phase 4, add SPAWN_LOG memo: `phase4: git-agent×<N>` where N is the actual number of git-agent commit spawns
- [x] 1.6 At the end of Phase 5, add SPAWN_LOG memo: `phase5: spec-reviewer×<N>, design-reviewer×<N>` (0 if the review was skipped)
- [x] 1.7 At the end of Phase 6, add SPAWN_LOG memo: `phase6: pr-agent×1, git-agent×1` (adjust for workspace mode where multiple PRs are created)

## 2. Rewrite Phase 7b (JIRA) in SKILL.md.template

- [x] 2.1 Delete Step 3 entirely (`"Please type /cost and share the total..."` block and the `Hold the actual cost value.` line, approximately lines 1842–1847)
- [x] 2.2 After the existing Step 2 (collect workflow metadata), insert a new step: run the JSONL cost script via Bash that reads `SESSION_JSONL_PATH`, sums token usage per model (input, cache_write_5m, cache_write_1h, cache_read, output), applies rates from `claude-pricing.md`, and outputs `ACTUAL_TOTAL` and per-model token counts
- [x] 2.3 Replace `**Actual session cost:** $XX.XX (from /cost)` in the comment template with `**Actual session cost:** $<ACTUAL_TOTAL>` (the value from the script)
- [x] 2.4 Replace the generic per-phase example table in the comment template with instructions to build the table from SPAWN_LOG: for each phase/agent entry, compute `spawns × mid-range_profile_cost` from `claude-pricing.md`; add the agent's model in the Model column
- [x] 2.5 Add orchestrator row computation instruction: `orchestrator_cost = ACTUAL_TOTAL − Σ(sub_agent_row_estimates)`; show as `| Orchestrator | — | Sonnet 4.6 | — | $X.XX |`; this ensures the table total equals ACTUAL_TOTAL exactly
- [x] 2.6 Replace the footer note in the comment template: remove the `/cost` reference, add `> Actual total from session token log (includes all agent spawns). Phase 7 finalization (~$0.05–0.15) not included. Per-agent rows are profile estimates × actual spawn count.`
- [x] 2.7 Renumber the steps in Phase 7b (JIRA) to be sequential after the deletion: Step 1 (read pricing), Step 2 (collect metadata + run JSONL script), Step 3 (build table), Step 4 (compose comment), Step 5 (post comment)

## 3. Rewrite Phase 7b (T&R) in SKILL.md.template

- [x] 3.1 Replace `**Actual session cost:** $XX.XX (from /cost)` (approximately line 2000) in the T&R summary comment template with `**Actual session cost:** $<ACTUAL_TOTAL>` computed from the same JSONL script
- [x] 3.2 Add the per-phase breakdown table to the T&R cost section, same structure as the JIRA variant (Phase/Agent/Model/Spawns/Est. Cost, with reconciled orchestrator row)
- [x] 3.3 Add a step before the T&R comment composition instruction to run the JSONL cost script (same script as JIRA variant; reference SESSION_JSONL_PATH)
- [x] 3.4 Update the T&R footer note to remove the `/cost` reference, same wording as JIRA variant

## 4. Verify

- [x] 4.1 Read through the updated Phase 1 kickoff and all six phase-transition SPAWN_LOG instructions to confirm they cover every agent type used in the workflow (jira-agent, tr-agent, sdd-expert, architect, git-agent, impl-agent, spec-reviewer, design-reviewer, pr-agent)
- [x] 4.2 Read through the full updated Phase 7b (JIRA) section end-to-end and confirm: no `/cost` prompt remains, JSONL script is present and correct, comment template has actual total + breakdown table + reconciled orchestrator row + correct footer
- [x] 4.3 Read through the full updated Phase 7b (T&R) section and confirm the same properties
- [x] 4.4 Grep the entire SKILL.md.template for `/cost` to confirm no remaining interactive prompts referencing the command as a required user action
