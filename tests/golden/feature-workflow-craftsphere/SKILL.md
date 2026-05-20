---
name: feature-workflow
model: claude-sonnet-4-6
description: >
  Kick off intentional feature work with the full ticketed workflow: clarify
  scope, create a goal-oriented JIRA ticket, set up the branch, develop the
  solution, commit, and open a PR. Use this skill when the user says
  "start feature: X", "start a feature", "kick off work on X", or "full
  workflow for X". This is a deliberate mode the user enters — do NOT
  trigger for casual coding requests, experiments, spikes, or when the user
  just asks to "add X" or "implement X" without explicit feature framing.
  The phrase "start feature" is the signal.
---

# Start Feature Workflow

This skill orchestrates the full lifecycle of intentional feature work:
ticket → clarify → specify → plan → branch → develop → test → commit → review → PR → finalize.

It is designed to be entered deliberately. Experiments and spikes skip this
entirely — the user just codes. This workflow is for work that deserves a
JIRA ticket, a clean branch, and a PR.

**There is exactly one human gate: spec and plan approval in Phase 1.** After
that, all phases run autonomously.

## Project configuration

JIRA, Azure DevOps, and git conventions are externalized to
`.claude/skills/feature-workflow/config.json`. Sub-agents read it directly.
Before Phase 1-pre, verify the config is present and parseable:

```
Tool: Read
file_path: .claude/skills/feature-workflow/config.json
```

Hold these values for use in Phase 1-pre and beyond:
- `<projectKey>` ← `jira.projectKey`
- `<urlBase>` ← `jira.urlBase`
- `<branchTypes>` ← `git.branchTypes` (array, e.g., `["feature","bugfix","hotfix"]`)
- `<branchPattern>` ← `git.branchPattern` (template, e.g., `"{type}/{ticket}/{slug}"`)

If the config is missing or invalid, stop and ask the user to populate it
before continuing — the workflow cannot create tickets or PRs without it.

The main branch (`main` vs `master`) is auto-detected at runtime by the
git-agent and the `prepare-*.sh` scripts via
`.claude/skills/feature-workflow/scripts/lib.sh` — no config entry needed.

## Agent architecture

Specialized work — BDD specification, architecture planning, JIRA ticket
management, and PR creation — runs as scoped sub-agents via the `Agent` tool.
Each sub-agent receives only the tools it needs and a self-contained prompt;
it returns a small JSON result block that the main agent uses to continue.

- **sdd-expert-agent** — domain expert in BDD specifications, writes
  exhaustive Gherkin specs using actor/action/outcome pattern
- **architect-agent** — expert in high-level architecture, software
  contracts (OpenAPI, DB entities, repository ports, DTOs, commands), and
  precise task decomposition into checkpoint-based execution plans
- **jira-agent** — manages JIRA tickets: creation with AI labels, description
  updates, status transitions, work logging, and comments
- **pr-agent** — creates Azure DevOps pull requests
- **spec-reviewer** — verifies implementation matches BDD spec scenarios
- **design-reviewer** — verifies code quality against repo standards and rules
- **git-agent** — handles all git repository operations: branch creation,
  staging, committing, squashing, amending, syncing, and pushing
- **implementation-agent** — implements code changes: baseline verification,
  checkpoint-by-checkpoint development with build/test/lint/live-test loops,
  and review fix application

The main agent's job is to orchestrate: spawn sub-agents, pass context, and
route results. It does not touch Atlassian or Azure DevOps MCP tools
directly — those belong to the sub-agents. It does not write code, run
builds, or execute tests — that belongs to the implementation-agent.

```
Main agent (Sonnet 4.6)
├── Phase 1: Ticket, clarify, specify, plan
│   ├── 1-pre. Create JIRA ticket      → spawn jira-agent (create) → {ticketKey}
│   │         Record WORKFLOW_START timestamp
│   ├── 1a. Clarify scope              (main — conversation)
│   │         → spawn jira-agent (updateDescription)
│   ├── 1b. Create BDD spec            → spawn sdd-expert-agent → {specFiles}
│   ├── 1c. Execution plan             → spawn architect-agent  → {planPath}
│   ├── 1d. User gate                  (user confirms spec + plan)
│   │         → spawn jira-agent (addWorklog — "Requirement refinement work")
│   │         Record CHECKPOINT timestamp
├── Phase 2: Create branch             → spawn git-agent (create-branch)
├── Phase 3: Develop and test
│   ├── 3a. Baseline + checkpoint 1    IN PARALLEL (both run_in_background)
│   │   ├── spawn implementation-agent (baseline)
│   │   └── spawn implementation-agent (checkpoint 1)
│   │   If baseline fails: STOP workflow
│   └── 3b. Remaining checkpoints      → spawn implementation-agent (checkpoint N)
├── Phase 4: Commit                    → spawn git-agent (count-commits, squash, stage-and-prepare, commit)
├── Phase 5: Review
│   ├── 5a. Spec review               → spawn spec-reviewer    → {passed, findings}
│   │         If failed: spawn implementation-agent (fix-findings)
│   │                    → spawn git-agent (amend) → re-spawn spec-reviewer
│   └── 5b. Design review             → spawn design-reviewer  → {passed, findings}
│             If failed: spawn implementation-agent (fix-findings)
│                        → spawn git-agent (amend) → re-spawn design-reviewer
├── Phase 6: PR creation
│   ├── spawn git-agent (validate-pr-readiness, sync-and-push)
│   └── spawn pr-agent                                         → {prUrl}
└── Phase 7: Finalize JIRA             → spawn jira-agent (composite)
              ├── addWorklog — "Implementation work"
              ├── addComment — cost analysis with per-agent breakdown
              └── transition → "In Review"
```

---

## Phase 1: Ticket, clarify, specify, and plan

Call `mcp__bosch__phase_start` with `{ num: 1, title: "Ticket · Clarify · Specify · Plan" }`.

This phase creates the JIRA ticket immediately, then produces two
deliverables before any code is written: a complete BDD specification and
a detailed technical execution plan. Both live in the `specs/` directory
and are committed with the feature — they are code, not throwaway notes.

### Time tracking

Record the workflow start time at the very beginning of Phase 1. This is
used to calculate work log durations later.

```bash
WORKFLOW_START=$(date +%s)
```

Hold this value throughout the workflow. After Phase 1d, calculate the
elapsed time and log it. Record a second timestamp (`CHECKPOINT`) to
measure the implementation phase separately.

### 1-pre. Ticket setup

Read the agent instructions from
`.claude/skills/feature-workflow/agents/jira-agent.md` once and reuse
for all JIRA spawns in Phase 1.

---

**Path A — user provided a JIRA ticket key:**

The ticket already exists. Delegate to the JIRA sub-agent to prepare it
for the workflow (transition, sprint, assign, labels):

```
Tool: Agent
Parameters:
  prompt: |
    <paste the full contents of jira-agent.md as instructions>

    INPUT CONTEXT:
    {
      "action": "fetchAndPrepare",
      "ticketKey": "<ticket key from user>",
      "area": "<BE | FE | DevOps | Docs — infer from user's request>"
    }
  allowedTools:
    - mcp__atlassian__searchJiraIssuesUsingJql
    - mcp__atlassian__getJiraIssue
    - mcp__atlassian__getTransitionsForJiraIssue
    - mcp__atlassian__transitionJiraIssue
    - mcp__atlassian__editJiraIssue
    - mcp__atlassian__atlassianUserInfo
```

The agent will emit a JSON result block. Extract and hold:

```json
{
  "action": "fetchAndPrepare",
  "ticketKey": "<projectKey>-XXXXX",
  "ticketUrl": "<urlBase>/browse/<projectKey>-XXXXX",
  "existingDescription": true,
  "currentStatus": "In Progress"
}
```

Hold `existingDescription` — it determines whether the description is
updated after scope clarification (1a).

Tell the user the ticket URL, then proceed to 1a.

---

**Path B — no ticket provided:**

Create a new ticket. Before spawning the agent, classify the user's
initial request:

**Issue type — Task vs Story:**
- `"Task"` — purely technical/internal work: refactoring, tech debt,
  dependency upgrade, config change, internal tooling, removing dead
  code, migration, performance optimization, fixing code quality
- `"Story"` — new feature, change request, user-facing behavior change,
  new API endpoint, new UI component, business rule change

**Priority — infer from tone and wording:**
- `"Critical"` — words like "critical", "urgent", "production down",
  "hotfix", "breaking", "blocker"
- `"High"` — words like "important", "needed urgently", "ASAP",
  "high priority", "blocking other work"
- `"Medium"` — default for neutral requests, or words like "should",
  "needed", "please add"
- `"Low"` — words like "could", "nice to have", "eventually",
  "when possible", "potential", "consider", "minor"

Delegate to the JIRA sub-agent:

```
Tool: Agent
Parameters:
  prompt: |
    <paste the full contents of jira-agent.md as instructions>

    INPUT CONTEXT:
    {
      "action": "create",
      "scope": "<initial description from user's request — use as-is, even if brief>",
      "area": "<BE | FE | DevOps | Docs — infer from user's request>",
      "issueType": "<Task | Story — from classification above>",
      "priority": "<Critical | High | Medium | Low — from classification above>",
      "acceptanceCriteria": [
        "<derive what you can from the initial request — even if minimal>"
      ],
      "context": "<any background the user mentioned>"
    }
  allowedTools:
    - mcp__atlassian__searchJiraIssuesUsingJql
    - mcp__atlassian__createJiraIssue
    - mcp__atlassian__getTransitionsForJiraIssue
    - mcp__atlassian__transitionJiraIssue
    - mcp__atlassian__editJiraIssue
    - mcp__atlassian__atlassianUserInfo
```

The agent will emit a JSON result block. Extract and hold:

```json
{
  "action": "create",
  "ticketKey": "<projectKey>-XXXXX",
  "ticketUrl": "<urlBase>/browse/<projectKey>-XXXXX"
}
```

For newly created tickets, set `existingDescription` to `false` (the
description will always be refined after clarification).

Tell the user the ticket URL, then proceed to 1a.

### 1a. Clarify scope

Ask targeted questions until every aspect of the feature is understood. You
are building the foundation for an exhaustive spec, so do not leave
ambiguities — dig until the picture is complete.

Things worth clarifying:
- Which monorepo service or MFE is this for?
- Is there a user-facing impact, or is it internal/infra?
- Any known constraints or related tickets?
- Who are the actors? What are their roles and permissions?
- What are the error and edge cases?
- Are there authorization requirements?
- Are there event/integration boundaries (e.g., cross-service calls)?
- What validation rules apply to inputs?

**After scope is fully clarified**, update the JIRA ticket description —
but only if it needs updating:

- **Newly created ticket** (`existingDescription` is `false`): always
  update — refine the initial description with the fully clarified scope.
- **Existing ticket with thin/missing description** (`existingDescription`
  is `false`): update with the clarified scope.
- **Existing ticket with well-populated description** (`existingDescription`
  is `true`): skip the description update — the ticket is already
  well-described.

When updating, compose a description using the ticket description template
(Goal / Acceptance Criteria / Context) populated with the clarified scope,
then delegate to the JIRA sub-agent:

```
Tool: Agent
Parameters:
  prompt: |
    <paste the full contents of jira-agent.md as instructions>

    INPUT CONTEXT:
    {
      "action": "updateDescription",
      "ticketKey": "<ticketKey from 1-pre>",
      "description": "<updated markdown description using the Goal / Acceptance Criteria / Context template, populated with the fully clarified scope>"
    }
  allowedTools:
    - mcp__atlassian__editJiraIssue
```

### 1b. Create the BDD spec

Once scope is fully clear, determine the spec directory, then delegate to
the SDD Expert sub-agent.

**Directory naming:**

Determine the next sequence number by inspecting existing directories:

```bash
ls -d specs/[0-9]* 2>/dev/null | sort -n | tail -1
```

If none exist, start at `001`. Otherwise increment the highest number by 1,
zero-padded to 3 digits. Use `ticketKey` from Phase 1-pre. The directory
name follows this pattern:

```
specs/<NNN>-<TICKET>-<short-slug>/
```

Example: `specs/001-PLAT-12345-short-description/`

**Delegate to sdd-expert-agent:**

Read the agent instructions from
`.claude/skills/feature-workflow/agents/sdd-expert-agent.md`, then spawn
the agent:

```
Tool: Agent
Parameters:
  prompt: |
    <paste the full contents of sdd-expert-agent.md as instructions>

    INPUT CONTEXT:
    {
      "scope": "<clarified scope from 1a>",
      "specDir": "specs/<NNN>-<TICKET>-<slug>/",
      "service": "<service name and path — e.g., invitations-service at services/invitations-service/>",
      "actors": ["<actor 1 and role>", "<actor 2 and role>"],
      "constraints": "<known constraints, related tickets, edge cases>",
      "area": "<BE | FE | DevOps | Docs>"
    }
```

The agent will emit a JSON result block. Extract and hold for Phase 1c:

```json
{
  "specDir": "specs/001-PLAT-12345-short-description/",
  "specFiles": ["business-behavior-spec.md", "authorization-spec.md"],
  "scenarioCount": 15,
  "concerns": ["business-behavior", "authorization"],
  "openQuestions": []
}
```

If `openQuestions` is non-empty, present them to the user and resolve
before proceeding. Do not continue to 1c with unresolved ambiguities.

### 1c. Create the technical execution plan

After the spec is complete, delegate to the Architect sub-agent to produce
the execution plan.

**Delegate to architect-agent:**

Read the agent instructions from
`.claude/skills/feature-workflow/agents/architect-agent.md`, then spawn
the agent:

```
Tool: Agent
Parameters:
  prompt: |
    <paste the full contents of architect-agent.md as instructions>

    INPUT CONTEXT:
    {
      "specDir": "specs/<NNN>-<TICKET>-<slug>/",
      "service": "<service name and path>",
      "area": "<BE | FE | DevOps | Docs>",
      "specFiles": <specFiles array from sdd-expert-agent result>
    }
```

The agent will emit a JSON result block:

```json
{
  "planPath": "specs/001-PLAT-12345-short-description/execution-plan.md",
  "checkpointCount": 4,
  "taskCount": 12,
  "layersAffected": ["domain", "application", "adapter-in", "adapter-out"],
  "contractsDefined": ["rest-api", "domain-model", "db-entity", "repository-port", "command", "authorization"],
  "risks": []
}
```

If `risks` is non-empty, include them in the gate presentation (1d) so the
user can acknowledge or resolve them.

### 1d. Gate — spec and plan review

**Request human approval via the bosch MCP server:**

Read the full text of all spec files in `specDir` and the execution plan,
then call the gate tool:

```
Call mcp__bosch__gate_request with:
{
  "kind": "spec+plan",
  "payload": {
    "ticket": "<ticketKey>",
    "spec": "<full text of all BDD spec files from specDir, concatenated>",
    "plan": "<full text of execution-plan.md>"
  }
}
```

The `gate_request` tool suspends the workflow and delivers the spec + plan to
the bosch web UI for human review. It returns only when the user resolves the gate.

**Branch on the gate result:**

**If result is `"approved"`:** proceed to time-logging below, then Phase 2.

**If result is `{ status: "rejected", changes: "<feedback>" }`:** re-invoke
sdd-expert-agent and architect-agent with the change request, then re-issue
`mcp__bosch__gate_request`. Repeat until approved.

**After the gate is approved**, log the requirement refinement work and record
the checkpoint timestamp before proceeding autonomously.

Calculate elapsed time since workflow start:

```bash
PHASE1_END=$(date +%s)
ELAPSED_SECONDS=$((PHASE1_END - WORKFLOW_START))
```

Convert `ELAPSED_SECONDS` to JIRA time format (e.g., `"1h 30m"`, `"45m"`,
`"2h"`). Round to the nearest 5 minutes. Use hours and minutes — do not
use seconds or days.

Delegate to the JIRA sub-agent to log the work:

```
Tool: Agent
Parameters:
  prompt: |
    <paste the full contents of jira-agent.md as instructions>

    INPUT CONTEXT:
    {
      "action": "addWorklog",
      "ticketKey": "<ticketKey>",
      "timeSpent": "<elapsed time in JIRA format — e.g., 1h 30m>",
      "comment": "Requirement refinement work"
    }
  allowedTools:
    - mcp__atlassian__addWorklogToJiraIssue
```

Record the checkpoint timestamp for Phase 7:

```bash
CHECKPOINT=$(date +%s)
```

Once confirmed and worklog is recorded, execute Phases 2–7 autonomously
without pausing.

Call `mcp__bosch__phase_complete` with `{ num: 1 }`.

---

## Phase 2: Create branch

Call `mcp__bosch__phase_start` with `{ num: 2, title: "Create Branch" }`.

Use `ticketKey` from Phase 1. Derive a short kebab-case slug from the
ticket summary (3-5 words, no area prefix). Do not ask the user.

Branch naming follows `git.branchPattern` from config — by default
`{type}/{ticket}/{slug}` where `{type}` is one of `git.branchTypes`
(default `feature`, `bugfix`, `hotfix`) and `{ticket}` is the full
`<ticketKey>` (e.g., `<projectKey>-12345`).

Example with default config: `feature/<projectKey>-12345/short-description`

Delegate to the git sub-agent. Read the agent instructions from
`.claude/skills/feature-workflow/agents/git-agent.md`, then spawn
the agent:

```
Tool: Agent
Parameters:
  prompt: |
    <paste the full contents of git-agent.md as instructions>

    INPUT CONTEXT:
    {
      "action": "create-branch",
      "branchName": "feature/<projectKey>-XXXXX/short-description"
    }
  allowedTools:
    - Bash
```

The agent will emit a JSON result block:

```json
{
  "action": "create-branch",
  "branch": "feature/<projectKey>-XXXXX/short-description"
}
```

Call `mcp__bosch__phase_complete` with `{ num: 2 }`.

---

## Phase 3: Develop and test

Call `mcp__bosch__phase_start` with `{ num: 3, title: "Develop and Test" }`.

All implementation work is delegated to the implementation-agent. Read the
agent instructions from
`.claude/skills/feature-workflow/agents/implementation-agent.md` once and
reuse for all spawns in this phase.

### 3a. Baseline and checkpoint 1 — in parallel

Launch both the baseline verification and checkpoint 1 simultaneously.
Send them in a **single message with two Agent tool calls**, both with
`run_in_background: true`:

```
Tool: Agent  (run_in_background: true)
Parameters:
  prompt: |
    <paste the full contents of implementation-agent.md as instructions>

    INPUT CONTEXT:
    {
      "action": "baseline",
      "service": "<service path — e.g., services/employees-service/>",
      "area": "<BE | FE>"
    }
  allowedTools:
    - Read
    - Edit
    - Write
    - Bash
```

```
Tool: Agent  (run_in_background: true)
Parameters:
  prompt: |
    <paste the full contents of implementation-agent.md as instructions>

    INPUT CONTEXT:
    {
      "action": "checkpoint",
      "executionPlanPath": "specs/<NNN>-<TICKET>-<slug>/execution-plan.md",
      "checkpointNumber": 1,
      "specDir": "specs/<NNN>-<TICKET>-<slug>/",
      "service": "<service path>",
      "area": "<BE | FE>"
    }
  allowedTools:
    - Read
    - Edit
    - Write
    - Bash
```

Wait for both to complete.

**If baseline fails (`passed: false`):** Stop the entire workflow
immediately. Tell the user the baseline is broken (compilation or boot
failure), include the `failureDetails` from the result, and ask them to
fix the issues before re-invoking the workflow. Any checkpoint 1 work
done in parallel is discarded — the branch can be deleted and recreated.
Do NOT proceed with further checkpoints.

**If baseline passes:** Continue with checkpoint 1's result. If checkpoint 1
also completed successfully, proceed to checkpoint 2. If checkpoint 1 hit a
blocker, present it to the user.

### 3b. Remaining checkpoints

For each remaining checkpoint (2 to N) in the execution plan, spawn the
implementation-agent sequentially:

```
Tool: Agent
Parameters:
  prompt: |
    <paste the full contents of implementation-agent.md as instructions>

    INPUT CONTEXT:
    {
      "action": "checkpoint",
      "executionPlanPath": "specs/<NNN>-<TICKET>-<slug>/execution-plan.md",
      "checkpointNumber": <N>,
      "specDir": "specs/<NNN>-<TICKET>-<slug>/",
      "service": "<service path>",
      "area": "<BE | FE>"
    }
  allowedTools:
    - Read
    - Edit
    - Write
    - Bash
```

**If `completed` is `false`:** the agent hit a blocker. Present the
`blocker` description to the user and wait for guidance before retrying
or proceeding.

**After each checkpoint:** aggregate `testsRun`, `testsPassed`, and
`liveTestResults` from the result into a cumulative test summary. This
summary is passed to the PR agent in Phase 6.

Only proceed to Phase 4 when **all checkpoints are complete** and every
scenario in the BDD spec is satisfied.

---

## Phase 4: Commit

One commit per branch. If multiple commits accumulated during Phase 3, squash
them first. The commit message must be prefixed with `ticketKey` from Phase 1.

All git operations in this phase are delegated to the git sub-agent. Read the
agent instructions from `.claude/skills/feature-workflow/agents/git-agent.md`
once and reuse for all spawns in this phase.

**Important:** The spec directory (`specs/<NNN>-PLAT-XXXXX-slug/`) is code and
must be included in the commit. Pass it as `specDir` to `stage-and-prepare`.

### 4a. Check commit count

Spawn the git-agent:

```
Tool: Agent
Parameters:
  prompt: |
    <paste the full contents of git-agent.md as instructions>

    INPUT CONTEXT:
    {
      "action": "count-commits"
    }
  allowedTools:
    - Bash
```

Extract `commitCount`:
- If **1 commit**: skip to Step 4c
- If **> 1 commits**: run the squash flow (Steps 4b then 4c)
- If **0 commits**: something went wrong in Phase 3 — check staging

### 4b. Squash (only if > 1 commit)

Spawn the git-agent with the `squash` action. The agent runs
`prepare-squash.sh`, creates a backup branch, and does a soft-reset to the
detected main branch. If the rebase encounters conflicts, the agent
reports an error — stop and tell the user to resolve manually.

```
Tool: Agent
Parameters:
  prompt: |
    <paste the full contents of git-agent.md as instructions>

    INPUT CONTEXT:
    {
      "action": "squash"
    }
  allowedTools:
    - Bash
```

Extract `combinedDiff` and `backupBranch` from the result.

Use the `combinedDiff` to compose the commit message (Step 4c format), then
spawn the git-agent with the `commit` action (see 4c below).

After committing, verify the squash integrity by spawning the git-agent with
the `verify-squash` action:

```
Tool: Agent
Parameters:
  prompt: |
    <paste the full contents of git-agent.md as instructions>

    INPUT CONTEXT:
    {
      "action": "verify-squash",
      "backupBranch": "<backupBranch from squash result>"
    }
  allowedTools:
    - Bash
```

If `verified` is `false`, stop and tell the user. Include the recovery
command from the error result.

### 4c. Stage and commit

**Stage** — spawn the git-agent:

```
Tool: Agent
Parameters:
  prompt: |
    <paste the full contents of git-agent.md as instructions>

    INPUT CONTEXT:
    {
      "action": "stage-and-prepare",
      "specDir": "specs/<NNN>-PLAT-XXXXX-slug/"
    }
  allowedTools:
    - Bash
```

**Compose the commit message:**

```
<TICKET>: <message>

<description_block>
```

**Message line**: imperative mood, ≤50 chars after the ticket prefix.
**Description block**: explain why and what; wrap at 72 chars; group changes
under headings when the diff spans multiple areas.

**Commit** — spawn the git-agent:

```
Tool: Agent
Parameters:
  prompt: |
    <paste the full contents of git-agent.md as instructions>

    INPUT CONTEXT:
    {
      "action": "commit",
      "message": "<full commit message>"
    }
  allowedTools:
    - Bash
```

After committing, collect the final commit message (first line + body) — you
will pass this to the PR agent in Phase 6.

---

## Phase 5: Review

Two automated review gates verify the implementation before creating the PR.
Both reviewers are read-only — they report findings, and the
implementation-agent applies fixes.

### 5a. Spec review

First, get the list of changed files:

```
Tool: Agent
Parameters:
  prompt: |
    <paste the full contents of git-agent.md as instructions>

    INPUT CONTEXT:
    {
      "action": "get-changed-files"
    }
  allowedTools:
    - Bash
```

Then spawn the spec-reviewer. Read agent instructions from
`.claude/skills/feature-workflow/agents/spec-reviewer.md`:

```
Tool: Agent
Parameters:
  prompt: |
    <paste the full contents of spec-reviewer.md as instructions>

    INPUT CONTEXT:
    {
      "specDir": "specs/<NNN>-<TICKET>-<slug>/",
      "service": "<service path>",
      "changedFiles": <changedFiles array from git-agent>,
      "area": "<BE | FE>"
    }
  allowedTools:
    - Read
    - Bash
```

**If `passed` is `false`** (Critical findings):

1. Spawn the implementation-agent with `fix-findings`:

```
Tool: Agent
Parameters:
  prompt: |
    <paste the full contents of implementation-agent.md as instructions>

    INPUT CONTEXT:
    {
      "action": "fix-findings",
      "findings": <Critical + Major findings from spec-reviewer>,
      "reviewerType": "spec",
      "service": "<service path>",
      "area": "<BE | FE>"
    }
  allowedTools:
    - Read
    - Edit
    - Write
    - Bash
```

2. Amend the commit:

```
Tool: Agent
Parameters:
  prompt: |
    <paste the full contents of git-agent.md as instructions>

    INPUT CONTEXT:
    {
      "action": "amend"
    }
  allowedTools:
    - Bash
```

3. Re-run the spec-reviewer to verify fixes resolved the Critical findings.

If still failing after one fix cycle, present the remaining findings to the
user and ask for guidance.

### 5b. Design review

Spawn the design-reviewer. Read agent instructions from
`.claude/skills/feature-workflow/agents/design-reviewer.md`:

```
Tool: Agent
Parameters:
  prompt: |
    <paste the full contents of design-reviewer.md as instructions>

    INPUT CONTEXT:
    {
      "service": "<service path>",
      "changedFiles": <changedFiles array from git-agent>,
      "area": "<BE | FE>"
    }
  allowedTools:
    - Read
    - Bash
```

**If `passed` is `false`** (Critical findings): follow the same
fix → amend → re-review loop as 5a, using `"reviewerType": "design"`.

---

## Phase 6: PR creation

### 6a. Validate and push

Spawn the git-agent to validate PR readiness:

```
Tool: Agent
Parameters:
  prompt: |
    <paste the full contents of git-agent.md as instructions>

    INPUT CONTEXT:
    {
      "action": "validate-pr-readiness"
    }
  allowedTools:
    - Bash
```

Then sync and push:

```
Tool: Agent
Parameters:
  prompt: |
    <paste the full contents of git-agent.md as instructions>

    INPUT CONTEXT:
    {
      "action": "sync-and-push",
      "branch": "<branch name>",
      "remoteStatus": "<remoteStatus from validate result>"
    }
  allowedTools:
    - Bash
```

### 6b. Create the PR

Delegate to the PR sub-agent. Read the agent instructions from
`.claude/skills/feature-workflow/agents/pr-agent.md`:

```
Tool: Agent
Parameters:
  prompt: |
    <paste the full contents of pr-agent.md as instructions>

    INPUT CONTEXT:
    {
      "ticketKey": "<projectKey>-XXXXX",
      "ticketUrl": "<urlBase>/browse/<projectKey>-XXXXX",
      "branch": "feature/<projectKey>-XXXXX/short-description",
      "commitMessage": "<first line of commit message>",
      "commitBody": "<commit message body>",
      "testSummary": "<X unit tests passed; live tested POST /api/v1/foo (200), GET /api/v1/bar (200)>",
      "diffStat": "<summary of changed files>"
    }
  allowedTools:
    - Bash
    - mcp__azure-devops__repo_create_pull_request
```

The agent will emit a JSON result block. Extract `prUrl` and tell the user.

---

## Phase 7: Finalize JIRA

After the PR is created, finalize the JIRA ticket with work logging, cost
analysis, and status transition. All operations are delegated to the
jira-agent.

Read the agent instructions from
`.claude/skills/feature-workflow/agents/jira-agent.md` once and reuse for
all spawns in this phase.

### 7a. Log implementation work

Calculate elapsed time since the checkpoint recorded after Phase 1d:

```bash
IMPL_END=$(date +%s)
IMPL_SECONDS=$((IMPL_END - CHECKPOINT))
```

Convert to JIRA time format (round to nearest 5 minutes). Then log it:

```
Tool: Agent
Parameters:
  prompt: |
    <paste the full contents of jira-agent.md as instructions>

    INPUT CONTEXT:
    {
      "action": "addWorklog",
      "ticketKey": "<ticketKey>",
      "timeSpent": "<implementation elapsed time in JIRA format>",
      "comment": "Implementation work"
    }
  allowedTools:
    - mcp__atlassian__addWorklogToJiraIssue
```

### 7b. Cost analysis comment

Build a per-phase/per-agent cost analysis and post it as a JIRA comment.

**Step 1:** Read the pricing reference:

```
Read: .claude/skills/feature-workflow/references/claude-pricing.md
```

**Step 2:** Collect workflow metadata:
- Which agents were spawned during this run
- How many checkpoints were completed
- How many spawns per agent type
- Whether context compaction occurred

**Step 3:** Ask the user for the actual session cost:

> "Please type `/cost` and share the total so I can include the actual
> figure in the JIRA comment."

Hold the actual cost value.

**Step 4:** Estimate per-agent costs using the agent profiles from the
pricing reference. For each agent spawn, calculate:

```
cost = (input_tokens × cache_write_rate + output_tokens × output_rate) / 1,000,000
```

Use the mid-range of each agent's profile. For the orchestrator, use the
blended input rate (30% cache-write + 70% cache-hit).

**Step 5:** Compose the JIRA comment using this template:

```markdown
## AI-Assisted Development — Cost Analysis

**Actual session cost:** $XX.XX (from `/cost`)

### Per-Phase / Per-Agent Breakdown (estimated)

| Phase | Agent | Model | Est. Input | Est. Output | Est. Cost |
|-------|-------|-------|-----------|-------------|-----------|
| 1-pre Ticket | jira-agent | Haiku 4.5 | 8K | 2K | $0.02 |
| 1a-d Clarify | Orchestrator | Sonnet 4.6 | 80K | 20K | $0.60 |
| 1b Spec | sdd-expert | Sonnet 4.6 | 30K | 15K | $0.34 |
| 1c Plan | architect | Sonnet 4.6 | 40K | 20K | $0.45 |
| 1d Worklog | jira-agent | Haiku 4.5 | 8K | 2K | $0.02 |
| 2 Branch | git-agent | Haiku 4.5 | 8K | 2K | $0.02 |
| 3 Baseline | impl-agent | Sonnet 4.6 | 30K | 10K | $0.26 |
| 3 CP 1 | impl-agent | Sonnet 4.6 | 150K | 50K | $1.31 |
| ... | ... | ... | ... | ... | ... |
| 4 Commit | git-agent (xN) | Haiku 4.5 | NK | NK | $X.XX |
| 5a Spec review | spec-reviewer | Sonnet 4.6 | 50K | 8K | $0.31 |
| 5b Design review | design-reviewer | Sonnet 4.6 | 50K | 8K | $0.31 |
| 6 PR | pr-agent + git | Sonnet+Haiku | 25K | 5K | $0.17 |
| 7 Finalize | jira-agent (x3) | Haiku 4.5 | 24K | 6K | $0.06 |
| Orchestrator (impl) | — | Sonnet 4.6 | 200K | 60K | $1.65 |
| **Total estimate** | | | | | **$X.XX** |

### Pricing Rates Used

| Model | Input (cache-write) | Cache Hit | Output |
|-------|-------------------|-----------|--------|
| Sonnet 4.6 | $3.75/MTok | $0.30/MTok | $15/MTok |
| Haiku 4.5 | $1.25/MTok | $0.10/MTok | $5/MTok |

> Per-agent estimates use cache-write rate for input (fresh context per spawn).
> Orchestrator uses blended rate (30% cache-write, 70% cache-hit).
> Delta between estimate and actual reflects context compaction, retries,
> and estimation error.
```

Fill in actual values from the run: number of checkpoints, agent spawns,
and the actual total from `/cost`. Use mid-range values from the agent
profiles in the pricing reference for the token estimates.

**Step 6:** Post the comment:

```
Tool: Agent
Parameters:
  prompt: |
    <paste the full contents of jira-agent.md as instructions>

    INPUT CONTEXT:
    {
      "action": "addComment",
      "ticketKey": "<ticketKey>",
      "commentBody": "<composed cost analysis comment>"
    }
  allowedTools:
    - mcp__atlassian__addCommentToJiraIssue
```

### 7c. Transition to "In Review"

```
Tool: Agent
Parameters:
  prompt: |
    <paste the full contents of jira-agent.md as instructions>

    INPUT CONTEXT:
    {
      "action": "transition",
      "ticketKey": "<ticketKey>",
      "targetStatus": "In Review"
    }
  allowedTools:
    - mcp__atlassian__getTransitionsForJiraIssue
    - mcp__atlassian__transitionJiraIssue
```

### Final report to user

After Phase 7 completes, tell the user:
- The PR URL
- The JIRA ticket URL (now "In Review")
- A brief summary of what was implemented
- Test results (from the test summary built in Phase 3)
- The actual session cost
- A reminder to request reviewers if needed

---

## Quick reference

| Phase | Who | Action | Gate |
|-------|-----|--------|------|
| 1-pre Ticket | **jira-agent** (Haiku) | Create or prepare ticket with AI labels | — |
| 1a Clarify | Main (Sonnet) | Ask targeted questions until fully understood | — |
| 1b Specify | **sdd-expert** (Sonnet) | Write BDD specs to `specs/<NNN>-PLAT-XXXXX-slug/` | Resolve openQuestions |
| 1c Plan | **architect** (Sonnet) | Write `execution-plan.md` with checkpoints and contracts | Acknowledge risks |
| 1d Review | Main (Sonnet) | Present spec + plan to user | **User confirms** ← only gate |
| 2 Branch | **git-agent** (Haiku) | `git checkout -b feature/<projectKey>-X/slug` | — |
| 3a Baseline + CP1 | **impl-agent** (Sonnet) ×2 | Compile+boot check ‖ first checkpoint (parallel) | Stop if baseline fails |
| 3b Checkpoints | **impl-agent** (Sonnet) | Remaining checkpoints sequentially | — |
| 4 Commit | **git-agent** (Haiku) | Squash → stage → commit | — |
| 5a Spec review | **spec-reviewer** (Sonnet) | Verify all BDD scenarios implemented + tested | Fix Critical findings |
| 5b Design review | **design-reviewer** (Sonnet) | Verify code quality against project rules | Fix Critical findings |
| 6 PR | **git-agent** (Haiku) + **pr-agent** (Sonnet) | Validate → sync → push → create PR | — |
| 7a Worklog | **jira-agent** (Haiku) | Log implementation time | — |
| 7b Cost | **jira-agent** (Haiku) | Post per-agent cost analysis comment | — |
| 7c Transition | **jira-agent** (Haiku) | Move ticket to "In Review" | — |

## What this is NOT

- Not for experiments or spikes — those just get coded, no ticket needed
- Not for quick fixes with no PR — commit directly without this workflow
- The ticket documents the **goal**, not the solution — implementation details
  belong in the commit message and PR description, written after the work

---

## Upgrade Path

Generated by claudboard-workflow on 2026-05-13 from template version v1.
To regenerate with updated templates, remove this directory and re-run `/claudboard-workflow`.
