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

## Where to run /analyse

```
single repo  → run inside the repo
monorepo     → run at the repo root
workspace    → run at the workspace directory
               (the parent folder that holds ONLY the related repos
               — not a generic ~/Projects or ~/code folder)
```

If you run from the wrong level, re-run from the right one. The catalog regenerates in seconds.

## Phase 0: First-run permission setup

**Before dispatching to any sub-skill**, check whether the recommended permissions are already installed:

1. Read `.claude/settings.json` (if it exists).
2. Look for the key `_claudboard_permissions_version` in the JSON:
   - **Present (any value):** Skip the prompt — permissions were already handled. Proceed to sub-skill dispatch.
   - **Absent:** Show the one-shot offer below, then proceed.

**One-shot offer (shown only when marker is absent):**

> Add claudboard's recommended permissions to `.claude/settings.json`? This eliminates ~20 prompts per analysis run. [y/n]

**YES branch:**
1. Read `references/recommended-permissions.json` to get the `permissions.allow` array.
2. Read `.claude/settings.json` (or start with `{}` if missing).
3. Merge: take the existing `permissions.allow` array (if any) and union it with the bundle's array — deduplicate, preserve all existing entries, never delete anything.
4. Write back `.claude/settings.json` with the merged `permissions.allow` and the marker `"_claudboard_permissions_version": "1"`.
5. Print: `✓ Recommended permissions added to .claude/settings.json`
6. MUST NOT modify any key other than `permissions.allow` and `_claudboard_permissions_version`.

**NO branch:**
1. Write `"_claudboard_permissions_version": "1-declined"` into `.claude/settings.json` (stamp only — do not touch any other key).
2. Print the bundle contents as a copy-paste fallback:
   > To add these manually later, copy the `permissions.allow` entries from `skills/claudboard/references/recommended-permissions.json` into `.claude/settings.json`. To re-trigger this offer, delete the `_claudboard_permissions_version` key and re-run any claudboard command.

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
| `references/workflow-signals.md` | analyse | Dispatcher for cross-service edge schema + sub-catalog pointer table |
| `references/edges/sync-rpc.md` | analyse | REST, gRPC, tRPC detection (Java + TS) |
| `references/edges/messaging.md` | analyse | Kafka, AMQP, JMS, SNS/SQS, Solace, Azure Service Bus detection |
| `references/edges/streaming.md` | analyse | WebSocket, SSE, RSocket detection |
| `references/edges/graphql.md` | analyse | GraphQL client + server detection |
| `references/patterns/architectural.md` | analyse | Saga, CQRS, outbox, BFF, circuit breaker, schema registry detection |
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

## Per-task cost reporting (opt-in)

See the **"Per-task cost reporting"** section in `README.md` for the opt-in Stop hook that emits a cost line after every `/analyse`, `/generate`, `/refresh`, or `/techdebt` run. The hook uses `scripts/compute-cost.sh` and `scripts/stop-hook.sh` and costs $0 in API tokens.
