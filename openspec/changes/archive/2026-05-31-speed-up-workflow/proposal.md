## Why

`/claudboard-workflow` is the second-slowest skill in the suite after `/analyse`, and its bottleneck is structurally the same: tool-call round-trips and unconditional reference loads dominate the per-run cost, not the actual template rendering. Static measurement of this repo shows the workflow generator SKILL.md is 852 lines (~9.5K tokens) loaded every run, the four reference catalogs add ~1,831 lines (~21K tokens) of mostly-irrelevant content, and the detection phases (Phase 1d MCP detection, Phase 2a git remote parsing, Phase 2b sibling-repo scan) issue 5-10 separate tool calls applying keyword/regex rules in prose that a single bash script could execute deterministically. The cost shape is fixable without changing what `/claudboard-workflow` generates or how it prompts the user — by consolidating detection work into one bash invocation, gating prompt-reference loads on the resolved-config gaps, and trimming the always-loaded SKILL.md.

The companion `slim-feature-workflow-orchestrator` and `slim-feature-workflow-agents` changes target the **generated artifact** (the `feature-workflow/` skill written into target projects). This change targets the **generator** (the `claudboard-workflow` skill that does the writing). The two are independent.

## What Changes

- **Add `skills/claudboard-workflow/scripts/detect.sh`** that runs the detection work currently spread across Phase 1d (MCP detection, 6 steps), Phase 2a (git remote parsing), and Phase 2b (sibling-repo `config.json` scan) as a single bash invocation. Emits a structured JSON detection report that the model reads in one tool call instead of 5-10 individual file reads + regex matches. Outputs versioned schema (`schema_version` field) so the script and SKILL.md can evolve safely together.
- **Gate prompt-reference loading on detection signals.** Skip `references/tracker-config-prompts.md` when both `TRACKER_JIRA` and `TRACKER_TR` are false AND no tracker fields are unresolved. Skip `references/repo-config-prompts.md` symmetrically. Document the gates in the workflow SKILL.md as machine-readable conditionals tied to the detect.sh output.
- **Shrink workflow SKILL.md** by moving the inline MCP keyword tables (Phase 1d Step 2), git remote URL regex tables (Phase 2a), and sibling-inheritance field lists (Phase 2b) out of the SKILL.md. The keyword and regex tables become data inside `detect.sh` (where they execute); the sibling field allowlist moves to a small reference file. Target: cut workflow SKILL.md from 852 → ~500 lines (~9.5K → ~5.5K tokens).
- **No change to generated output, capability flags, substitution variables, prompts shown to the user, or the existing-skill guard (Phase 1c).** Backwards compatible with all downstream consumers — the generated `feature-workflow/` skill is byte-identical to the pre-change generator's output given the same inputs.
- **Out of scope (explicitly):** render automation (capability-block resolution, template substitution remain model-driven); `/generate` perf (already lean, separate decision); the in-flight `slim-feature-workflow-*` changes (different surface — generated artifact, not generator); workspace-mode parallel fan-out audit.

## Capabilities

### New Capabilities

- `workflow-generator-performance`: Performance discipline for `/claudboard-workflow` — detection-script consolidation contract, conditional reference loading gated on detection signals, and SKILL.md size budget. Defines the invariants that keep `/claudboard-workflow` fast and cheap across single-repo, monorepo, and workspace modes.

### Modified Capabilities

<!-- No existing capability requirements change. The behavior detected by mcp-detection, tracker-backends, repo-backends, feature-workflow-generation, etc. all remain identical — only the execution path that produces those detections changes. -->

## Impact

- **Affected files (workflow skill):**
  - `skills/claudboard-workflow/SKILL.md` — modified (trim, add detect.sh invocation, document conditional ref loads)
  - `skills/claudboard-workflow/scripts/detect.sh` — new
  - `skills/claudboard-workflow/scripts/schema/detect-v1.md` — new (schema doc for the JSON contract)
  - `skills/claudboard-workflow/references/sibling-inheritance.md` — new, small (~30 lines) — the field allowlist moved out of SKILL.md
- **Affected behavior:** none externally observable. Generated `feature-workflow/` skills are byte-identical for the same inputs. User prompts during Phase 2c are unchanged.
- **Downstream consumers (unchanged):** generated `feature-workflow/` skills behave identically; `/start-feature` flows in target projects are unaffected.
- **Workspace mode:** the workflow generator's own workspace path (writing the skill into a meta-repo's `.claude/skills/`) is unchanged; only the detection step inside the generator gets faster.
- **Risk:** detection-script output schema becomes a contract. If the script and SKILL.md drift, workflow generation fails opaquely. Mitigation: script emits a `schema_version` field and SKILL.md asserts on it (same mechanism as speed-up-analyse).
- **Out of scope:** render-time automation (`render.sh`), the in-flight `slim-feature-workflow-*` changes (different surface), `/generate` perf (separate decision).
