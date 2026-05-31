## ADDED Requirements

### Requirement: Cost-tick contract reference present in generated workflow
The generated feature-workflow SHALL contain a `references/cost-tick.md` file that defines the per-phase cost tick contract: the bash invocation template, the expected output format, the `SESSION_COST_LOG` append rule, and the slot vocabulary for `PHASE_N_START` and `<phase-label>`. The generated `SKILL.md` SHALL reference this file from each of phases 1-6 via a one-line shorthand at the phase's end.

The file SHALL be rendered from a template (`feature-workflow.template/references/cost-tick.md`) and SHALL be present in every generated workflow regardless of capability flags — it is a baseline, not optional.

#### Scenario: cost-tick.md present in single-repo generation
- **WHEN** the generator writes a single-repo feature-workflow
- **THEN** the generated tree contains `<workflow>/references/cost-tick.md`

#### Scenario: cost-tick.md present in workspace generation
- **WHEN** the generator writes a workspace-mode feature-workflow
- **THEN** the generated tree contains `<meta-repo>/.claude/skills/feature-workflow/references/cost-tick.md`

#### Scenario: SKILL.md references cost-tick at each phase end
- **WHEN** the generated `SKILL.md` is inspected for phases 1 through 6
- **THEN** each phase's instructions include a one-line shorthand at the end that names `references/cost-tick.md` and passes a `label=<phase-name>` and `since=PHASE_N_START` parameter

## MODIFIED Requirements

### Requirement: File generation contract
The system SHALL write generated files only under the resolved feature-workflow skill directory:
- In single-repo mode: `<project>/.claude/skills/feature-workflow/`
- In workspace mode: `<workspace>/.claude/skills/feature-workflow/` (a symlink resolving to `<meta-repo>/.claude/skills/feature-workflow/`)

The system SHALL NOT modify any files outside this directory in either mode.

The generated tree SHALL contain:
- `SKILL.md` (rendered from template; multi-repo variant when `WORKSPACE_MODE` is true)
- `config.json` (synthesized from inputs; workspace shape with `repos: { ... }` map when `WORKSPACE_MODE` is true)
- `agents/jira-agent.md` (verbatim copy if `TRACKER_JIRA`; otherwise NOT written)
- `agents/tr-agent.md` (verbatim copy if `TRACKER_TR`; otherwise NOT written)
- `agents/pr-agent-ado.md` (verbatim copy if `REPO_ADO`; otherwise NOT written)
- `agents/pr-agent-github.md` (verbatim copy if `REPO_GITHUB`; otherwise NOT written)
- `agents/git-agent.md`, `agents/architect-agent.md`, `agents/implementation-agent.md`, `agents/sdd-expert-agent.md`, `agents/design-reviewer.md`, `agents/spec-reviewer.md` (rendered from templates; multi-repo variants when `WORKSPACE_MODE` is true; each accepts a `repo` argument in workspace mode)
- `scripts/lib.sh`, `scripts/prepare-commit.sh`, `scripts/prepare-pr.sh`, `scripts/prepare-squash.sh` (verbatim copies; in workspace mode they SHALL accept a `--repo` flag or `REPO_PATH` env var)
- `scripts/jira-add-labels.sh` (verbatim copy if `TRACKER_JIRA`; otherwise NOT written)
- `scripts/load-repo-context.sh` (only generated when `WORKSPACE_MODE` is true)
- `scripts/compute-cost.sh` (verbatim copy of `skills/claudboard/scripts/compute-cost.sh`; always present)
- `references/claude-pricing.md` (verbatim copy)
- `references/pricing.md` (verbatim copy of `skills/claudboard/references/pricing.md`; always present — sourced exclusively by `compute-cost.sh` for cost computation)
- `references/cost-tick.md` (rendered from template; always present)
- `references/phase7-cost-analysis.md` (rendered from template; always present)

Mutually-exclusive tracker and repo agents SHALL never both be present: the generator SHALL refuse to write both `jira-agent.md` and `tr-agent.md` in the same output (likewise for the two PR agents).

#### Scenario: Existing skill present in single-repo mode
- **WHEN** `.claude/skills/feature-workflow/` already exists in the target project
- **THEN** the system SHALL refuse to overwrite, print "feature-workflow skill already exists. Upgrade flow is not available in v1; remove the existing skill manually if you want to regenerate.", and stop

#### Scenario: Existing skill present in workspace mode
- **WHEN** the meta-repo's `.claude/skills/feature-workflow/` already exists
- **THEN** the system SHALL refuse to overwrite, print "feature-workflow skill already exists at <path>. Upgrade flow is not available in v1; remove the existing skill manually if you want to regenerate.", and stop

#### Scenario: Path outside target ignored
- **WHEN** rendering would write to any path outside the resolved feature-workflow skill directory
- **THEN** the system SHALL refuse the write and report a path-violation error

#### Scenario: Workspace mode writes to per-repo locations are blocked
- **WHEN** in workspace mode, rendering would write to any path under `<workspace>/<repo>/.claude/` (i.e., into a service repo's `.claude/`)
- **THEN** the system SHALL refuse the write and report a path-violation error; per-repo `feature-workflow/` skills are explicitly not generated in workspace mode

#### Scenario: Mutually-exclusive tracker agents
- **WHEN** the resolved capability flags would cause both `jira-agent.md` and `tr-agent.md` to be written
- **THEN** the system SHALL halt before writing any files and report a "mutually-exclusive tracker flags both true" error

#### Scenario: Mutually-exclusive repo agents
- **WHEN** the resolved capability flags would cause both `pr-agent-ado.md` and `pr-agent-github.md` to be written
- **THEN** the system SHALL halt before writing any files and report a "mutually-exclusive repo flags both true" error

#### Scenario: compute-cost.sh and pricing.md bundled in every generation
- **WHEN** the generator writes any feature-workflow (single-repo or workspace, any capability-flag combination)
- **THEN** the generated tree contains `scripts/compute-cost.sh` and `references/pricing.md` as verbatim copies of the source files in `skills/claudboard/scripts/` and `skills/claudboard/references/`

#### Scenario: Bundled script is executable
- **WHEN** `scripts/compute-cost.sh` is written to the generated workflow
- **THEN** the file has executable permission (mode includes `+x`) so the orchestrator can invoke it directly

### Requirement: Phase 7b cost comment — JIRA variant
The generated feature-workflow SKILL.md SHALL instruct the orchestrator to compute the actual session cost autonomously via the bundled `compute-cost.sh` script and post a measured per-phase cost breakdown comment to the JIRA ticket. The orchestrator SHALL NOT prompt the user for `/cost` output or any cost-related input.

Phase 7b (JIRA) steps:
1. Read `references/pricing.md` (for documentation context; computation already uses it via the script)
2. Run the bundled `compute-cost.sh` once over the full session to obtain `ACTUAL_TOTAL`
3. Read the `SESSION_COST_LOG` memo to obtain the per-phase measured costs (P1_COST..P6_COST)
4. Compute `ORCH_COST = max(0, ACTUAL_TOTAL − Σ(P1..P6))` and `RECONCILIATION = ACTUAL_TOTAL − Σ(P1..P6)`
5. Compose the comment per the `automated-cost-computation` capability requirements (measured per-phase rows; reconciliation annotation in footnote if `|RECONCILIATION| > $0.01`) and post via jira-agent; proceed to Phase 7c

The orchestrator SHALL NOT execute inline jq or inline Python for cost computation in Phase 7b.

#### Scenario: JIRA cost comment posted without user interaction
- **WHEN** the feature-workflow reaches Phase 7b (JIRA variant)
- **THEN** the orchestrator runs the bundled script, reads the SESSION_COST_LOG, composes the comment, and posts it without asking the user anything

#### Scenario: JIRA comment shows measured per-phase costs
- **WHEN** the cost comment is posted
- **THEN** the per-phase bullets show measured values from SESSION_COST_LOG (not SPAWN_LOG × profile estimates) and the footnote reflects measured-source semantics

#### Scenario: Phase 7b does not embed inline cost computation
- **WHEN** Phase 7b composes the comment
- **THEN** all token-to-dollar arithmetic is performed by the bundled `compute-cost.sh`; the SKILL.md SHALL NOT contain a `python3 - <<EOF` block or an inline `jq` pipeline for cost computation

### Requirement: Phase 7b cost comment — T&R variant
The generated feature-workflow SKILL.md SHALL instruct the orchestrator to apply the same autonomous cost computation to the T&R Phase 7b summary comment. The `$XX.XX (from /cost)` placeholder SHALL be replaced with the bundled-script's computed `ACTUAL_TOTAL`. The orchestrator SHALL NOT prompt the user for `/cost` output and SHALL NOT execute inline jq or inline Python for cost computation.

Phase 7b (T&R) steps follow the same five-step pattern as the JIRA variant; only the posting tool and the optional time-data prefix differ.

#### Scenario: T&R cost comment posted without user interaction
- **WHEN** the feature-workflow reaches Phase 7b (T&R variant)
- **THEN** the orchestrator runs the bundled script, reads the SESSION_COST_LOG, composes the comment with the time-data prefix, and posts it without any user prompt

#### Scenario: T&R comment cost section shows measured per-phase costs
- **WHEN** the T&R summary comment is composed
- **THEN** the Cost Analysis section displays `ACTUAL_TOTAL` from the bundled script and measured per-phase bullets from SESSION_COST_LOG

### Requirement: Spawn-count tracking across phases
The generated feature-workflow SKILL.md SHALL instruct the orchestrator to record a `SPAWN_LOG` memo at the end of each phase, a `SESSION_COST_LOG` memo updated by each phase's cost tick, `SESSION_JSONL_PATH` at Phase 1 kickoff, and `PHASE_N_START` timestamps at each phase's start.

SPAWN_LOG format (unchanged):
```
SPAWN_LOG:
  phase1: <agent>×<n>, ...
  phase2: <agent>×<n>, ...
  ...
```

SESSION_COST_LOG format:
```
SESSION_COST_LOG:
  phase1: $X.XX │ session $Y.YY
  phase2: $X.XX │ session $Y.YY
  ...
```

`SESSION_JSONL_PATH` = `~/.claude/projects/$(pwd | sed 's|/|-|g')/$CLAUDE_CODE_SESSION_ID.jsonl`, recorded before any directory change. Under the Claude Agent SDK, the orchestrator SHALL fall back to `$CLAUDE_SESSION_JSONL` if set, then to the computed path.

`PHASE_N_START` SHALL be recorded as an ISO 8601 UTC timestamp at the entry of each phase 1-6 (phase 1's timestamp recorded alongside `SESSION_JSONL_PATH` at workflow kickoff; subsequent phases' timestamps recorded immediately after the prior phase's tick).

#### Scenario: SPAWN_LOG available at Phase 7b
- **WHEN** the workflow has run through Phase 6
- **THEN** the orchestrator holds a SPAWN_LOG covering all spawned agents per phase

#### Scenario: SESSION_COST_LOG available at Phase 7b
- **WHEN** the workflow has run through Phase 6 with ticks emitted at each phase end
- **THEN** the orchestrator holds a SESSION_COST_LOG with six entries (phase1..phase6) readable without scanning tool history

#### Scenario: SESSION_JSONL_PATH captured at kickoff
- **WHEN** Phase 1 begins
- **THEN** the orchestrator records `SESSION_JSONL_PATH` using `$CLAUDE_CODE_SESSION_ID` and the current working directory (or `$CLAUDE_SESSION_JSONL` under the SDK)

#### Scenario: PHASE_N_START recorded for each phase
- **WHEN** phase N (N ∈ {1..6}) begins
- **THEN** the orchestrator records `PHASE_N_START` as an ISO 8601 UTC timestamp before any sub-agent is spawned for that phase
