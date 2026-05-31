## The bet

The orchestrator (Sonnet 4.6) can follow a stated pattern reliably without per-instance reminders. We're replacing ~580-780 lines of inline repetition with single canonical statements, betting that the model:

1. Spawns agents correctly from a one-paragraph contract instead of 39 verbatim templates.
2. Fires `mcp__bosch__*` lifecycle signals at the right boundaries from a one-paragraph rule instead of 42 inline reminders.
3. Branches tracker-specific behavior at leaf steps when the orchestrating structure is unified.

If the bet is wrong, we re-inline the failing pattern. Failure mode is "Sonnet skips a lifecycle signal" or "Sonnet constructs a malformed Agent call" — both detectable in an eval run.

---

## What replaces what

### Agent invocation contract (replaces ~400-600 lines of spawn boilerplate)

**Before** (current pattern, 39 occurrences, ~10-15 lines each):

```
Tool: Agent
Parameters:
  prompt: |
    <paste the full contents of jira-agent.md as instructions>

    INPUT CONTEXT:
    { "action": "addWorklog", "ticketKey": "...", "timeSpent": "...", "comment": "..." }
  allowedTools:
    - mcp__atlassian__addWorklogToJiraIssue
```

**After** (canonical contract stated once near the top):

```markdown
## Agent invocation contract

Every spawn uses the Agent tool with:
  prompt = <full contents of agents/<agent>.md> + "\n\nINPUT CONTEXT:\n" + <json>
  allowedTools = the per-call tool list listed in each spawn site

When this document writes "→ spawn <agent>" with action/input/tools, that is
shorthand for the full Agent call described above. Do not invent extra
allowedTools entries — use exactly what is listed.

If gate=mcp, wrap every spawn with mcp__bosch__agent_start before and
mcp__bosch__agent_complete after.
```

Per-call sites collapse:

```
→ spawn jira-agent
  action: "addWorklog"
  input:  { ticketKey, timeSpent, comment: "Implementation work" }
  tools:  [mcp__atlassian__addWorklogToJiraIssue]
```

Net: ~10-15 lines × 39 → ~5 lines × 39 + one 12-line contract section. Savings: ~250-400 lines.

### Lifecycle signals (replaces ~80 lines of `If gate=mcp:` reminders)

**Before** (42 inline occurrences scattered throughout):

```
**If gate=mcp:** Call `mcp__bosch__phase_start` with `{ num: 3, title: "Develop and test" }`.
...
**If gate=mcp:** Call `mcp__bosch__agent_start` with `{ name: "implementation-agent", op: "checkpoint 1" }`.
...
**If gate=mcp:** Call `mcp__bosch__checkpoint_complete` with `{ num: 1 }`.
```

**After** (single canonical rule in the Gate mode block):

```markdown
### Lifecycle signals (gate=mcp only)

When gate=mcp, emit lifecycle signals at the obvious structural boundaries:

| Signal | When | Payload |
|--------|------|---------|
| `phase_start` | Entry of each phase | `{ num, title }` (from phase heading) |
| `phase_complete` | Exit of each phase | `{ num }` |
| `agent_start` | Before every Agent spawn | `{ name, op }` (name from agent file, op from action) |
| `agent_complete` | After every Agent spawn returns | `{ name }` |
| `checkpoint_start` | Around each Phase 3 checkpoint (including baseline as num: 0) | `{ num, title }` |
| `checkpoint_complete` | After each Phase 3 checkpoint completes | `{ num }` |

When gate=interactive, omit all lifecycle signals entirely.
```

Net: ~80 lines removed; one ~15-line table replaces them.

### Unified Phase 7 cost analysis (replaces ~180 lines of mirror duplication)

**Before:** Two separate Phase 7 sections (JIRA: 190 lines, T&R: 135 lines). The 37-line Python cost script, computation rules, and markdown comment template appear in both verbatim.

**After:** One Phase 7 section gated by `<!-- IF TRACKER_JIRA || TRACKER_TR -->` (or equivalent "any tracker" condition). Structure:

```markdown
## Phase 7: Finalize ticket

### 7a. Log implementation work
<!-- IF TRACKER_JIRA -->
→ spawn jira-agent  action: "addWorklog", input: { ... }, tools: [...]
<!-- ENDIF -->
<!-- IF TRACKER_TR -->
T&R does not support worklog. Hold IMPL_ELAPSED for the 7b comment.
<!-- ENDIF -->

### 7b. Cost analysis comment

<the 37-line Python script — once>
<computation rules — once>
<markdown comment template — once>

→ spawn <tracker>-agent  action: "addComment", input: { ticketKey, commentBody }, tools: [...]

### 7c. Transition to success state

→ spawn <tracker>-agent  action: "transition", input: { ticketKey, lifecycleState: "success" }, tools: [...]
```

The generator's existing capability-flag resolution handles `||` conditions, or — fallback — two single-flag blocks each containing the same content (deduplicated at template-source level, kept identical via single source of truth).

**Note on `||` support:** If `block-catalog.md` does not currently support compound conditions, the implementation MAY introduce them OR fall back to: keep two IF blocks but have both reference the same `references/phase7-cost-analysis.md` fragment that the generator inlines. Decision deferred to implementation; both options achieve the dedup goal.

Net: ~150-180 lines saved.

### Tightened sub-bucket changes

- **8-dimension rubric:** state the canonical list once at the start of section 1a; have `autopilot`, `balanced`, `manual` subsections reference it.
- **Halt mechanics restatement:** one canonical statement; downstream sections say "see Halt mechanics" instead of restating.
- **AC template:** move to `references/ticket-description-template.md`; SKILL.md says "compose using the template at references/ticket-description-template.md" and the agent reads it.

Net: ~50 lines saved.

---

## What stays inline (deliberately not deduplicated)

- **JSON result-block schemas** for each agent's response. These are precise and short, and the orchestrator's parse-and-route logic depends on knowing the exact field names. Worth the inline cost.
- **Path A / Path B branching** for ticket setup. The control flow is genuinely different and inlining beats indirection.
- **Capability-flag IF blocks for stack-specific reminders** (the `STACK_REMINDERS` substitution). These are tailored at generation time and don't appear redundantly at runtime.
- **Phase ordering and dependencies.** The "Phase N: title" headings stay as-is.

---

## Risks

| Risk | Severity | Mitigation |
|------|----------|------------|
| Sonnet misconstructs a spawn from the stated contract | Medium | Eval-gate: one full workflow run against a Bosch-style repo before merge. Specific check: did every Agent call include the right `allowedTools` set? |
| Sonnet skips a `mcp__bosch__phase_start` when gate=mcp | Medium | Eval-gate same as above. Specific check: did the bosch UI receive every expected lifecycle signal? Failure mode is recoverable (UI just won't show the signal) — not catastrophic. |
| Unified Phase 7 introduces a tracker-specific bug | Low | The branching is at leaf steps only (worklog emission for Jira; comment-only for T&R). All other logic is shared and trivially correct for both. |
| `||` operator in capability-flag resolution doesn't exist | Low | Fall back to: two IF blocks both referencing a shared `references/phase7-cost-analysis.md` snippet. Generator inlines the snippet. Same end-state without changing the condition language. |
| Generator's existing tests break on the new template shape | Low | The substitution machinery is unchanged. Only template content moves. Run existing generator tests; expect zero diff in flag-resolution behavior. |

---

## Estimated end-state line counts

```
Section                          Before    After     Δ
─────────────────────────────────────────────────────────
Spawn boilerplate                 ~580     ~195    -385
gate=mcp lifecycle reminders       ~80      ~15     -65
Phase 7 mirror (JIRA + TR)         ~325    ~165    -160
Phase 1-pre mirror                 ~253    ~165     -88
Error handler mirror                ~80      ~50     -30
8-dim rubric / halt / AC tightening ~50     ~10     -40
─────────────────────────────────────────────────────────
Total                              ~1368   ~600    -768

SKILL.md.template:  2474 → ~1700
Generated SKILL.md (1 tracker, 1 repo, no workspace):  ~1700 → ~1000
```

Numbers are estimates from the current template; actual savings depend on how aggressively the tightening lands. The proposal stands if the actual reduction is ≥30%.
