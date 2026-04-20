# claudboard

A Claude Code plugin that deep-analyzes brownfield projects and generates production-ready `.claude/` onboarding artifacts — so Claude Code can work effectively on any existing codebase from the first prompt.

## What it does

Run `/claudboard` on any project and get:

- **`CLAUDE.md`** — Architecture overview, build/test/lint commands, critical rules, skill/rule index
- **`.claude/rules/*.md`** — Auto-loaded rules with `paths:` frontmatter, conventions extracted from actual code (not generic templates)
- **`.claude/skills/*/`** — Full-scope skills with SKILL.md, `references/` (templates, examples), and `scripts/scaffold.sh` — tailored to detected patterns

The skill answers three questions about your project:
- **What** — what does it do, what value does it provide
- **How** — what architecture, patterns, and design decisions are in use
- **Why** — what constraints drove those decisions

It also identifies good patterns to preserve, anti-patterns to avoid, and tech debt to address.

## Installation

```bash
claude plugin install github:<your-username>/claudboard
```

Or add manually: clone this repo, then reference the `skills/claudboard/` directory.

## Usage

```bash
# Analyze current directory
/claudboard

# Analyze a specific project
/claudboard ~/projects/my-app
/claudboard /path/to/existing/repo
```

The skill runs in three phases:

1. **Discovery** — reads config files, samples source code, inventories existing `.claude/` (read-only)
2. **Analysis report** — presents WHAT/HOW/WHY/CONCERNS + proposes artifacts for your approval
3. **Generation** — writes to `.claude/` after you confirm

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

## Supported stacks

- **Java/Kotlin**: Spring Boot, Gradle/Maven, Spock/JUnit, Kafka, MongoDB
- **TypeScript/JavaScript**: React, Next.js, NestJS, Express, MCP servers
- **Python**: FastAPI, Django, Flask, Pydantic, MCP servers
- **Go**: Gin, Echo, gRPC
- **Rust**: Cargo workspaces
- **Infrastructure**: Helm, Kustomize, Pulumi, Terraform, Docker, Azure DevOps, GitHub Actions

## Design principles

- **Merge, not replace** — if `.claude/` already exists, claudboard fills gaps only
- **Adaptive depth** — full rules for clean codebases, skeleton rules for messy ones
- **Real patterns** — rules contain actual conventions from your code, not generic advice
- **Full-scope skills** — generated skills have working scaffold scripts and real templates

## License

MIT
