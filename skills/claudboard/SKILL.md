---
name: claudboard
description: >
  Deep-analyzes an existing project or repository and bootstraps Claude Code's understanding
  by generating production-ready .claude/ artifacts: CLAUDE.md, rules with paths: frontmatter,
  full-scope skills (with references/ and scripts/), and memories. Goes beyond surface scanning
  to detect architecture patterns, coding conventions, testing strategies, CI/CD pipelines,
  infrastructure, good patterns, anti-patterns, and tech debt.
  Use this skill whenever the user says /claudboard, "onboard this project", "bootstrap Claude
  for this repo", "set up Claude Code for this project", "analyze this codebase", "generate
  rules for this project", "create CLAUDE.md", "scan this repo", "understand this project",
  "help me onboard to this codebase", or asks for a project health check, architecture audit,
  or code quality review. Also triggers on "what patterns does this repo use", "generate coding
  rules from this codebase", or when starting work on an unfamiliar or brownfield project.
---

# Claudboard — Project Onboarding Agent

Analyzes a repository and generates Claude Code artifacts that let you work on it immediately: CLAUDE.md, rules, and full-scope skills tailored to the project's actual patterns.

## Workflow

Onboarding is a two-phase process. Run each phase separately for best results.

### Phase 1: Analyse

```
/analyse [path]
```

Scans the project (read-only), detects patterns, quality signals, and anti-patterns, then presents an analysis report with proposed artifacts. Saves the report to `.claude/reports/claudboard-analysis.md`.

At the end of analysis, you'll be asked whether to continue with generation or do it later.

### Phase 2: Generate

```
/generate
```

Reads the saved analysis report and generates production-ready `.claude/` artifacts: CLAUDE.md, rules (with `paths:` frontmatter), and full-scope skills (SKILL.md + references/ + scripts/).

**Recommended:** Run `/generate` in a fresh Claude Code session. The analysis phase fills context with discovery data that isn't needed during generation — a clean session gives better output.

### Additional commands

- **`/refresh`** — Delta updates for projects that already have `.claude/` artifacts. Identifies what's new, stale, or missing and updates only what changed.
- **`/techdebt`** — Deep tech debt analysis. Produces module-grouped, ticket-ready reports with severity, effort, and fix suggestions.

## Reference Files

Sub-skills load these shared references as needed:

| File | Used by | Purpose |
|------|---------|---------|
| `references/stack-detectors.md` | analyse, techdebt | Detection heuristics per language/framework |
| `references/pattern-catalog.md` | analyse, techdebt | Architecture patterns + anti-patterns catalog |
| `references/quality-signals.md` | analyse, refresh | Quality scoring, rule depth, skill triggers |
| `references/claude-md-template.md` | generate | CLAUDE.md generation template |
| `references/rule-templates.md` | generate | Rule file templates per language |
| `references/skill-generation.md` | generate | Full-scope skill generation guide |

The techdebt skill also has its own references in `../claudboard-techdebt/references/`: code-smell-catalog, design-debt-patterns, perf-debt-patterns, arch-debt-patterns, severity-matrix, and report-template.
