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
│       ├── workflow-signals.md       # Dispatcher + schema for cross-service edge & pattern detection
│       ├── edges/                    # Per-family transport detection sub-catalogs
│       │   ├── sync-rpc.md           # REST, gRPC, tRPC, GraphQL-over-HTTP clients & servers
│       │   ├── messaging.md          # Kafka, AMQP, JMS, SNS/SQS, Solace, Azure Service Bus, etc.
│       │   ├── streaming.md          # WebSocket, SSE, RSocket
│       │   └── graphql.md            # GraphQL (schema-first and code-first, clients and servers)
│       ├── patterns/
│       │   └── architectural.md      # Saga, CQRS, outbox, BFF, circuit breaker, schema registry, etc.
│       ├── claude-md-template.md     # CLAUDE.md generation template
│       ├── rule-templates.md         # Rule file templates per language
│       └── skill-generation.md       # Full-scope skill generation guide
├── claudboard-analyse/
│   ├── SKILL.md                      # Discovery & analysis (read-only, saves report)
│   └── scripts/
│       ├── discover.sh               # Runs Phase 1b/1c/1g in one bash invocation; emits JSON v1
│       ├── schema/discover-v1.md     # v1 JSON schema: fields, semantics, schema-bump procedure
│       └── lang/                     # Per-language grep packs (sourced by discover.sh)
│           ├── _common.sh            # Shared: file count, language detect, ref_load_signals
│           ├── java.sh               # Java/Kotlin triggers, anti-patterns, conventions
│           ├── typescript.sh         # TypeScript/JavaScript triggers, anti-patterns
│           ├── python.sh             # Python triggers, anti-patterns
│           ├── go.sh                 # Go triggers, anti-patterns
│           ├── rust.sh               # Rust triggers, anti-patterns
│           └── dotnet.sh             # .NET/C# triggers, anti-patterns
├── claudboard-generate/SKILL.md      # Artifact generation from analysis report
├── claudboard-refresh/SKILL.md       # Delta updates for existing projects
├── claudboard-techdebt/SKILL.md      # Deep tech debt analysis
├── claudboard-workspace-init/SKILL.md  # Bootstrap workspace meta-repo + symlink (run once per workspace)
├── claudboard-workspace-link/SKILL.md  # Teammate bootstrap: clone meta-repo + create symlink
└── claudboard-workflow/
    ├── SKILL.md                      # Orchestrator — generates feature-workflow/ into target project
    └── references/
        ├── feature-workflow.template/ # Template tree (SKILL.md, agents, scripts, config)
        │   ├── references/
        │   │   ├── agent-preamble.md            # Shared sub-agent preamble ({{INCLUDE}}'d into all agents)
        │   │   ├── agent-context-loading.md     # Shared context-loading snippet ({{INCLUDE}}'d into coding agents)
        │   │   ├── reviewer-protocol.md         # Shared reviewer scaffolding ({{INCLUDE}}'d into reviewer agents)
        │   │   ├── ticket-description-template.md  # Verbatim — copied to generated skill's references/
        │   │   ├── claude-pricing.md            # Verbatim — copied to generated skill's references/
        │   │   ├── pricing.md                   # Verbatim copy of claudboard/references/pricing.md — cost computation source of truth
        │   │   ├── cost-tick.md                 # Per-phase cost tick contract: bash invocation, output format, SESSION_COST_LOG rule
        │   │   └── phase7-cost-analysis.md      # Phase 7b: log-read + reconciliation (replaces inline Python)
        │   ├── scripts/
        │   │   └── compute-cost.sh              # Verbatim copy of claudboard/scripts/compute-cost.sh — bundled for self-contained workflows
        │   └── agents/
        │       └── *.md.template           # All agents (jira, tr, pr-ado, pr-github, architect, git, impl, etc.)
        ├── block-catalog.md          # v1 capability flags: 4 MCP backends + all other flags
        ├── substitution-catalog.md   # v1 {{VAR}} tokens: source, fallback, example
        ├── tracker-config-prompts.md # Prompt text for Jira (TRACKER_JIRA) and T&R (TRACKER_TR) fields
        └── repo-config-prompts.md    # Prompt text for ADO (REPO_ADO) and GitHub (REPO_GITHUB) fields
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

## Generated feature-workflow

`/claudboard-workflow` generates a complete `.claude/skills/feature-workflow/` skill into any target project. This is a separate opt-in step from `/generate` — it requires the project to already have `CLAUDE.md` and `.claude/rules/` (the context heavy agents lean on).

**Single-repo / monorepo mode** (default): generates `feature-workflow/` into the repo's own `.claude/skills/`.

**Workspace mode** (when `workspace: true` in the analysis report): generates the multi-repo-aware skill into the workspace meta-repo's `.claude/skills/`. Requires the workspace meta-repo to be bootstrapped first via `/claudboard-workspace-init`. Per-repo `feature-workflow/` skills (if any pre-exist) are NOT auto-deleted — they are listed in the completion report with the manual removal command.

**Relationship to hand-edited copies:** The Bosch repos (craftsphere, MEAS repos) currently have hand-edited `feature-workflow/` skills. Those remain untouched — `/claudboard-refresh` skips `feature-workflow/` directories entirely. The generated skill is templated from those hand-edited copies, parameterized by claudboard analysis.

**Autonomy lever and synthesis phase (v1):** Every generated `feature-workflow` includes a clarification autonomy prompt at workflow entry (four levels: `autopilot` / `balanced` / `guided` / `manual`) and a `### 1-syn. Stated synthesis` phase that fires before Clarify. The default autonomy level is set in `config.json` (`clarify.defaultAutonomy`, default `balanced`) and is resolved at generation time from `{{CLARIFY_AUTONOMY_DEFAULT}}` in the template.

**Upgrade path caveat:** v1 has no upgrade path. If you need to regenerate — including to pick up the live per-phase cost ticks — remove the directory manually and re-run `/claudboard-workflow`. This applies to both single-repo and workspace-mode generated skills.

**Template source of truth:** `skills/claudboard-workflow/references/feature-workflow.template/` — fixing a bug here benefits all projects on their next regeneration.

**Detection contract:** `skills/claudboard-workflow/scripts/detect.sh` is the canonical detection script. It emits a JSON blob (schema v1 — see `scripts/schema/detect-v1.md`) covering MCP backends, git remote, and sibling repos. The orchestrator SKILL.md runs this script in Phase 1d and consumes the JSON; fallback prose paths handle environments where the script is unavailable.

**Template slimming (slim-feature-workflow-orchestrator change):** The template was restructured to state the agent-spawn contract, gate=mcp lifecycle signals, Phase 7 cost analysis, Phase 1-pre structure, and clarification rubric each exactly once, with per-call sites using a shorthand notation. No behavior change — the orchestrator drives the same workflow; the generated `SKILL.md` is ~26% smaller than the pre-change baseline. Projects regenerated after this change get the slim version; existing generated projects keep their verbose version until they re-run `/claudboard-workflow`.

## Workspace meta-repo concept

For multi-repo workspaces (a non-git parent directory containing N independent service repos), the workspace root cannot hold a git-tracked `.claude/`. The solution is a **workspace meta-repo** — a child git repo nested inside the workspace root:

```
meas/                                       # workspace root — NOT a git repo
├── .claude → ./meas.workspace/.claude      # symlink (single-segment relative path)
├── meas.workspace/                         # child git repo (shared, versioned)
│   ├── .claude/
│   │   ├── rules/          # cross-cutting team rules
│   │   ├── reports/        # claudboard analysis reports (per-repo + workspace summary)
│   │   ├── skills/feature-workflow/  # generated by /claudboard-workflow
│   │   └── changes/        # per-feature specs and plans
│   ├── setup.sh            # idempotent symlink bootstrap
│   └── README.md
├── datahandler/            # service repo (has its own .git/)
├── common-dto/             # service repo (has its own .git/)
└── ...
```

The meta-repo lives **inside** the workspace root (not alongside it). This means `setup.sh`'s `WORKSPACE_ROOT="$(dirname "$SCRIPT_DIR")"` resolves correctly, and the symlink target is a single-segment relative path (`./meas.workspace/.claude` — no `..` traversal).

**Bootstrap flow:**
1. First developer runs `/claudboard-workspace-init` from the workspace root to create `<workspace>/<name>/` as the meta-repo, set up the symlink, and migrate existing `.claude/` contents.
2. Teammates run `/claudboard-workspace-link <remote-url>` to clone the meta-repo as a child of their workspace root and run `setup.sh` to create the symlink.
3. Per-repo `.claude/` directories remain untouched — they hold repo-local rules, memories, and skills.

**v3+ layout note:** v3+ uses the child layout described above. Earlier bootstraps (pre-v3) used a sibling layout (`../meas.workspace/`). If you have a stale sibling-layout symlink, both `/claudboard-workspace-init` and `/claudboard-workspace-link` will detect it and refuse with a manual-removal message.

**Symlink convention:** The symlink uses a relative path so the workspace is portable across different clone locations.

## Testing / Verification

Test against real projects:
- `craftsphere.cloud` — complex polyglot monorepo (Java + React + Helm + Azure DevOps)
- `azure-devops-mcp` — TypeScript MCP server
- `worca-cc` — Python multi-agent orchestration

Compare generated CLAUDE.md against craftsphere's hand-crafted one. Generated rules should have correct `paths:` frontmatter and conventions from actual code, not generic templates.
