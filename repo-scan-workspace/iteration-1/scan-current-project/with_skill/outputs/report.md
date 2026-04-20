## Repo scan: /Users/LUP1BG/Documents/BoschProjects/claude-repo-scan

**Stack:** Markdown · JSON · Claude Code skill/plugin project · no traditional build system
**Size:** ~29 files, ~22 dirs (excl. .git)

### Structure
```
claude-repo-scan/
├── CLAUDE.md                          # project instructions for Claude
├── skills/repo-scan/SKILL.md          # skill definition (the repo-scan skill prompt)
├── evals/evals.json                   # eval prompts + expected outputs
├── .claude/settings.local.json        # Claude Code permissions config
└── repo-scan-workspace/iteration-1/   # eval run workspace (scan-caveman-plugin, scan-current-project, scan-skill-creator)
```

### Dependencies (0)
No package.json, requirements.txt, go.mod, Cargo.toml, or other dependency files present. Pure markdown/JSON — no runtime dependencies.

### Issues
[WARN] No tests — no test/, tests/, spec/, or *.test.* files found
[WARN] No CI — no .github/workflows/, .gitlab-ci.yml, Jenkinsfile, .circleci/, or azure-pipelines.yml
[WARN] No README.md — missing top-level README
[WARN] No LICENSE — no LICENSE or LICENSE.md file
[WARN] No .gitignore — repo root has no .gitignore

### Summary
A Claude Code skill plugin project that defines a `repo-scan` skill — a markdown prompt file instructing Claude how to analyze repositories. The project contains the skill definition, eval prompts for testing the skill's behavior, and a workspace for storing eval run outputs. No runtime code, no dependencies, no CI or test infrastructure; the "tests" are Claude-evaluated evals rather than automated test suites.
