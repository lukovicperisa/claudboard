## Why

`/claudboard-analyse` ends with a Phase 3 instruction to "save reports to `.claude/reports/`" — but the phrasing is advisory enough that the model sometimes interprets it as "I've shown the content" rather than "invoke Write tool to create the file." The `.claude/reports/` directory creation is also only instructed, not enforced before the write attempt.

This is a silent collapse point: the entire downstream pipeline — `/generate`, `/claudboard-workflow`, workspace graph construction, per-repo analysis reuse — depends on the report file existing on disk. When it's missing, none of that works, and the failure is invisible (no error; the agent just moves on to the generate prompt).

The fix is two instructions in Phase 3: create the directory unconditionally, then write the file unconditionally, both BEFORE the agent asks the user anything about generation.

## What Changes

- **MODIFIED: `skills/claudboard-analyse/SKILL.md` Phase 3** — rewrite the save instruction as an imperative, sequenced, tool-invocation mandate:
  1. Create `.claude/reports/` if it does not exist (mkdir, idempotent)
  2. Write the report file using the Write tool
  3. Only then ask the user about generating
  
  Applies to all three modes: single-project, monorepo, workspace (where the workspace summary is the orchestrator's responsibility and sub-agent reports are verified to exist before this step).

## Capabilities

### Modified Capabilities
- `analyse-report-write`: The Phase 3 save step is made unambiguously imperative — directory creation first, Write tool invocation second, user prompt third. No mode-specific deviation.

## Impact

- **MODIFIED skills**: `skills/claudboard-analyse/SKILL.md` — Phase 3 only
- **NO impact** on analysis phases, report content, or downstream tools — this is purely a sequencing and instruction-strength fix
- **Blocks**: `workspace-analyse-output` tasks 6.1-6.8 (MEAS end-to-end validation) — those tests assumed the write was working; this change is a prerequisite for reliable validation results
