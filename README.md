# claudboard

A Claude Code plugin that deep-analyzes brownfield projects and generates production-ready `.claude/` onboarding artifacts — so Claude Code can work effectively on any existing codebase from the first prompt.

## What it does

Run `/claudboard` on any project and get:

- **`CLAUDE.md`** — Architecture overview, build/test/lint commands, critical rules, skill/rule index
- **`.claude/rules/*.md`** — Auto-loaded rules with `paths:` frontmatter, conventions extracted from actual code (not generic templates)
- **`.claude/skills/*/`** — Full-scope skills: each has SKILL.md (workflow orchestrator), `references/` (templates, annotated examples from your code), and `scripts/scaffold.sh` (boilerplate generator) — tailored to detected patterns, not generic stubs

The skill answers three questions about your project:
- **What** — what does it do, what value does it provide
- **How** — what architecture, patterns, and design decisions are in use
- **Why** — what constraints drove those decisions

It also identifies good patterns to preserve, anti-patterns to avoid, and tech debt to address.

## Installation

```bash
claude plugin install github:lukovicperisa/claudboard
```

Or add manually: clone this repo, then reference the `skills/claudboard/` directory.

## Usage

Onboarding is a two-step process. Run each step separately for best results.

```bash
# Step 1: Analyse the project (read-only)
/analyse
/analyse ~/projects/my-app

# Step 2: Generate artifacts from the analysis (recommend fresh session)
/generate
```

The `/analyse` command scans, detects patterns, and writes:
- **`.claudboard/catalog.json`** — the primary artifact consumed by `/generate` (structured JSON, versioned schema)
- **`.claude/reports/claudboard-analysis.md`** — a thin human-readable summary for review before generating

By default, `/analyse` runs a reference-service deep pass per detected stack — cheap enough for large monorepos. Pass `--audit` for full per-service analysis (Watch findings, quality scores, cross-service graphs written to `.claudboard/audits/<svc>.md`).

The `/generate` command reads `.claudboard/catalog.json` and creates `.claude/` artifacts. Best run in a fresh Claude Code session. If you have artifacts from a prior claudboard version (`.claude/reports/cloudboard-analysis.md` only), `/generate` auto-migrates to the catalog format on first run.

### Filesystem layout

```
<project>/
  .claudboard/         ← build state; not loaded by Claude Code at runtime
    catalog.json       ← primary artifact for /generate and /refresh
    audits/            ← per-service reports (--audit only)
      <svc>.md
  .claude/             ← runtime context (auto-loaded by Claude Code)
    reports/
      claudboard-analysis.md   ← thin summary, human review
    rules/, skills/, memories/ ← generated artifacts
  CLAUDE.md            ← generated project overview
```

`.claudboard/` is build state — consider adding it to `.gitignore` (or commit it to share the catalog across team members; see `catalog-format.md` for trade-offs).

Additional commands:

- **`/refresh`** — Delta updates for projects that already have `.claude/` artifacts
- **`/techdebt`** — Deep tech debt analysis with module-grouped, ticket-ready reports
- **`/claudboard-workflow`** — Generates a complete `.claude/skills/feature-workflow/` skill into any project (opt-in, run after `/generate`)
- **`/claudboard-workspace-init`** — Bootstrap a workspace meta-repo for multi-repo workspaces (run once by the first developer)
- **`/claudboard-workspace-link`** — Teammate bootstrap: clones the workspace meta-repo and wires up the symlink

## Migration from older claudboard

If you've previously run `/analyse` without the catalog architecture (older versions produced only `.claude/reports/claudboard-analysis.md`), no action is required. On your next `/generate` run, claudboard automatically:

1. Detects the missing `.claudboard/catalog.json`
2. Parses your existing legacy report(s) and synthesises a catalog
3. Writes `.claudboard/catalog.json` (log line confirms the migration)
4. Proceeds with normal generation

Your legacy report files are left in place — only the new catalog is written. Subsequent `/generate` runs use the catalog directly and skip migration.

If migration fails (incompatible older format), the error message names the offending file and instructs you to run `/analyse` for a fresh catalog.

## Lifecycle

### First run vs. re-run

- **First run** (`/analyse` → `/generate`): Full analysis. Generates artifacts from scratch.
- **Re-run** (`/refresh`): Delta mode. Compares current codebase against existing artifacts, identifies what's new, stale, or missing, and updates only what changed. Never regenerates from scratch.

### Stale rule detection

`/refresh` detects staleness by:
- Checking `generated_at` timestamp in the saved analysis report
- Running `git diff --name-only` since the last analysis to find changed areas
- Comparing Wide Scan results against existing rule `paths:` globs and skill triggers
- Flagging rules that reference renamed/deleted files, or miss newly added modules

### Removing artifacts

To remove all claudboard-generated artifacts:

```bash
rm -rf .claude/rules/ .claude/skills/ .claude/reports/
# Optionally remove CLAUDE.md if it was fully generated (not hand-written)
```

Claudboard never modifies files outside `.claude/` and project-root `CLAUDE.md`, so removal is safe and complete.

## Output example

After running on a Spring Boot project, claudboard generates:

```
.claude/
├── rules/
│   ├── java-conventions.md      # paths: **/*.java — naming, DI, error handling, logging
│   ├── testing-rules.md         # paths: src/test/**/*.java — Spock/JUnit patterns
│   └── infrastructure-context.md # paths: **/charts/**/*.yaml, **/Dockerfile*
├── skills/
│   ├── rest-controller/
│   │   ├── SKILL.md             # Full workflow for REST endpoints + DTOs
│   │   ├── references/
│   │   │   └── template-controller.java
│   │   └── scripts/
│   │       └── scaffold.sh      # Generates controller + DTOs
│   └── mongodb-persistence/
│       ├── SKILL.md             # DBEntity, Repository, Adapter, Listener
│       ├── references/
│       │   └── template-entity.java
│       └── scripts/
│           └── scaffold.sh
CLAUDE.md                        # Project overview, commands, architecture, critical rules
```

## Tested on

- **Java/Kotlin**: Spring Boot, Gradle/Maven, Spock/JUnit, Kafka, MongoDB
- **TypeScript/JavaScript**: React, Next.js, NestJS, Express, MCP servers
- **Python**: FastAPI, Django, Flask, Pydantic, MCP servers
- **Go**: Gin, Echo, gRPC
- **Rust**: Cargo workspaces
- **Infrastructure**: Helm, Kustomize, Pulumi, Terraform, Docker, Azure DevOps, GitHub Actions

Claudboard works on any codebase — these are stacks with dedicated detection heuristics and eval coverage. Other stacks get structure-based analysis without stack-specific pattern matching.

## Design principles

- **Merge, not replace** — if `.claude/` already exists, claudboard fills gaps only
- **Adaptive depth** — full rules for clean codebases, skeleton rules for messy ones
- **Real patterns** — rules contain actual conventions from your code, not generic advice
- **Full-scope skills** — generated skills have working scaffold scripts and real templates

## Quality guarantees

Every claudboard run upholds these contracts:

- **Traceability** — every rule cites at least one real file path from the scanned repo; every CLAUDE.md claim is traceable to a source file
- **Signal threshold** — no skill is generated for patterns appearing fewer than 3 times in the codebase
- **Output caps** — CLAUDE.md: 60-120 lines; rules: 30-120 lines (adaptive); skills: 80-250 lines
- **Token budget visibility** — the Phase 2 report includes estimated persistent context overhead so you can see the cost before committing
- **Pre-write summary** — a summary of what will be written is shown before file writes begin; interrupt with Esc to abort or adjust
- **Merge-only** — existing `.claude/` content is never overwritten, only gaps are filled

## Repository structure

- `skills/claudboard/` — Main skill (dispatcher) + shared reference files
- `skills/claudboard-analyse/` — Discovery & analysis (read-only)
- `skills/claudboard-generate/` — Artifact generation from analysis report
- `skills/claudboard-refresh/` — Delta updates for existing projects
- `skills/claudboard-techdebt/` — Deep tech debt analysis
- `skills/claudboard-workflow/` — Generates feature-workflow skill into target projects
- `skills/claudboard-workspace-init/` — Bootstrap workspace meta-repo + symlink
- `skills/claudboard-workspace-link/` — Teammate bootstrap: clone meta-repo + create symlink
- `openspec/` — OpenSpec change tracking for development workflow (specs for planned features)
- `evals/` — Evaluation test cases across diverse repo types

## Per-task cost reporting (optional)

Every `/analyse`, `/generate`, `/refresh`, and `/techdebt` run touches real API tokens. A `Stop` hook lets you see the dollar cost of each individual claudboard task at the moment it finishes — at zero extra API cost, since the hook reads the session JSONL that Claude Code already writes to disk.

**Expected cost ranges** (asymmetric tier: Opus orchestrator, Sonnet sub-agents):
- `/analyse` default — single-project: ≤$15; 19-service monorepo: ≤$150
- `/analyse --audit` — 19-service monorepo: ≤$250 (full per-service fan-out)
- `/generate` (from catalog) — ≤$25 on a 19-service monorepo

The `thin-analyse-catalog-primary` change (2026-06-01) documents the measured baseline ($417 all-Opus) and the architectural rationale for the catalog-as-primary approach.

To enable, add the following block to your project's `.claude/settings.local.json` (or the global `~/.claude/settings.json`). Replace `<abs-path>` with the absolute path to this plugin's scripts directory.

```json
{
  "hooks": {
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "<abs-path>/skills/claudboard/scripts/stop-hook.sh"
          }
        ]
      }
    ]
  }
}
```

**Example output** (appears in the Claude Code transcript after the task ends):

```
Cost for /analyse: $8.17 (Opus 4.7, 25 calls, 28K out)
```

When the task pauses waiting for your input (e.g. topology-confirm question), the line is suffixed with `(in progress)`:

```
Cost for /analyse: $1.43 (Opus 4.7, 8 calls, 6K out) (in progress)
```

**Details:**
- **Gated triggers** — the hook fires on every Stop event but only emits a cost line when the most recent user message begins with `/analyse`, `/generate`, `/refresh`, or `/techdebt`. Conversational turns are ignored.
- **Slice semantics** — the cost covers the slice from the matching trigger prompt to now, so running `/analyse` then `/generate` in the same session produces two independent cost lines, not an accumulating total.
- **Zero API tokens** — the hook runs bash + jq against the on-disk JSONL, no model is involved.
- **Known limitation** — the gate is a heuristic: if you type `/analyse` in chat without invoking the skill, the next Stop event will emit a (near-zero) cost line. This is harmless.

The underlying script (`skills/claudboard/scripts/compute-cost.sh`) can also be invoked directly for ad-hoc slicing:

```bash
compute-cost.sh --since 2026-05-31T13:06:00Z --task analyse /path/to/session.jsonl
compute-cost.sh --format json /path/to/session.jsonl
compute-cost.sh --help
```

## License

MIT
