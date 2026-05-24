## Why

`/claudboard-workflow` takes ~60 minutes on Sonnet 4.6 (standard context) for a 13-repo workspace like MEAS — with 5 compaction cycles consuming most of that time. The root causes are: (1) 11 verbatim files are Read+Write'd through the context window despite needing zero rendering, and (2) per-repo analysis reports are duplicated from the workspace reports directory into each service repo's `.claude/reports/`, adding ~4,400 lines of redundant disk content and confusing the report lookup chain across generate/refresh/workflow skills.

Demo and team onboarding sessions feel slow. While this is largely a one-time operation, the perception cost is real.

## What Changes

- **Verbatim file batch-copy:** Phase 6 of `claudboard-workflow` gains a new step 6a that copies all 11 non-templated files via `bash cp` in a single tool call, instead of 11 Read+Write cycles through the conversation context. Estimated context savings: ~4,000 lines (2,050 lines × 2 for read result + write input). Phase 6 tool calls drop from ~19 to ~9.
- **Missing file fix:** `scripts/jira-add-labels.sh` was present in the template directory and in generated output, but missing from the Phase 6b file mapping table, Phase 5 confirmation gate file tree, and Phase 7 completion report. Now listed in all three.
- **Workspace report single-source-of-truth:** In workspace mode, the workspace reports directory (`<workspace>/.claude/reports/`) is the canonical location for per-repo analysis reports. Per-repo `.claude/reports/` copies are no longer created. Three consuming skills updated:
  - `claudboard-analyse`: Sub-agent prompt explicitly forbids writing to `<repo>/.claude/reports/`; constraint section updated.
  - `claudboard-generate`: Phase 1 restructured into 1a (mode detection) and 1b (report loading) with workspace-aware lookup.
  - `claudboard-refresh`: Phase 2d and Phase 6 gain workspace-mode paths.

## Capabilities

### Modified Capabilities
- `feature-workflow-generation`: Phase 6 restructured — verbatim files batch-copied via bash (6a), template rendering unchanged (6b), file mapping split into templated vs verbatim tables (6c). `jira-add-labels.sh` added to all manifests.
- `workspace-analysis`: Sub-agents no longer write per-repo report copies. Single source of truth enforced.
- `artifact-generation`: Workspace-mode report lookup reads from workspace reports directory, not per-repo.
- `artifact-refresh`: Workspace-mode report lookup and save both target workspace reports directory.

## Impact

- **Files changed:** `skills/claudboard-workflow/SKILL.md`, `skills/claudboard-analyse/SKILL.md`, `skills/claudboard-generate/SKILL.md`, `skills/claudboard-refresh/SKILL.md`
- **Backward compatibility:** Existing per-repo report copies (from prior runs) are harmless — they're just no longer created or consulted in workspace mode. No migration needed.
- **Estimated speed improvement:** 15-20% reduction in `/claudboard-workflow` wall-clock time (1-2 fewer compaction cycles on Sonnet standard context).
- **Out of scope:** Script-based template rendering (would save ~50-60% but adds maintenance surface — a separate change if needed).
