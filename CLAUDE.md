# CLAUDE.md — claudboard

This file provides guidance to Claude Code when working in this repository.

## Project Overview

**claudboard** is a Claude Code plugin/skill that deep-analyzes brownfield projects and generates production-ready `.claude/` onboarding artifacts: CLAUDE.md, rules (with `paths:` frontmatter), and full-scope skills (SKILL.md + references/ + scripts/). Think of it as an autopilot for project onboarding.

## Skill Anatomy

```
skills/
├── claudboard/
│   ├── SKILL.md                      # Dispatcher — routes to /analyse, /generate, /refresh, /techdebt
│   └── references/                   # Shared reference files loaded by sub-skills
│       ├── stack-detectors.md        # Detection heuristics per language/framework
│       ├── pattern-catalog.md        # Architecture patterns + anti-patterns catalog
│       ├── quality-signals.md        # Quality scoring + adaptive rule depth guide
│       ├── claude-md-template.md     # CLAUDE.md generation template
│       ├── rule-templates.md         # Rule file templates per language
│       └── skill-generation.md       # Full-scope skill generation guide
├── claudboard-analyse/SKILL.md       # Discovery & analysis (read-only, saves report)
├── claudboard-generate/SKILL.md      # Artifact generation from analysis report
├── claudboard-refresh/SKILL.md       # Delta updates for existing projects
└── claudboard-techdebt/SKILL.md      # Deep tech debt analysis
```

## Development Workflow

- Edit sub-skill SKILL.md files and reference files → test via Skill tool → iterate
- Use `skill-creator` to run evaluations: `/skill-creator`
- Reference files are loaded on-demand — keep them focused and comprehensive
- Evals target different repo types: Spring Boot monorepo, TypeScript service, Python agent

## Key Design Decisions

- **Two-step workflow**: `/analyse` (read-only, saves report) → `/generate` (writes artifacts, best in fresh session)
- **Adaptive rule depth**: Full rules for clean codebases, skeleton for messy, ask user when in doubt
- **Merge, not replace**: When `.claude/` exists, fill gaps only — never overwrite
- **Full-scope skills**: Every generated skill has SKILL.md + references/ + scripts/ — no stubs
- **Gold standard**: craftsphere.cloud/.claude/ — that's what the output should look like

## Testing / Verification

Test against real projects:
- `craftsphere.cloud` — complex polyglot monorepo (Java + React + Helm + Azure DevOps)
- `azure-devops-mcp` — TypeScript MCP server
- `worca-cc` — Python multi-agent orchestration

Compare generated CLAUDE.md against craftsphere's hand-crafted one. Generated rules should have correct `paths:` frontmatter and conventions from actual code, not generic templates.
