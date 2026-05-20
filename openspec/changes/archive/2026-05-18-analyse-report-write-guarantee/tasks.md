## 1. Rewrite Phase 3 in `skills/claudboard-analyse/SKILL.md`

- [x] 1.1 Replace the current "After presenting the analysis, save reports" paragraph with an explicit numbered sequence: (1) create directory, (2) write file, (3) confirm to user, (4) ask about generation
- [x] 1.2 Add explicit Write-tool mandate: "Use the Write tool to create this file. Displaying the analysis to the user does NOT substitute for writing the file."
- [x] 1.3 Add failure handling: if the Write tool call fails, report the error and stop — do not proceed to the generate prompt
- [x] 1.4 Verify monorepo Phase 3 path: same numbered sequence applies; global report + per-service reports all written before the user prompt
- [x] 1.5 Verify workspace Phase 3 path: sub-agent verification step precedes workspace summary write; workspace summary write precedes user prompt

## 2. End-to-end validation

- [ ] 2.1 Run `/analyse` on a single-repo project; confirm `<repo>/.claude/reports/claudboard-analysis.md` exists after the session
- [ ] 2.2 Run `/analyse` on a monorepo; confirm global + per-service reports all exist
- [ ] 2.3 Run `/analyse` from MEAS workspace root; confirm workspace summary + per-repo reports all exist (unblocks `workspace-analyse-output` tasks 6.1-6.8)
- [ ] 2.4 Verify that when the user says "generate now", the report file still exists on disk (not only held in context)
- [ ] 2.5 Verify that when the user says "defer", the report file exists and a fresh `/generate` session can load it
