## Context

The feature-workflow SKILL.md.template (generated into target projects as `.claude/skills/feature-workflow/SKILL.md`) drives a multi-phase AI-assisted development workflow. Phase 7 finalizes the tracker ticket with a worklog, cost comment, and status transition. Phase 7b is the cost comment step.

Current Phase 7b flow:
1. Read `claude-pricing.md`
2. Collect workflow metadata
3. **Ask the user to type `/cost` and paste the result** ← blocks here
4. Use the pasted value as "Actual session cost"
5. Compose and post the comment

The `/cost` command is a Claude Code CLI slash command — only the user can invoke it; Claude cannot call it as a tool. When the skill asks the user for it, the user either doesn't know what to do or doesn't notice the prompt in a long output stream, silently stalling Phases 7b and 7c (and leaving the ticket in an incomplete state).

**Investigation findings** (from `openspec-explore` session, 2026-05-20):
- `CLAUDE_CODE_SESSION_ID` env var is set in every Claude Code session — no PID lookup needed
- JSONL path: `~/.claude/projects/<cwd-slashes-to-dashes>/<session-id>.jsonl`
- Each assistant turn in the JSONL contains a `usage` object with `input_tokens`, `cache_creation_input_tokens`, `cache_read_input_tokens`, `output_tokens`, and `cache_creation.ephemeral_{5m,1h}_input_tokens`
- Sub-agent spawns (via Agent tool) are **embedded in the parent JSONL** — no separate files created
- The JSONL contains `model` per turn, enabling per-model cost breakdown (Sonnet vs Haiku)
- Phase/agent attribution is **not available** in the JSONL — no phase markers exist

## Goals / Non-Goals

**Goals:**
- Eliminate the interactive `/cost` prompt so Phase 7b completes autonomously
- Compute the actual session cost from the JSONL (exact, not estimated)
- Display a per-phase/per-agent breakdown table in the ticket comment
- The breakdown table must reconcile to the actual total

**Non-Goals:**
- Real-time per-turn cost tracking during the workflow (too heavy)
- Breaking out orchestrator cost per phase (JSONL has no phase markers)
- Modifying generated skills already deployed in target projects (must regenerate)
- Adding new MCP tools or external services

## Decisions

### D1: Use CLAUDE_CODE_SESSION_ID env var to locate the JSONL

**Decision:** Read `$CLAUDE_CODE_SESSION_ID` (always set by Claude Code) and compute the JSONL path as `~/.claude/projects/$(pwd | sed 's|/|-|g')/$CLAUDE_CODE_SESSION_ID.jsonl`.

**Alternatives considered:**
- Parse `~/.claude/sessions/<pid>.json` via `echo $$`: fragile — `$$` in a bash subprocess is the shell PID, not the Claude Code process PID. The env var is cleaner and guaranteed.
- Prompt the user for the session ID: defeats the purpose.

**Why:** The env var is already there, reliable, and requires zero filesystem searching.

---

### D2: Sub-agent tokens are in the parent JSONL — no aggregation needed

**Decision:** Read only the single JSONL identified in D1. Do not scan sibling files.

**Validation:** Tested across multiple projects — Agent tool spawns produced no separate JSONL files within the same project directory during the parent session's timeframe. All usage appears in the parent's JSONL.

**Risk:** If a future Claude Code version changes this behaviour, the computed total will be lower than the actual cost. Mitigation: the Phase 7b script should note that it covers "the primary session JSONL" so any undercount is at least visible.

---

### D3: Per-phase breakdown = profile × actual spawn count, not JSONL attribution

**Decision:** The JSONL has no phase markers and no sub-agent identity markers. Rather than attempting JSONL-based attribution (which is fragile and inaccurate), use:
- **Actual spawn counts** tracked by the orchestrator as it runs each phase (added as explicit tracking instructions to each phase transition)
- **Mid-range token profiles** from `claude-pricing.md` × spawn count = per-agent estimated cost
- **Orchestrator row** = `actual_total − Σ(sub_agent_estimates)` — this ensures the table sums to the real number

**Why:** Zero extra API calls, zero JSONL complexity, and the reconciled orchestrator row means the total is always exact even if individual sub-agent estimates drift.

---

### D4: Spawn-count tracking via inline memo at each phase transition

**Decision:** Add a lightweight "record spawn counts" instruction to the end of each phase section in SKILL.md.template. The orchestrator holds a running tally (e.g., `SPAWN_LOG: phase1=jira×1,sdd-expert×1,architect×1`) that Phase 7b reads.

**Alternatives considered:**
- Write to a temp file during the workflow: adds filesystem side-effects and cleanup concerns.
- Reconstruct from tool history at Phase 7: expensive and unreliable (history may be compacted).
- Track only at Phase 7 by asking Claude to recall: inaccurate after context compaction.

**Why:** Inline memo is zero overhead, survives context compaction in the main session (it's in the conversation context, not reconstructed), and Phase 7b has a clean structured input.

---

### D5: T&R variant gets the same treatment as the JIRA variant

**Decision:** The T&R Phase 7b also has `$XX.XX (from /cost)` in its comment template. Apply the identical JSONL computation and breakdown table there.

**Note:** The T&R variant's comment is shorter (no separate worklog section) but the cost section structure is the same.

## Risks / Trade-offs

- **JSONL schema change** → If Anthropic changes the usage field structure, the script produces wrong results. Mitigation: the script fails gracefully (outputs `$0.00` with a warning) rather than blocking; the phase can still complete.
- **Different cwd at Phase 7** → If the user changed directory during the workflow, `pwd` returns the wrong path and the JSONL isn't found. Mitigation: capture and store the JSONL path at Phase 1 kickoff (before any cd) and reference that stored path in Phase 7b.
- **Phase 7 cost undercount** → The JSONL is read before Phase 7b/7c complete, so those turns aren't in the total. Accepted; the comment notes this (~$0.05–0.15 typical undercount for a few Haiku calls).
- **Profile drift** → Token profiles in `claude-pricing.md` are estimates; actual per-agent costs may vary. The reconciled orchestrator row absorbs this variance cleanly.

## Migration Plan

No migration needed for currently deployed skills — generated SKILL.md files in target projects are static copies. Projects will get the fix when they regenerate via `/claudboard-workflow`.

The template change is backward-compatible with respect to the generation process: no new reference files, no new config fields, no new flags.
