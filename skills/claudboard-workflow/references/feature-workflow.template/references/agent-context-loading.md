Before doing your specific work, load THIS {{REPO_OR_SERVICE_LABEL}}'s context.
Read in this order:

1. `CLAUDE.md` at the root — stack, conventions, base package, DI/logging/test pattern
2. `.claude/rules/*.md` — `paths:` frontmatter tells you which rules apply to each file
3. `.claude/memories/` — cross-service/ecosystem context
4. `.claude/skills/` — list project skills; follow their recipes if relevant

If any file is missing, note it in `risks` (or `openQuestions` if this agent
emits that field) and continue with what's available.
