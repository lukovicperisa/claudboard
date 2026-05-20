## Why

The feature-workflow's Phase 7b cost comment blocks on an interactive `/cost` prompt — asking the user to type the command and paste back the result — which silently stalls the workflow at the end of Phase 6/start of Phase 7, leaving ticket finalization incomplete. The fix is to compute the actual session cost autonomously from the Claude Code session JSONL (which contains full per-turn token usage including all sub-agent spawns) and display a richer per-phase/per-agent breakdown table so the cost comment is more useful than a single number.

## What Changes

- **Remove** the interactive `/cost` step from Phase 7b in both the JIRA and T&R workflow variants
- **Add** spawn-count tracking instructions at Phase 1 kickoff and each phase transition, so Phase 7b has the data it needs without scanning tool history
- **Add** a bash cost-computation script to Phase 7b that reads `~/.claude/projects/<encoded-cwd>/$CLAUDE_CODE_SESSION_ID.jsonl`, sums token usage per model, and applies per-model pricing from `claude-pricing.md`
- **Replace** the `$XX.XX (from /cost)` placeholder with `Actual session cost: $X.XX` derived from the JSONL computation
- **Add** a per-phase/per-agent breakdown table to the ticket comment: spawn count × mid-range profile estimate per agent, with an orchestrator row that reconciles to the actual total (`actual_total − Σ sub_agent_estimates`)

## Capabilities

### New Capabilities

- `automated-cost-computation`: Autonomous actual session cost computation from the Claude Code session JSONL, with per-phase/per-agent breakdown that reconciles to the real total

### Modified Capabilities

- `feature-workflow-generation`: Phase 7b cost comment section changes — new cost script instructions, spawn-count tracking, and updated comment template

## Impact

- `skills/claudboard-workflow/references/feature-workflow.template/SKILL.md.template` — the only file that changes; specifically Phase 7b (JIRA, ~line 1826) and Phase 7b (T&R, ~line 1980), plus Phase 1 kickoff and each phase-transition section
- No changes to agent files, config templates, scripts, or reference files
- Generated feature-workflow skills in existing projects are unaffected until regenerated
