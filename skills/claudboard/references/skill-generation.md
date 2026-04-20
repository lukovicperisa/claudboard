# Skill Generation Guide

Use this when generating full-scope `.claude/skills/<name>/` directories. Generated skills must be production-ready, not stubs.

---

## Full-Scope Skill Structure

Every generated skill should have:

```
.claude/skills/<name>/
├── SKILL.md                    # Required — orchestrator (100-250 lines)
├── references/                 # When: code templates, examples, checklists needed
│   ├── template.<ext>          # Actual template files from detected patterns
│   ├── example-<thing>.md      # Annotated example from the actual codebase
│   └── checklist.md            # Step checklist for complex workflows
└── scripts/                    # When: scaffold or automation is possible
    └── scaffold.sh             # Generates boilerplate matching detected patterns
```

**SKILL.md always required.** `references/` required for skills with code templates. `scripts/` for skills where scaffolding saves significant time.

---

## SKILL.md Structure

```markdown
---
name: <kebab-case-name>
description: >
  [What the skill does — 1 sentence].
  [When to use it — explicit trigger phrases, contexts, conditions].
  Use this skill whenever the user [asks/says/wants to] [specific phrases].
  Also triggers when [related contexts].
---

# [Skill Title]

## Architecture

[Diagram showing the file structure this skill creates/modifies. Use detected project structure.]

\`\`\`
<aggregate>/
├── [file-1]         ← [role of this file]
├── [file-2]/
│   └── [file-3]     ← [role]
\`\`\`

## Quick Start

[If scaffold script exists:]
\`\`\`bash
bash .claude/skills/<name>/scripts/scaffold.sh [args]
# Example:
# bash .claude/skills/<name>/scripts/scaffold.sh [concrete example from detected patterns]
\`\`\`

[Or if no scaffold:]
Follow the step-by-step below.

## Step-by-step

### 1. [First component]

[Explanation of why this component exists and what it does in this project's context.]

\`\`\`[language]
[Real code example extracted from the actual codebase, or a template that matches detected conventions]
\`\`\`

Key points:
- [Important rule 1 detected from codebase patterns]
- [Important rule 2]

### 2. [Second component]

[Continue for each component...]

## [Common Patterns] / [Conventions]

[Patterns detected from the codebase that are specific to this skill — e.g., how this project names things, what annotations/decorators to use, what NOT to do based on anti-patterns found]

## [Testing]

[How tests should be written for this type of component, based on detected test patterns]

\`\`\`[language]
[Test example matching detected test framework and conventions]
\`\`\`
```

---

## Description Field Guidelines

The `description` in YAML frontmatter is the auto-trigger mechanism. Make it **pushy** — it should trigger whenever the user is doing this type of work, even without using the exact skill name.

**Good description pattern:**
```yaml
description: >
  Create or modify a [Thing] in [Project]. Covers [Component A], [Component B], [Component C].
  Use this skill whenever the user asks to create a new [thing], add [thing] for [purpose],
  set up [thing], or implement [thing]. Also triggers when the user says
  '[phrase 1]', '[phrase 2]', 'I need to [action]', or 'add [X] to [Y]'.
```

**Trigger phrases to include** (adapt to context):
- Explicit: "create a", "add a", "implement a", "build a", "set up a"
- Implicit: "I need to store X", "add endpoint for X", "make X work", "hook up X"
- Domain: use actual domain terms from the codebase (e.g., "employee", "invitation", "subscription")

---

## Scaffold Script Guide

Write `scripts/scaffold.sh` when:
- The skill creates 3+ boilerplate files
- Files follow a predictable naming pattern
- The boilerplate is non-trivial (more than a few lines)

**Script template:**
```bash
#!/bin/bash
# scaffold.sh — generates [Skill] boilerplate for [Project]
# Usage: bash .claude/skills/<name>/scripts/scaffold.sh <arg1> <arg2>
# Example: bash .claude/skills/<name>/scripts/scaffold.sh services/my-service MyEntity

set -e

SERVICE_ROOT="$1"
ENTITY_NAME="$2"
# Add more args as needed

if [ -z "$SERVICE_ROOT" ] || [ -z "$ENTITY_NAME" ]; then
  echo "Usage: $0 <service-root> <entity-name>"
  echo "Example: $0 services/my-service MyEntity"
  exit 1
fi

# Detect package base from existing source files
PACKAGE_BASE=$(find "$SERVICE_ROOT/src/main/java" -name "*.java" -maxdepth 5 | head -1 | sed 's|.*/src/main/java/||' | sed 's|/[^/]*$||' | tr '/' '.')
if [ -z "$PACKAGE_BASE" ]; then
  echo "Error: Could not detect package base in $SERVICE_ROOT"
  exit 1
fi

echo "Scaffolding $ENTITY_NAME in $SERVICE_ROOT (package: $PACKAGE_BASE)"

# Create directories
mkdir -p "$SERVICE_ROOT/src/main/java/${PACKAGE_BASE//./\/}/$ENTITY_NAME_LOWER"

# Generate each file using heredoc
cat > "$OUTPUT_PATH" << EOF
[File content with variables substituted]
EOF

echo "✓ Created [file]"
echo ""
echo "Next steps:"
echo "1. Fill in TODO markers in generated files"
echo "2. [Any other required manual steps]"
```

**Critical:** The script must use actual detected values (package structure, naming conventions, imports) from the codebase — not hardcoded generic boilerplate. Read the codebase first, then generate the scaffold using detected patterns.

---

## References Directory Guide

Create `references/` when the skill benefits from having templates or examples the agent can read during execution.

### `references/template.<ext>`

An actual boilerplate file with `[PLACEHOLDER]` markers. The agent fills these in when creating new instances.

Example for a Spring Boot REST controller:
```java
package [PACKAGE_BASE].[AGGREGATE_LOWER].controller;

import [PACKAGE_BASE].[AGGREGATE_LOWER].dto.[AGGREGATE]Request;
import [PACKAGE_BASE].[AGGREGATE_LOWER].dto.[AGGREGATE]Response;
// ... imports matching detected import style

@RestController
@RequestMapping("/api/v1/[aggregate-plural-kebab]")
@RequiredArgsConstructor
@Slf4j
public class [AGGREGATE]Controller {

    private final [AGGREGATE]Service [aggregateLower]Service;

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public [AGGREGATE]Response create(@Valid @RequestBody [AGGREGATE]Request request) {
        log.info("[AGGREGATE] creation triggered");
        return [aggregateLower]Service.create(request);
    }
    // ... skeleton methods
}
```

### `references/example-<thing>.md`

An annotated example pulled from the actual codebase. Shows exactly how this pattern is implemented in THIS project.

```markdown
# Example: [Thing] from [actual service name]

Source: `[actual file path]`

This shows how [Entity] implements the [pattern] in [project name].

\`\`\`java
[Actual code from the file, not generic example]
\`\`\`

**Key points:**
- [Why this specific line is important]
- [Project-specific convention to note]
```

### `references/checklist.md`

Step checklist for complex multi-step workflows:

```markdown
# [Skill] Checklist

- [ ] [Step 1]
- [ ] [Step 2]
- [ ] [Step 3 — with sub-steps:]
  - [ ] [Sub-step A]
  - [ ] [Sub-step B]
- [ ] Tests written and passing
- [ ] [Any project-specific completion criteria]
```

---

## Skill Generation by Stack

### Spring Boot / Java Skills to Generate

**`rest-controller`** — when `@RestController` classes detected
- SKILL.md: controller layer, DTO, exception handler, validation
- `references/template-controller.java`, `references/template-dto.java`
- `scripts/scaffold.sh` — creates controller + request/response DTOs

**`mongodb-persistence`** — when Spring Data MongoDB detected
- SKILL.md: DBEntity, Repository interface, port, adapter, listener
- `references/` with template for each of the 5 files
- `scripts/scaffold.sh` — creates all 5 files

**`use-case`** / **`domain-service`** — when service/use-case pattern detected
- SKILL.md: use case class, command/result objects, orchestration
- `references/template-use-case.java`

**`kafka-consumer`** — when `@KafkaListener` detected
- SKILL.md: listener, Avro schema, retry config, DLT
- `references/template-listener.java`, `references/template-schema.avsc`

### React / TypeScript Skills to Generate

**`component`** — when React components detected
- SKILL.md: component file, CSS Module, test, story (if Storybook detected)
- `references/template-component.tsx`, `references/template-component.module.css`
- `scripts/scaffold.sh` — creates component dir with all files

**`api-hook`** — when React Query detected
- SKILL.md: useQuery hook, useMutation hook, API client function
- `references/template-hook.ts`

**`form`** — when react-hook-form detected
- SKILL.md: form component, validation schema (Zod if detected), submit handler

### Python Skills to Generate

**`api-endpoint`** — when FastAPI routes detected
- SKILL.md: route function, Pydantic model, dependency injection
- `references/template-endpoint.py`

**`mcp-tool`** — when MCP server detected
- SKILL.md: tool function, input schema, handler
- `references/template-tool.py`

---

## Adaptive Skill Depth

**Clean codebase (consistent patterns):**
- Full SKILL.md (200+ lines with code examples from actual repo)
- Real references extracted from codebase
- Working scaffold script

**Transitional codebase (mixed patterns):**
- SKILL.md (100-150 lines) documenting the intended/predominant pattern
- Reference templates using the cleaner pattern as target
- Note inconsistencies: "Currently some [components] use [pattern A], aiming for [pattern B]"

**Messy codebase (inconsistent):**
- SKILL.md (80-100 lines) with skeleton and TODO sections
- Ask user in Phase 2: "Found [X] and [Y] approaches for [concern] — which should I document as the standard?"
- Generate references once user clarifies
