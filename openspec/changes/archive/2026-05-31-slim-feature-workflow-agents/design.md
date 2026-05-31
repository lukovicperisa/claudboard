## Design choice — source dedup with generation-time inlining

Two ways to dedup repeated content across agents:

**Option A — runtime concatenation:** Agent files reference shared snippets (`include _common-preamble.md`). The orchestrator reads agent + snippet at spawn time, concatenates, passes as prompt.

**Option B — generation-time inlining:** Template tree contains shared snippets. The generator (`/claudboard-workflow`) reads each snippet, inlines it into each agent file during render, and writes the assembled agent file to disk. The runtime agent file is self-contained — orchestrator behavior is unchanged.

**We choose Option B.** Reasons:

- Runtime contract unchanged — no new ways for the orchestrator to break
- Sub-agent prompt loading is one file, not several — keeps spawn behavior simple
- Output agent file is grep-able and human-readable as a single unit
- The duplication problem we're solving is a **source** problem (template tree hygiene), not a runtime token problem; Option B addresses the source while preserving the runtime artifact's existing shape

The token savings at runtime come from the trimmed content of each agent file (the snippets ARE shorter than what they replace), not from sharing at runtime.

---

## What replaces what

### Bucket E — Shared agent preamble

**Before** (each agent has ~25-40 lines of opening boilerplate):

```markdown
# JIRA Ticket Agent

You are a scoped sub-agent responsible for JIRA ticket operations. You
execute the action specified by the `action` field in INPUT CONTEXT.

You have access to the Atlassian MCP tools and the `Read` tool (for loading
configuration). Do not attempt shell commands or other tool calls outside
of that scope.

## Configuration

Before any action, read project configuration:

\`\`\`
Tool: Read
file_path: .claude/skills/feature-workflow/config.json
\`\`\`

Extract these values and substitute them wherever the actions below use a
`<config:KEY>` placeholder: [table]

[...]

When you are done, emit a JSON result block — nothing else after it — so the
calling agent can parse it reliably.
```

**After** (shared preamble + per-agent specifics):

```markdown
# JIRA Ticket Agent

{{INCLUDE references/agent-preamble.md}}

## Configuration

Read `.claude/skills/feature-workflow/config.json`. Extract:

| Placeholder | JSON path |
|-------------|-----------|
| ... (only the table, no surrounding prose) |
```

Where `references/agent-preamble.md` is:

```markdown
You are a scoped sub-agent. Execute the action specified by the `action`
field of the INPUT CONTEXT block your caller provides. Your tool access is
limited by the frontmatter `allowedTools` — do not attempt tool calls outside
that set. When done, emit a single JSON result block as your final output;
emit nothing after it so the caller can parse it reliably.
```

Generator behavior: when rendering each agent file, the generator substitutes `{{INCLUDE references/agent-preamble.md}}` with the file contents. The output agent file contains the inlined preamble.

Per-agent net savings: ~20-30 lines × 10 agents = ~200-300 lines across the corpus, and each generated agent is smaller at runtime.

### Bucket F — Shared context-loading snippet

**Before** (each context-aware agent has 30-65 lines of "read CLAUDE.md and rules first"):

The current sdd-expert version (lines 36-65), architect (lines 36-70), and implementation (lines 63-128) each restate the same priority order with different wording.

**After** (shared snippet + per-agent extraction note):

`references/agent-context-loading.md`:

```markdown
Before doing your specific work, load THIS {{REPO_OR_SERVICE_LABEL}}'s context.
Read in this order:

1. `CLAUDE.md` at the root — stack, conventions, base package, DI/logging/test pattern
2. `.claude/rules/*.md` — `paths:` frontmatter tells you which rules apply
3. `.claude/memories/` — cross-service/ecosystem context
4. `.claude/skills/` — list project skills; follow their recipes if relevant

If any file is missing, note it in `risks` (or `openQuestions` if this agent emits one) and continue with what's available.
```

Each agent then has a 3-line note:

```markdown
{{INCLUDE references/agent-context-loading.md}}

**What to extract for this agent:** domain vocabulary (entity names, exception
types, event names) for use in Gherkin scenarios — keep wording consistent
with existing code.
```

Per-agent net savings: ~25-50 lines × 5 agents = ~150 lines.

### Bucket G — Architect Plan structure tightening

**Before** (lines 509-650, ~140 lines): full skeleton with example bodies.

```markdown
## Plan structure

Write the plan to `<specDir>/execution-plan.md`:

\`\`\`markdown
# Execution Plan: <feature title>

## Target {{REPO_OR_SERVICE_LABEL}}
<name and path>

## Context referenced
- CLAUDE.md
- .claude/rules/<list of files actually read>
...

## Software contracts

### REST API
<endpoint contracts for each operation>

### Domain model
<entity contracts>
[...]
\`\`\`
```

**After** (~60-80 lines): skeleton headings only with one-line guidance each. Phase C remains authoritative for contract content.

```markdown
## Plan structure

Write to `<specDir>/execution-plan.md`. Required headings:

- `# Execution Plan: <title>`
- `## Target {{REPO_OR_SERVICE_LABEL}}` — name and path
- `## Context referenced` — files actually read
- `## Architecture layers affected` — list
- `## Software contracts` — one subheading per contract from Phase C; the contract body follows the Phase C template exactly
- `## Checkpoints` — see "Checkpoint structure" below
- `## Testing strategy`, `## Risks and open questions`

[Tracker-specific AC placement note: see references/ticket-description-template.md]
```

Net savings: ~60-80 lines.

### Bucket H — AC template consolidation

The `## Goal / ## Acceptance Criteria / ## Context` template lives in `references/ticket-description-template.md` (created by the sibling `slim-feature-workflow-orchestrator` change). In this change:

- `jira-agent.md`'s `create` and `updateDescription` actions reference the file instead of inlining the template
- `architect-agent.md`'s Plan structure section's "Acceptance Criteria placement" subsection references the file

Net savings in agents: ~30-40 lines. The drift-protection win (one source of truth across orchestrator + 2 agents) is the more important outcome.

### Bucket I — Shared reviewer protocol

**Before**: spec-reviewer (278 lines) and design-reviewer (230 lines) share Step 1 / 2 / 5 / Determining-passed-failed / Output sections with near-identical wording.

**After**: `references/reviewer-protocol.md` (~90 lines) contains the shared scaffolding. Each reviewer file shrinks to its rubric-specific content.

`references/reviewer-protocol.md`:

```markdown
## What you receive
[INPUT CONTEXT description common to both reviewers]

## Workspace-mode: load per-repo context first
[the workspace section common to both]

## Step 1: Load context
[shared: read changed files via git-agent get-changed-files, etc.]

## Step 2: Read all relevant inputs
[shared: read changed source/test files]

## Step 5: Compile findings
[shared findings structure: file, line, severity, type, description, suggested fix]

## Determining passed/failed
[shared: passed = no Critical findings]

## Output
[shared JSON result block structure]
```

Each reviewer retains only:

- Frontmatter
- A one-line agent description ("Verify implementation matches BDD spec scenarios" / "Verify code quality against repo standards")
- The preamble include
- Step 3 (rubric-specific) and Step 4 (rubric-specific)
- An `{{INCLUDE references/reviewer-protocol.md}}` at the appropriate point

Net savings: ~80-120 lines.

### Bucket J — Per-action output JSON shape consolidation

Each agent currently states "Output (success)" and "Output (failure)" per action. The failure shape is often the same across actions within the agent.

**Refactor:** Each agent states its standard error/failure-output shape once near the top (just after Configuration). Per-action blocks show only the success shape and reference the standard error shape: *"On failure, emit the standard error shape with `action: '<this action>'`."*

Net savings: ~30-50 lines per agent that has multiple actions (jira-agent, tr-agent, git-agent, implementation-agent, architect-agent, pr-agent-github). Total ~150 lines.

---

## Generator changes

The current generator already supports `{{VAR}}` substitution from a substitution catalog (resolving things like `{{STACK_NAME}}`, `{{BASE_PACKAGE}}`). The new `{{INCLUDE <path>}}` directive is a new feature.

**Implementation note:** `{{INCLUDE <path>}}` can be implemented as a pre-substitution pass that:
1. Walks each agent file
2. Replaces each `{{INCLUDE <path>}}` directive with the contents of `<path>` (resolved relative to the template root)
3. Then runs the normal `{{VAR}}` substitution

This is conceptually similar to C-preprocessor `#include`. The `<path>` is always relative to `skills/claudboard-workflow/references/feature-workflow.template/` and SHOULD point to a `references/*.md` file within that tree.

The `claudboard-workflow` skill's `SKILL.md` (the orchestrator that does generation) MUST be updated to document this new directive in the file-rendering phase.

**Alternative if `{{INCLUDE}}` is too invasive:** the generator's existing per-file rendering loop can hard-code the concat step: "if rendering `agents/<name>.md`, prepend `references/agent-preamble.md`". Less elegant, but no new directive language. Implementation decides between these two.

---

## What stays inline (deliberately)

- **Frontmatter** of each agent (name, model, description, allowedTools). These are agent-specific and must be at the top of the file unchanged.
- **Per-action protocol** (Step 1 / Step 2 / ... per action in jira-agent, tr-agent, etc.). The actions are genuinely different and need their own walkthrough.
- **Per-stack IF blocks** in architect-agent's Phase C (JPA, MongoDB, Kafka, etc.) — these are signal, not bloat, and only render when the stack matches.
- **JSON result schemas** per action — the orchestrator's parse-and-route depends on knowing the exact shape. Worth the inline cost.
- **MCP server invocation examples** — the exact tool name and parameter shape is precise enough that examples earn their lines.

---

## Risks

| Risk | Severity | Mitigation |
|------|----------|------------|
| Sub-agent (Opus) misbehaves with the slim preamble — drops the JSON result block format | Low | The new preamble explicitly states "emit a JSON result block as your final output." Eval-gate with a full workflow run. |
| Trimming the "Read CLAUDE.md first" guidance leads to weaker context loading | Medium | The trimmed snippet still names the four sources (CLAUDE.md, rules, memories, skills) and the priority order. Per-agent override notes preserve agent-specific emphasis. Eval: implementation-agent on craftsphere — does it still follow the BaseEntity pattern correctly? |
| Trimmed architect Plan structure causes the agent to omit headings | Low | The required-headings list is explicit. The Phase C contract templates remain authoritative for body content. Eval: architect-agent on a craftsphere ticket — does the produced execution-plan.md have all required headings? |
| Reviewer protocol shared-base causes one reviewer to miss its rubric | Low | The shared base is scaffolding (Step 1, 2, 5, output); rubric Steps 3 and 4 stay agent-specific and unchanged. |
| `{{INCLUDE}}` directive introduces generator bugs | Low | The directive is a pre-pass over template files; small implementation surface. Add generator tests for the include resolution. |
| Sibling change (`slim-feature-workflow-orchestrator`) lands first and changes the `references/ticket-description-template.md` location | Low | Coordinate landing order. If sibling lands first, this change consumes the file as-is. If this lands first, this change creates the file and the sibling reuses it. |

---

## Estimated per-agent line counts

```
Agent                     Before    After     Δ      Per spawn impact
─────────────────────────────────────────────────────────────────────
architect-agent            ~700     ~520    -180    Opus, 1-3 spawns — biggest $ win
implementation-agent       ~500     ~410     -90    Sonnet, 5-10 spawns — biggest TTFT win
jira-agent                 ~520     ~430     -90    Haiku, 5-7 spawns
git-agent                  ~500     ~430     -70    Haiku, 4-6 spawns
sdd-expert-agent           ~290     ~240     -50    Opus, 1-2 spawns
tr-agent                   ~360     ~280     -80    Haiku, 5-7 spawns
spec-reviewer              ~280     ~190     -90    Sonnet, 1-3 spawns
design-reviewer            ~230     ~160     -70    Sonnet, 1-3 spawns
pr-agent-github            ~370     ~310     -60    Sonnet, 1 spawn
pr-agent-ado               ~200     ~165     -35    Sonnet, 1 spawn
─────────────────────────────────────────────────────────────────────
Total                     ~3950    ~3135    -815
```

Numbers are estimates; actual savings depend on how aggressively the per-agent trimming lands. The proposal stands if each agent drops ≥15% AND no agent loses a documented capability.
