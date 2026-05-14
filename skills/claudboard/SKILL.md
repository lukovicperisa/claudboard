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
  Also routes: "set up feature workflow", "install start-feature skill", "generate feature-workflow",
  "configure feature workflow for this repo" → claudboard-workflow.
  Also routes: "bootstrap workspace", "set up workspace meta-repo", "create workspace .claude repo",
  "share my .claude across the team", "make .claude versioned" → claudboard-workspace-init.
  Also routes: "join workspace", "link to workspace meta-repo", "bootstrap workspace on this machine",
  "clone workspace meta-repo", "connect to shared .claude" → claudboard-workspace-link.
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
- **`/claudboard-workflow`** — Generates a tailored `.claude/skills/feature-workflow/` skill into the target project from the analysis report. Requires `/generate` to have run first. Also triggered by: "set up feature workflow", "install start-feature skill", "generate feature-workflow", "configure feature workflow for this repo".
- **`/claudboard-workspace-init`** — Bootstrap a workspace meta-repo: creates a sibling git repo, migrates existing `.claude/` contents, and symlinks the workspace root's `.claude/` to the meta-repo. Run once per workspace from the workspace root. Also triggered by: "bootstrap workspace", "set up workspace meta-repo", "share my .claude across the team".
- **`/claudboard-workspace-link <url>`** — Teammate bootstrap: clones the workspace meta-repo and creates the symlink. Run after the first developer has run `/claudboard-workspace-init`. Also triggered by: "join workspace", "link to workspace meta-repo", "clone workspace meta-repo".

## Reference Files

Sub-skills load these shared references as needed:

| File | Used by | Purpose |
|------|---------|---------|
| `references/stack-detectors.md` | analyse, techdebt, refresh | Shared detection heuristics, infra signals, monorepo detection |
| `references/stack-detectors-java.md` | analyse, techdebt | Java/Kotlin Wide Scan patterns (7 categories) |
| `references/stack-detectors-typescript.md` | analyse, techdebt | TypeScript/JavaScript Wide Scan patterns (7 categories) |
| `references/stack-detectors-python.md` | analyse, techdebt | Python Wide Scan patterns (7 categories) |
| `references/stack-detectors-go.md` | analyse, techdebt | Go Wide Scan patterns (7 categories) |
| `references/stack-detectors-rust.md` | analyse, techdebt | Rust Wide Scan patterns (7 categories) |
| `references/stack-detectors-dotnet.md` | analyse, techdebt | .NET/C# Wide Scan patterns (7 categories) |
| `references/pattern-catalog.md` | analyse, techdebt | Architecture patterns + anti-patterns catalog |
| `references/quality-signals.md` | analyse, refresh | Quality scoring, rule depth, skill triggers |
| `references/claude-md-template.md` | generate | CLAUDE.md generation template |
| `references/rule-templates.md` | generate | Rule file templates per language |
| `references/skill-generation.md` | generate | Full-scope skill generation guide |

The techdebt skill also has its own references in `../claudboard-techdebt/references/`: code-smell-catalog, design-debt-patterns, perf-debt-patterns, arch-debt-patterns, severity-matrix, and report-template.
