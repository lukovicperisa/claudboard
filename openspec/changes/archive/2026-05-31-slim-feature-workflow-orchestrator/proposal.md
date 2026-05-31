## Why

The generated `feature-workflow/SKILL.md` lands at ~1700 lines for any project that picks one tracker, one repo backend, and no workspace mode. The orchestrator (Sonnet 4.6) holds the entire file in context for every turn of a workflow run — typically 30-60 turns plus 2-4 cache-cold reloads when the user pauses at the 1d spec/plan gate beyond the 5-minute prompt-cache TTL. Rough per-run cost just to keep SKILL.md in context: **$0.10-0.30**, with proportional latency on cold reloads.

Investigation found three structural sources of bloat that are pure repetition, not signal:

1. **39 verbatim "Tool: Agent / paste the full contents / INPUT CONTEXT / allowedTools" spawn blocks** (~10-15 lines each, ~400-600 lines total). The orchestrator learned the spawn shape by spawn #2; the next 37 repetitions teach it nothing new.
2. **42 inline "If gate=mcp: Call `mcp__bosch__*`" reminders** sprinkled into every phase, agent boundary, and checkpoint (~80 lines). Mechanical bookkeeping that one stated rule near the top can replace.
3. **TRACKER_JIRA and TRACKER_TR mirror sections** for Phase 1-pre, Phase 7 finalize, error handling, description-update (~876 lines combined). The 37-line Python cost script is **duplicated character-for-character** between the two Phase 7 paths; so are the cost-comment markdown template and the per-phase computation rules.

Plus ~50 lines of smaller tightening (8-dimension rubric restated three times, halt-mechanics rule restated three times, AC template inlined in two places).

The bet is that one stated pattern beats N inline reminders for Sonnet — low-risk, eval-gated.

## What Changes

- **NEW "Agent invocation contract" section near the top of `SKILL.md.template`** stating the canonical spawn shape once. Per-call sites collapse to `→ spawn <agent-name> action: "<X>", input: { ... }, tools: [ ... ]` style references that omit the boilerplate prompt/HEREDOC wrapping.

- **NEW "Lifecycle signals" subsection in the Gate mode block** stating once that, when `gate=mcp`, the orchestrator emits `phase_start`/`phase_complete` at every phase boundary, `agent_start`/`agent_complete` around every spawn, and `checkpoint_start`/`checkpoint_complete` around every Phase 3 checkpoint. The 42 inline reminders are removed.

- **UNIFIED Phase 7 cost-analysis section** that is shared by both `TRACKER_JIRA` and `TRACKER_TR` (gated by `IF TRACKER_JIRA || TRACKER_TR` — i.e., any-tracker). The 37-line Python cost script, computation rules, and markdown template appear ONCE. Only the post-step (worklog emission for Jira; comment-only for T&R) branches on tracker identity.

- **UNIFIED 1-pre ticket setup** structure: shared "fetchAndPrepare" and "compute additive labels" steps with tracker-specific tool invocations only at the leaf. Path B (auto-create) remains JIRA-only.

- **UNIFIED error handler** stating the recoverable/non-recoverable taxonomy once. Tracker-specific failure transition tools branch at the leaf step.

- **TIGHTENED 1a Clarify section** — the 8-dimension list appears once as the canonical reference; the three modes (autopilot/balanced/manual) reference it instead of restating.

- **TIGHTENED Halt mechanics** — one canonical statement of "plain text does not pause the CLI"; downstream sections reference it instead of restating in full.

- **TIGHTENED AC template placement** — the `## Goal / ## Acceptance Criteria / ## Context` block lives in `references/ticket-description-template.md` (already used by the orchestrator at runtime via Read); SKILL.md, jira-agent, and architect-agent all reference the same file. (Architect-agent and jira-agent updates are in the sibling `slim-feature-workflow-agents` change.)

- **NO change to runtime behavior or output format.** The orchestrator still spawns the same agents with the same INPUT CONTEXT shapes; gates still fire in the same modes; cost analysis still posts the same comment.

- **NO change to capability flags or substitution variables.** The capability resolution machinery is untouched.

## Capabilities

### Modified Capabilities

- `feature-workflow-template`: The `SKILL.md.template` source SHALL state the agent-spawn contract and gate=mcp lifecycle-signal contract once each near the top; SHALL collapse per-call sites to reference-style notation; SHALL unify the Phase 7 cost-analysis, Phase 1-pre ticket setup structure, and error handler across `TRACKER_JIRA` and `TRACKER_TR`. The generated `SKILL.md` size SHALL drop from ~1700 lines to ~1000 lines for a single-tracker single-repo project (~41% reduction).

## Impact

- **Files modified:**
  - `skills/claudboard-workflow/references/feature-workflow.template/SKILL.md.template` (primary)
  - `skills/claudboard-workflow/references/feature-workflow.template/references/ticket-description-template.md` (new file — small, ~25 lines)

- **Generated-artifact behavior change:** None. The orchestrator's external behavior is unchanged — same agents spawned, same INPUT CONTEXT, same gate semantics, same cost-comment shape.

- **Estimated runtime savings per workflow run:**
  - Per-turn input cost drops ~41% on SKILL.md (~12k → ~7k tokens)
  - Cache-cold reload after long user pauses: $0.036 → $0.021
  - Total per-run SKILL.md context cost: $0.10-0.30 → $0.06-0.18

- **Eval requirement:** One full-workflow eval against a Bosch-style repo (craftsphere or MEAS) before declaring victory. If the orchestrator misses a `mcp__bosch__phase_start` or fails to construct a spawn correctly from the stated pattern, the change is reverted or the boilerplate is reintroduced at the failing site.

- **Out of scope (explicit):**
  - Extracting cost analysis to a dedicated `cost-analyst-agent` (deferred — separate explore session)
  - Agent-file slimming (covered by sibling change `slim-feature-workflow-agents`)
  - Changes to `block-catalog.md`, `substitution-catalog.md`, or capability-flag resolution
  - Changes to non-template files (`config.json.template`, scripts)

- **Upgrade path:** Per the documented v1 caveat, projects that already ran `/claudboard-workflow` will not auto-pick up the slimmer template. Users wanting the slimmer SKILL.md remove `.claude/skills/feature-workflow/` and re-run `/claudboard-workflow`. No data migration required.

- **Rollback:** If eval surfaces orchestration regressions, revert the change. Generated skills from before/after the change continue to work independently.
