# Substitution Catalog — v1 Variables

All 18 substitution variables used in feature-workflow templates. For each
variable, this catalog documents the source field in the analysis report, fallback
behavior when the field is missing, and an example of a resolved value.

Template syntax: `{{VARIABLE_NAME}}` — exact case-sensitive match.

---

## {{PROJECT_NAME}}

**Token:** `{{PROJECT_NAME}}`

**Source field in analysis report:** Frontmatter `repo` field — take the basename
of the absolute path. Example: if `repo: /home/dev/craftsphere`, the value is
`craftsphere`.

**Fallback when unresolvable:** Attempt to read from the `name` field in
`package.json`, `artifactId` in `pom.xml`, or the current working directory
name. If none resolves, use `[TODO: PROJECT_NAME]`.

**Example resolved value:** `craftsphere`

**Used in:** `SKILL.md.template` (session header, commit message format),
`config.json.template` (optional display field), agent preambles.

---

## {{REPO_NAME}}

**Token:** `{{REPO_NAME}}`

**Source field in analysis report:** Same as `PROJECT_NAME` — frontmatter `repo`
field basename. In single-repo mode, `REPO_NAME` and `PROJECT_NAME` resolve to
the same value. In workspace mode, `REPO_NAME` is the current service's directory
name while `PROJECT_NAME` is the workspace/project name.

**Fallback when unresolvable:** Current working directory basename. If that is
also unavailable, `[TODO: REPO_NAME]`.

**Example resolved value:** `order-service`

**Used in:** Git branch pattern construction, ADO PR target repo context in
agent prompts.

---

## {{STACK_NAME}}

**Token:** `{{STACK_NAME}}`

**Source field in analysis report:** "How (design & patterns)" section →
Architecture bullet. Extract the pattern name from the first architecture bullet,
e.g., from "Architecture: Layered (Controller → Service → Repository)" extract
"Java/Spring Boot" or the primary stack label from the "Stack & Versions"
section.

**Fallback when unresolvable:** "How" section → Build bullet for a stack signal
(e.g., `./gradlew` → "Java/Gradle"). If still unresolvable, `[TODO: STACK_NAME]`.

**Example resolved value:** `Java/Spring Boot`

**Used in:** `SKILL.md.template` (session context line), agent preambles,
`{{STACK_REMINDERS}}` rendering.

---

## {{TEST_FRAMEWORK}}

**Token:** `{{TEST_FRAMEWORK}}`

**Source field in analysis report:** "Testing" quality assessment section —
extract the detected framework name (e.g., "JUnit 5 + Mockito", "Jest",
"pytest").

**Fallback when unresolvable:** Scan build files for testing library dependencies.
If none detected, `[TODO: TEST_FRAMEWORK]`.

**Example resolved value:** `JUnit 5 + Mockito`

**Used in:** `agents/implementation-agent.md.template` (test-writing instructions),
`SKILL.md.template` (implementation checklist).

---

## {{BASE_PACKAGE}}

**Token:** `{{BASE_PACKAGE}}`

**Source field in analysis report:** Stack details section or Wide Scan pattern
inventory — look for the root Java/Kotlin package (e.g., from `grep -r 'package
' src/main/java | head -1` pattern noted in the scan). Also detectable from
`@SpringBootApplication` class package declaration.

**Fallback when unresolvable:** Parse the primary source directory structure:
`src/main/java/{base_package_path}` — convert path separators to dots. If no
Java source found, `[TODO: BASE_PACKAGE]`.

**Example resolved value:** `com.bosch.craftsphere`

**Used in:** `agents/implementation-agent.md.template` (new class placement
guidance), `agents/architect-agent.md.template` (package structure examples).

---

## {{BUILD_CMD}}

**Token:** `{{BUILD_CMD}}`

**Source field in analysis report:** "How (design & patterns)" → Build bullet.
Extract the build command, e.g., `./gradlew build` or `mvn package`.

**Fallback when unresolvable:** Detect from presence of `gradlew` (→ `./gradlew
build`) or `mvnw` (→ `./mvnw package`) or `Makefile` (→ `make build`). If none,
`[TODO: BUILD_CMD]`.

**Example resolved value:** `./gradlew build`

**Used in:** `SKILL.md.template` (implementation checklist — "build must pass
before PR"), agent implementation instructions.

---

## {{TEST_CMD}}

**Token:** `{{TEST_CMD}}`

**Source field in analysis report:** Build commands table in the "How" section,
or the Testing quality assessment section. Look for the test execution command.

**Fallback when unresolvable:** Derive from `BUILD_CMD` — `./gradlew test`,
`./mvnw test`, `npm test`, `pytest`. If none, `[TODO: TEST_CMD]`.

**Example resolved value:** `./gradlew test`

**Used in:** `SKILL.md.template` (implementation checklist), `agents/implementation-agent.md.template`.

---

## {{LINT_CMD}}

**Token:** `{{LINT_CMD}}`

**Source field in analysis report:** CI/CD section (look for lint/checkstyle
steps in the pipeline) or build commands table.

**Fallback when unresolvable:** Detect from CI pipeline file — grep for
`checkstyle`, `eslint`, `flake8`, `ktlint` tasks. If none detected, empty string
(variable resolves to empty, lint step block is not shown).

**Example resolved value:** `./gradlew checkstyleMain`

**Used in:** `SKILL.md.template` (implementation checklist — optional lint step).

---

## {{TICKET_PREFIX}}

**Token:** `{{TICKET_PREFIX}}`

**Source field in analysis report:** Workflow Signals subsection →
`ticket_prefix` field (set during analyse phase by scanning last 50 commits and
last 20 branch names for consistent `[A-Z]+-[0-9]+` prefix).

**Fallback when unresolvable:** Prompt user during Phase 2 config gathering:
"What is your Jira project key? (e.g., PLAT, MEAS, ORDER)". If user stubs, use
`[TODO: TICKET_PREFIX]`.

**Example resolved value:** `PLAT`

**Used in:** `SKILL.md.template` (branch naming examples, commit message
examples), `config.json.template` (`git.ticketRegex` pattern).

---

## {{WORKSPACE_NAME}}

**Token:** `{{WORKSPACE_NAME}}`

**Source field in analysis report:** Report frontmatter workspace identifier, or
the parent directory name if `WORKSPACE_MODE = true`. For single-repo mode, this
variable is only referenced inside `<!-- IF WORKSPACE_MODE -->` blocks and
therefore irrelevant when WORKSPACE_MODE is false.

**Fallback when unresolvable:** Use the parent directory basename. If still
unavailable, `[TODO: WORKSPACE_NAME]`.

**Example resolved value:** `craftsphere-workspace`

**Used in:** `SKILL.md.template` inside `<!-- IF WORKSPACE_MODE -->` blocks,
`agents/architect-agent.md.template` ecosystem context.

---

## {{REPO_COUNT}}

**Token:** `{{REPO_COUNT}}`

**Source field in analysis report:** Monorepo topology table / workspace service
list — count the number of service repos detected.

**Fallback when unresolvable:** `[TODO: REPO_COUNT]` (only appears inside
WORKSPACE_MODE blocks, so this only matters when WORKSPACE_MODE=true and the
count is genuinely unknown).

**Example resolved value:** `4`

**Used in:** `SKILL.md.template` inside `<!-- IF WORKSPACE_MODE -->` blocks
(e.g., "This workspace contains 4 services").

---

## {{REPO_LIST_BULLETS}}

**Token:** `{{REPO_LIST_BULLETS}}`

**Source field in analysis report:** Monorepo topology table / workspace service
list. Render each detected service as a Markdown bullet:
```
- order-service (Java/Spring Boot)
- user-service (Java/Spring Boot)
- frontend (React/TypeScript)
```

**Fallback when unresolvable:** Single bullet `- [TODO: REPO_LIST_BULLETS]`.

**Example resolved value:**
```
- order-service (Java/Spring Boot)
- user-service (Java/Spring Boot)
- frontend (React/TypeScript)
- shared-core (Java library)
```

**Used in:** `agents/architect-agent.md.template` inside `<!-- IF WORKSPACE_MODE
-->` blocks (ecosystem overview section).

---

## {{EDGE_TYPES_JOINED}}

**Token:** `{{EDGE_TYPES_JOINED}}`

**Source field in analysis report:** Workflow Signals subsection →
`cross_service_edges` list. Extract the unique protocol types from the edge list
and join them with ", ".

**Fallback when unresolvable:** `REST` (most common default). If no Workflow
Signals at all, `[TODO: EDGE_TYPES_JOINED]`.

**Example resolved value:** `REST, Kafka`

**Used in:** `agents/architect-agent.md.template` inside `<!-- IF
CROSS_SERVICE_EDGES -->` blocks (e.g., "Cross-service communication uses: REST,
Kafka").

---

## {{SHARED_LIB_NAME}}

**Token:** `{{SHARED_LIB_NAME}}`

**Source field in analysis report:** Workflow Signals subsection →
`shared_libs` list → first entry with `consumer_count ≥ 2` → `name` field.

**Fallback when unresolvable:** `[TODO: SHARED_LIB_NAME]` (only appears inside
SHARED_LIB blocks, so this only matters when SHARED_LIB=true).

**Example resolved value:** `shared-core`

**Used in:** `agents/architect-agent.md.template` and `agents/implementation-agent.md.template`
inside `<!-- IF SHARED_LIB -->` blocks.

---

## {{SHARED_LIB_CONSUMER_COUNT}}

**Token:** `{{SHARED_LIB_CONSUMER_COUNT}}`

**Source field in analysis report:** Workflow Signals subsection →
`shared_libs` list → first entry with `consumer_count ≥ 2` → `consumer_count`
field.

**Fallback when unresolvable:** `[TODO: SHARED_LIB_CONSUMER_COUNT]`.

**Example resolved value:** `3`

**Used in:** `agents/architect-agent.md.template` inside `<!-- IF SHARED_LIB -->`
blocks (e.g., "shared-core is used by 3 services — breaking changes need a
coordinated release").

---

## {{ECOSYSTEM_MEMORY_NAME}}

**Token:** `{{ECOSYSTEM_MEMORY_NAME}}`

**Source field in analysis report:** Filesystem check — if
`.claude/memories/ecosystem.md` exists, resolve to `ecosystem.md`. If a
differently-named ecosystem memory file exists, use its filename.

**Fallback when unresolvable:** Empty string (the referencing block should be
inside `<!-- IF MEMORIES_PRESENT -->` and therefore already guarded).

**Example resolved value:** `ecosystem.md`

**Used in:** `agents/architect-agent.md.template` and `agents/implementation-agent.md.template`
inside `<!-- IF MEMORIES_PRESENT -->` blocks (e.g., "Load
`.claude/memories/ecosystem.md` before starting design").

---

## {{REPO_OR_SERVICE_LABEL}}

**Token:** `{{REPO_OR_SERVICE_LABEL}}`

**Source field in analysis report:** Derived from `WORKSPACE_MODE` flag:
- `WORKSPACE_MODE = true` → resolves to `service`
- `WORKSPACE_MODE = false` → resolves to `repo`

**Fallback when unresolvable:** `repo`.

**Example resolved value:** `service` (workspace mode) or `repo` (single-repo)

**Used in:** `SKILL.md.template` (generic labels like "this {{REPO_OR_SERVICE_LABEL}}"),
agent preambles for natural-language framing.

---

## {{STACK_REMINDERS}}

**Token:** `{{STACK_REMINDERS}}`

**Source field in analysis report:** "Preserve:" bullets in the Quality Assessment
section of the analysis report. These are the positive patterns the analyst
detected and wants to preserve (e.g., "Constructor injection — consistent
throughout", "Slf4j + structured logging — used in all service classes").

Render each "Preserve" bullet as a Markdown list item:
```
- Constructor injection — consistent throughout
- Slf4j + structured logging — used in all service classes
- @Transactional on service methods only — never on repository layer
```

**Fallback when unresolvable:** Empty string (the variable is used in a section
that gracefully handles an empty value — no bullets rendered).

**Example resolved value:**
```
- Constructor injection — consistent throughout
- Slf4j + structured logging — used in all service classes
- @Transactional at service layer — never repository layer
- Custom @LogExecutionTime annotation on all public service methods
```

**Used in:** `agents/architect-agent.md.template` and
`agents/implementation-agent.md.template` in a "Stack reminders" section that
tells the agent which conventions to preserve. Also used in the escape-hatch
section of `agents/architect-agent.md.template` for cases where the agent needs
project-specific guidance not otherwise covered by capability blocks.

---

---

## {{REPOS_MAP_JSON}}

**Token:** `{{REPOS_MAP_JSON}}`

**Source field in analysis report:** `workspace.repos` — an object where each
key is the directory name of a service repo under the workspace root.

**Resolution logic:**

For each repo in the workspace, extract the Azure DevOps `repositoryId` by
parsing the git remote URL:

```bash
git -C "<workspace>/<repo>" remote get-url origin 2>/dev/null
```

Parse the URL to extract the repo UUID or name. If the remote is an ADO URL
of the form `.../git/RepoName`, use the UUID from the ADO API if reachable,
otherwise stub `[TODO: repositoryId]`.

Render as a JSON object:

```json
{
  "meas.cloud.common-dto":   { "azureDevOps": { "repositoryId": "<uuid-or-TODO>" } },
  "meas.cloud.datahandler":  { "azureDevOps": { "repositoryId": "<uuid-or-TODO>" } },
  "meas.cloud.controller":   { "azureDevOps": { "repositoryId": "<uuid-or-TODO>" } }
}
```

**Fallback when unresolvable:** Each repo that cannot be resolved gets
`"repositoryId": "[TODO: repositoryId]"` — the user fills these in manually
after generation.

**Example resolved value (MEAS workspace):**

```json
{
  "meas.cloud.common-dto":        { "azureDevOps": { "repositoryId": "[TODO: repositoryId]" } },
  "meas.cloud.datahandler":       { "azureDevOps": { "repositoryId": "[TODO: repositoryId]" } },
  "meas.cloud.controller":        { "azureDevOps": { "repositoryId": "[TODO: repositoryId]" } },
  "meas.cloud.exportprovider":    { "azureDevOps": { "repositoryId": "[TODO: repositoryId]" } },
  "meas.cloud.profile-mapper":    { "azureDevOps": { "repositoryId": "[TODO: repositoryId]" } },
  "meas.cloud.subscription":      { "azureDevOps": { "repositoryId": "[TODO: repositoryId]" } },
  "meas.cloud.user-account":      { "azureDevOps": { "repositoryId": "[TODO: repositoryId]" } },
  "meas.cloud.web-ui":            { "azureDevOps": { "repositoryId": "[TODO: repositoryId]" } }
}
```

**Used in:** `config.json.template` inside the `<!-- IF WORKSPACE_MODE -->` block
as the value of the top-level `repos` key.

**Mode constraint:** `WORKSPACE_MODE` only. Guarded by an IF block; never
appears in non-workspace generated configs.

---

## Variable Summary Table

| Variable | Mode constraint | Always required |
|----------|----------------|-----------------|
| `{{PROJECT_NAME}}` | All modes | Yes |
| `{{REPO_NAME}}` | All modes | Yes |
| `{{STACK_NAME}}` | All modes | Yes |
| `{{TEST_FRAMEWORK}}` | All modes | Yes |
| `{{BASE_PACKAGE}}` | Java/Kotlin repos | No (empty string ok for other stacks) |
| `{{BUILD_CMD}}` | All modes | Yes |
| `{{TEST_CMD}}` | All modes | Yes |
| `{{LINT_CMD}}` | All modes | No (empty string ok) |
| `{{TICKET_PREFIX}}` | JIRA_AVAILABLE | No (falls back to TODO) |
| `{{WORKSPACE_NAME}}` | WORKSPACE_MODE only | No (guarded by IF block) |
| `{{REPO_COUNT}}` | WORKSPACE_MODE only | No (guarded by IF block) |
| `{{REPO_LIST_BULLETS}}` | WORKSPACE_MODE only | No (guarded by IF block) |
| `{{REPOS_MAP_JSON}}` | WORKSPACE_MODE only | No (guarded by IF block) |
| `{{EDGE_TYPES_JOINED}}` | CROSS_SERVICE_EDGES only | No (guarded by IF block) |
| `{{SHARED_LIB_NAME}}` | SHARED_LIB only | No (guarded by IF block) |
| `{{SHARED_LIB_CONSUMER_COUNT}}` | SHARED_LIB only | No (guarded by IF block) |
| `{{ECOSYSTEM_MEMORY_NAME}}` | MEMORIES_PRESENT only | No (guarded by IF block) |
| `{{REPO_OR_SERVICE_LABEL}}` | All modes | Yes |
| `{{STACK_REMINDERS}}` | All modes | No (empty string ok) |
