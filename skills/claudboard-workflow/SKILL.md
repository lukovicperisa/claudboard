---
name: claudboard-workflow
description: >
  Generates a tailored `.claude/skills/feature-workflow/` skill into any project
  by reading the claudboard analysis report, gathering config from the user,
  and rendering Markdown templates with capability blocks and substitution
  variables. Produces a complete, project-aware feature-workflow skill
  (SKILL.md, agents, scripts, config.json) ready to drive `/start-feature` flows.
  Use when: /claudboard-workflow, "set up feature workflow", "install start-feature
  skill", "generate feature-workflow", "configure feature workflow for this repo",
  "add the feature workflow skill", "generate my start-feature skill",
  "create the feature workflow for me", "I want a start-feature skill",
  "bootstrap feature workflow", "generate workflow skill", "set up my workflow
  skill", "add start-feature to this project".
---

# claudboard-workflow — Feature-Workflow Skill Generator

Reads the claudboard analysis report for the current project, prompts for any
missing config values, resolves capability flags and substitution variables, then
renders the feature-workflow template set and writes a complete
`.claude/skills/feature-workflow/` directory into the project.

## Invocation

```
/claudboard-workflow [path]
```

Path defaults to the current working directory. Run after `/analyse` and
`/generate` have already been run for the project.

---

## Phase 1: Pre-flight Checks

Run all checks before prompting the user for anything. Fail fast on hard
blockers. Accumulate soft warnings and present them together after the checks
pass.

### 1a. Prerequisite check

Check that the project has the claudboard base artifacts already generated:

1. Check for `CLAUDE.md` at the project root.
2. Check for `.claude/rules/` directory containing at least one `.md` file.

If either is missing, stop immediately with this exact message:

> Run /claudboard-generate first to create the context heavy agents will lean
> on. claudboard-workflow without that context produces weak prompts.

Do not proceed past this point until the prerequisite is met.

### 1b. Analysis report check

Look for `.claude/reports/claudboard-analysis.md` in the target project.

**If not found**, stop with this exact message:

> No analysis report found. Run /claudboard-analyse first, then re-run
> /claudboard-workflow.

**If found**, read it and then:

- Check `generated_at` in YAML frontmatter. If the report is older than 7 days,
  compute the exact day count and warn:
  > Analysis report is N days old. Results may not reflect recent codebase
  > changes. Continue with stale data, or re-run /claudboard-analyse first?
  > [continue / re-run]
  Wait for the user response. If "re-run", stop here.

- Check for a "Workflow Signals" subsection. If missing:
  > Limited workflow signals available — capability blocks may default off;
  > consider re-running /analyse to refresh.
  Record this warning and continue.

### 1c. Existing-skill guard

**Workspace mode:** If `WORKSPACE_MODE = true` (detected from the analysis
report before Phase 1c runs), resolve the target path as the workspace root's
`.claude/` symlink target rather than the current repo's `.claude/`:

1. Detect the workspace root as the parent of the analysis report path
   (the directory above the repo that contains the symlinked `.claude/`).
2. Verify `<workspace>/.claude` is a symlink:
   ```bash
   test -L <workspace>/.claude && readlink <workspace>/.claude
   ```
   If it is NOT a symlink (not pointing at a meta-repo), stop with:
   > Workspace detected but `.claude/` is not a symlink to a meta-repo.
   > Run `/claudboard-workspace-init` first to create the workspace meta-repo,
   > then re-run `/claudboard-workflow`.
3. Set the output target: `SKILL_TARGET="<workspace>/.claude/skills/feature-workflow/"`.

**Single-repo / monorepo mode:** `SKILL_TARGET=".claude/skills/feature-workflow/"`.

Check if `$SKILL_TARGET` already exists.

If it does, stop with this exact message:

> feature-workflow skill already exists. Upgrade flow is not available in v1;
> remove the existing skill manually if you want to regenerate.

### 1d. MCP detection

Detect which of the four supported MCP backends are available across two
independent dimensions (tracker × repo). Load `references/block-catalog.md`
for the complete detection keyword rules. Apply project-level precedence.

**Step 1: Read MCP configuration files**

Read each config in order, holding results separately per source:

1. Project-level: `.mcp.json` in the project root (or workspace root in workspace
   mode). If found, parse the `mcpServers` object.
2. User-level: `~/.claude/mcp_servers.json` (if it exists, parse `mcpServers`).
3. User-level: `~/.claude.json` (if it exists, look for `mcpServers` key).

**Step 2: Apply detection keyword rules (case-insensitive)**

For each MCP server entry, inspect the server key/name and command/args fields:

| Backend | Flag | Matches |
|---------|------|---------|
| Atlassian Jira | `TRACKER_JIRA` | name contains "atlassian", "jira", or "confluence"; OR args reference `@atlassian/` |
| Bosch Track & Release | `TRACKER_TR` | name contains "bosch-jira-mcp" or "bosch-jira"; OR args reference `bosch-jira-mcp` binary |
| Azure DevOps | `REPO_ADO` | name contains "azure-devops" or "ado"; OR args reference `azure-devops-mcp` or `@microsoft/azure` |
| GitHub | `REPO_GITHUB` | name contains "github"; OR args reference `github-mcp-server` or `@modelcontextprotocol/server-github` |

For each match, record: flag, source (project / user), server name and config path.

Emit a warning when a match occurs via command/args only (indirect match), so
the user can verify the detection was intentional.

**Step 3: Apply project-level precedence**

Within each dimension, if a flag is detected in the project-level `.mcp.json`,
it takes precedence over any conflicting user-level detection in the same
dimension. Suppress the user-level entry for that dimension.

**Step 4: Resolve mutually-exclusive dimensions**

_Tracker dimension:_

- **Both** `TRACKER_JIRA` and `TRACKER_TR` detected → prompt:
  ```
  Two tracker MCPs detected. Which should the generated workflow target?
  [1] Atlassian Jira         (detected in: <source path>)
  [2] Bosch Track & Release  (detected in: <source path>)
  ```
  Set the chosen flag true, the other false. Record "chosen via prompt".

- **Only one** detected → set it true, the other false.

- **Neither** detected → both false. Emit warning (accumulate for Phase 5 and
  completion report):
  ```
  ⚠ No tracker MCP detected. Generated feature-workflow has no ticket
    integration. To enable: configure Atlassian Jira MCP or Bosch T&R MCP,
    then re-run /claudboard-workflow.
  ```

_Repo dimension (apply same logic):_

- **Both** `REPO_ADO` and `REPO_GITHUB` detected → prompt:
  ```
  Two repo MCPs detected. Which should the generated workflow target?
  [1] Azure DevOps  (detected in: <source path>)
  [2] GitHub        (detected in: <source path>)
  ```
  Set the chosen flag true, the other false. Record "chosen via prompt".

- **Only one** detected → set it true, the other false.

- **Neither** detected → both false. Emit warning:
  ```
  ⚠ No repo MCP detected. Generated feature-workflow has no PR creation.
    To enable: configure Azure DevOps MCP or GitHub MCP, then re-run
    /claudboard-workflow.
  ```

**Step 5: Halt-on-conflict guard**

After resolution, if both flags in either dimension are still true (should not
occur if the user answered the prompt, but guards against bad state):

```
Error: precedence resolution failed — both flags in the [tracker|repo] dimension
are true after resolution. Cannot generate a deterministic workflow.
Aborting.
```

**Step 6: Record detection state**

Accumulate detection results for the Phase 7 completion report "MCP detection"
section. For each of the four backends, record:
- Detected / not detected
- Source config path where found (or "—" if not detected)
- Resolution: auto / chosen via prompt / overridden by project-level

---

## Phase 2: Config Gathering

Gather values for `config.json` and substitution variables. Work through each
source in order — auto-detect first, inherit from siblings second, prompt last.

### 2a. Auto-detect from git remote

Run:

```bash
git remote -v
```

**Azure DevOps patterns** (only when `REPO_ADO = true`):

- `https://dev.azure.com/{org}/{project}/_git/{repo}` (modern)
- `https://{org}.visualstudio.com/{project}/_git/{repo}` (legacy)

If a match is found, extract and set:

- `azureDevOps.org` — the `{org}` segment
- `azureDevOps.project` — the `{project}` segment
- `azureDevOps.repositoryName` — the `{repo}` segment (record for display;
  `repositoryId` is a UUID and cannot be auto-detected)

**GitHub patterns** (only when `REPO_GITHUB = true`):

- `git@github.com:{owner}/{repo}.git` (SSH)
- `https://github.com/{owner}/{repo}` or `https://github.com/{owner}/{repo}.git` (HTTPS)

If a match is found, extract and set:

- `github.owner` — the `{owner}` segment (GitHub username or org)
- `github.repo` — the `{repo}` segment (repository name, without `.git`)

Record `github.linkingKeyword = "Closes"` as the default (can be overridden in
Phase 2c if the user's GitHub workflow uses a different keyword like `Fixes` or
`Resolves`).

Inform the user of what was auto-detected before moving on. Unrecognised remote
URLs are silently skipped — missing values will be prompted in Phase 2c.

### 2b. Sibling-repo inheritance

Scan the parent directory (`../`) for directories containing
`.claude/skills/feature-workflow/config.json`. For each sibling found, read
its `config.json`.

If one or more siblings have a valid `config.json`, offer inheritance:

```
Found feature-workflow config in sibling repo(s):
  • ../order-service/ — project: PLAT, urlBase: https://example.atlassian.net

Inherit shared values from sibling? [y/n]
If y, which sibling to inherit from: [list if multiple]
```

Load the reference file `references/tracker-config-prompts.md` and
`references/repo-config-prompts.md` for the exact inheritance offer wording.

Fields that CAN be inherited from siblings:
- `jira.cloudId`
- `jira.projectKey`
- `jira.urlBase`
- `jira.customFields.sprint`
- `jira.customFields.acceptanceCriteria`
- `azureDevOps.org` (if not auto-detected)
- `azureDevOps.project` (if not auto-detected)
- `tr.baseUrl`, `tr.projectKey` (if T&R sibling exists)
- `github.owner`, `github.repo` (if GitHub sibling exists and not auto-detected)

Fields that MUST NOT be inherited (always per-repo):
- `azureDevOps.repositoryId`
- `azureDevOps.repositoryName`

### 2c. Prompt for remaining fields

For each `config.json` field not resolved by auto-detect or inheritance, prompt
the user using the prompt text from `references/tracker-config-prompts.md` (for
tracker fields) and `references/repo-config-prompts.md` (for repo fields).

Every prompt must offer a "stub with TODO" escape:

> Type 's' to stub with [TODO: FIELD_NAME] and continue.

Fields requiring prompts (when not auto-detected/inherited):

**Tracker fields (TRACKER_JIRA only):**

| Field | Default |
|-------|---------|
| `jira.cloudId` | none |
| `jira.projectKey` | none |
| `jira.urlBase` | none |
| `jira.customFields.sprint` | `customfield_10001` |
| `jira.customFields.acceptanceCriteria` | `customfield_12206` |
| `jira.transitions.start` | `In Progress` |
| `jira.transitions.success` | `In Review` |
| `jira.transitions.failure` | `Blocked` |

Skip all Jira fields if `TRACKER_JIRA = false`.

**Tracker fields (TRACKER_TR only):**

| Field | Default |
|-------|---------|
| `tr.baseUrl` | none (e.g., `https://track.example.bosch.com`) |
| `tr.projectKey` | none (e.g., `MEAS`) |
| `tr.transitions.start` | `In Progress` |
| `tr.transitions.success` | `In Review` |
| `tr.transitions.failure` | `Blocked` |
| `tr.transitions.pause` | `null` |

Skip all T&R fields if `TRACKER_TR = false`.

**Repo fields (REPO_ADO only):**

| Field | Default |
|-------|---------|
| `azureDevOps.repositoryId` | none (always prompted, never inherited) |

Skip all ADO fields if `REPO_ADO = false`.

**Repo fields (REPO_GITHUB only):**

| Field | Default |
|-------|---------|
| `github.owner` | auto-detected from git remote |
| `github.repo` | auto-detected from git remote |
| `github.linkingKeyword` | `Closes` |

Prompt for `github.owner` and `github.repo` only if not auto-detected in 2a.
Always offer the user the chance to override the `linkingKeyword` default
(`Closes`) — some teams use `Fixes` or `Resolves`.

Skip all GitHub fields if `REPO_GITHUB = false`.

**Shared git fields (always prompted):**

| Field | Default |
|-------|---------|
| `git.branchTypes` | `["feature","bugfix","hotfix"]` |
| `git.branchPattern` | `{type}/{ticket}/{slug}` if either tracker active, else `{type}/{slug}` |
| `git.ticketRegex` | `[A-Z]+-[0-9]+` |

---

## Phase 3: Capability-Flag Resolution

Resolve all 18 v1 capability flags from workflow signals and architectural patterns in the analysis report, and from runtime checks. Load `references/block-catalog.md` for the full resolution table.

| Flag | Source | Resolution logic |
|------|--------|-----------------|
| `TRACKER_JIRA` | MCP config (Phase 1d) | Set in Phase 1d; mutually exclusive with `TRACKER_TR` |
| `TRACKER_TR` | MCP config (Phase 1d) | Set in Phase 1d; mutually exclusive with `TRACKER_JIRA` |
| `REPO_ADO` | MCP config (Phase 1d) | Set in Phase 1d; mutually exclusive with `REPO_GITHUB` |
| `REPO_GITHUB` | MCP config (Phase 1d) | Set in Phase 1d; mutually exclusive with `REPO_ADO` |
| `WORKSPACE_MODE` | Analysis report | `true` if report frontmatter has `workspace: true` or report body contains "Workspace mode" section |
| `CROSS_SERVICE_EDGES` | Workflow Signals subsection | `true` if Workflow Signals lists ≥1 cross-service edge |
| `SHARED_LIB` | Workflow Signals subsection | `true` if Workflow Signals lists ≥1 shared library with `consumer_count ≥ 2` |
| `AUTH_PERIMETER` | Workflow Signals subsection | `true` if `auth_perimeter` field is not "none" and not "unknown" |
| `MEMORIES_PRESENT` | Filesystem check | `true` if `.claude/memories/` exists and contains ≥1 `.md` file |
| `MONGODB` | Analysis report | `true` if Spring Data MongoDB detected (look for `spring-data-mongodb` or `@Document`) |
| `JPA` | Analysis report | `true` if Spring Data JPA / Hibernate detected (look for `spring-data-jpa`, `@Entity`, `@Repository`) |
| `KAFKA` | Analysis report | `true` if Kafka producers/consumers detected (look for `spring-kafka`, `@KafkaListener`, `KafkaTemplate`) |
| `RABBITMQ` | Analysis report / Workflow Signals | `true` if RabbitMQ detected: `@RabbitListener`, `RabbitTemplate`, `spring-rabbit`, or `protocol: rabbitmq` in `cross_service_edges` |
| `JMS` | Analysis report / Workflow Signals | `true` if JMS detected: `@JmsListener`, `JmsTemplate`, `spring-boot-starter-activemq`, or `protocol: jms` in `cross_service_edges` |
| `GRAPHQL` | Analysis report / Workflow Signals | `true` if GraphQL detected: `spring-graphql`, `netflix-dgs`, `@QueryMapping`, Apollo, `urql`, `graphql-request`, or `protocol: graphql` in `cross_service_edges` |
| `WEBSOCKET` | Analysis report / Workflow Signals | `true` if WebSocket/streaming detected: `spring-boot-starter-websocket`, `socket.io`, `ws`, `rsocket-*`, or `protocol` in `{websocket,stomp,socketio,sse,rsocket}` in `cross_service_edges` |
| `SAGA` | `architectural_patterns` subsection | `true` if `architectural_patterns` list contains an entry with `type: saga`. Resolve sub-style from `style` field: `orchestration` or `choreography`. Default `false` when `architectural_patterns` absent. |
| `CQRS` | `architectural_patterns` subsection | `true` if `architectural_patterns` contains `type: cqrs`. Default `false` when subsection absent. |
| `OUTBOX` | `architectural_patterns` subsection | `true` if `architectural_patterns` contains `type: outbox`. Default `false` when subsection absent. |
| `CIRCUIT_BREAKER` | `architectural_patterns` subsection | `true` if `architectural_patterns` contains `type: circuit-breaker`. Extract `library` field for `{{CIRCUIT_BREAKER_LIBRARY}}` substitution. Default `false` when subsection absent. |

**Flags with missing Workflow Signals:** If the "Workflow Signals" subsection is
absent (warned in Phase 1b), default `WORKSPACE_MODE`, `CROSS_SERVICE_EDGES`,
`SHARED_LIB`, `AUTH_PERIMETER`, `RABBITMQ`, `JMS`, `GRAPHQL`, `WEBSOCKET` all
to `false` and note them as "defaulted off (no workflow signals)".

**Flags with missing Architectural Patterns subsection:** If the "Architectural Patterns" subsection is absent (old-schema report), default `SAGA`, `CQRS`, `OUTBOX`, `CIRCUIT_BREAKER` all to `false` and emit a single warning:

> "Architectural patterns subsection absent — SAGA, CQRS, OUTBOX, CIRCUIT_BREAKER flags defaulted to false. Re-run `/analyse` to enable pattern-based blocks."

Record every resolved flag value and its evidence source for display in Phase 5.

---

## Phase 4: Substitution Resolution

Resolve all substitution variables from the analysis report and runtime
context. Load `references/substitution-catalog.md` for source fields, fallback
rules, and example values.

For each variable:

1. Read the source field from the analysis report (see catalog for exact field
   paths).
2. If the source field is present and non-empty, use its value.
3. If the source field is absent or empty, check for a catalog-defined fallback.
4. If no fallback is resolvable, use the literal `[TODO: VAR_NAME]` and record a
   warning.

| Variable | Primary source |
|----------|---------------|
| `{{PROJECT_NAME}}` | Report frontmatter `repo` field basename |
| `{{REPO_NAME}}` | Report frontmatter `repo` field basename |
| `{{STACK_NAME}}` | Report "How (design & patterns)" → Architecture bullet |
| `{{TEST_FRAMEWORK}}` | Report Testing quality section |
| `{{BASE_PACKAGE}}` | Report stack details or Wide Scan package root |
| `{{BUILD_CMD}}` | Report "How" → Build bullet |
| `{{TEST_CMD}}` | Report "How" → Build commands table |
| `{{LINT_CMD}}` | Report CI/CD section or build commands table |
| `{{TICKET_PREFIX}}` | Workflow Signals `ticket_prefix` field |
| `{{WORKSPACE_NAME}}` | Parent directory name or report workspace identifier |
| `{{REPO_COUNT}}` | Report topology table row count |
| `{{REPO_LIST_BULLETS}}` | Report topology table rendered as bullet list |
| `{{EDGE_TYPES_JOINED}}` | Workflow Signals cross-service edge types joined with ", " |
| `{{SHARED_LIB_NAME}}` | Workflow Signals first shared library name |
| `{{SHARED_LIB_CONSUMER_COUNT}}` | Workflow Signals first shared library consumer_count |
| `{{ECOSYSTEM_MEMORY_NAME}}` | Filename of `.claude/memories/ecosystem.md` if present |
| `{{REPO_OR_SERVICE_LABEL}}` | "workspace" if WORKSPACE_MODE else "repo" |
| `{{STACK_REMINDERS}}` | Report "Patterns detected" / "Preserve" section rendered as bullet list |
| `{{REPOS_MAP_JSON}}` | Per-repo ADO repositoryId map; WORKSPACE_MODE only; see substitution-catalog |
| `{{CLARIFY_AUTONOMY_DEFAULT}}` | `config.clarify.defaultAutonomy` from generated config; fallback `balanced` |

**`{{STACK_REMINDERS}}` lift:** Read the "Preserve" bullets from the analysis
report (the items under "Preserve:" in the quality assessment). Format as a
bullet list. If the section is absent, use an empty string (no bullet list).

For WORKSPACE_MODE-specific variables (`{{WORKSPACE_NAME}}`, `{{REPO_COUNT}}`,
`{{REPO_LIST_BULLETS}}`), if `WORKSPACE_MODE = false`, resolve as empty string
unless used in an always-on section of a template.

---

## Phase 5: Confirmation Gate

Before writing any files, present a complete summary and wait for user approval.

```
## claudboard-workflow — Ready to Generate

### Files to write:
  .claude/skills/feature-workflow/      ← [or <workspace>/.claude/skills/feature-workflow/ in workspace mode]
  ├── SKILL.md
  ├── config.json
  ├── references/
  │   └── claude-pricing.md
  ├── scripts/
  │   ├── jira-add-labels.sh     ← only if TRACKER_JIRA=true
  │   ├── lib.sh
  │   ├── load-repo-context.sh   ← [workspace mode only]
  │   ├── prepare-commit.sh
  │   ├── prepare-pr.sh
  │   └── prepare-squash.sh
  └── agents/
      ├── architect-agent.md
      ├── design-reviewer.md
      ├── git-agent.md
      ├── implementation-agent.md
      ├── jira-agent.md          ← only if TRACKER_JIRA=true
      ├── tr-agent.md            ← only if TRACKER_TR=true
      ├── pr-agent-ado.md        ← only if REPO_ADO=true
      ├── pr-agent-github.md     ← only if REPO_GITHUB=true
      ├── sdd-expert-agent.md
      └── spec-reviewer.md

### Capability blocks:
  ENABLED:  TRACKER_JIRA, JPA, AUTH_PERIMETER
  DISABLED: TRACKER_TR, REPO_ADO, REPO_GITHUB, WORKSPACE_MODE, CROSS_SERVICE_EDGES,
            SHARED_LIB, MEMORIES_PRESENT, MONGODB, KAFKA

### Resolved config:
  jira.cloudId:              a1b2c3d4-...
  jira.projectKey:           PLAT
  jira.urlBase:              https://example.atlassian.net
  jira.customFields.sprint:  customfield_10001
  azureDevOps.repositoryId:  [TODO: AZURE_DEVOPS_REPOSITORY_ID]  ← stub
  git.branchPattern:         {type}/{ticket}/{slug}
  git.ticketRegex:           [A-Z]+-[0-9]+

[WORKSPACE MODE ONLY]:
  Target path:  <workspace>/.claude/skills/feature-workflow/
                (via symlink → <meta-repo>/.claude/skills/feature-workflow/)
  Repos map:    <N> repos detected (config.json will include repos: { ... })
  Per-repo feature-workflow skills found (will NOT be auto-deleted):
    • <workspace>/<repo>/.claude/skills/feature-workflow/
    [listed for manual cleanup — see completion report]

Proceed? [y/n/edit]
```

**On `n`:** Ask what should change and loop back to the relevant phase.

**On `edit`:** Ask which value the user wants to change, update it, and re-show
the confirmation gate.

**On `y`:** Proceed to Phase 6.

**Path violation guard:** Any resolved output path that falls outside
`$SKILL_TARGET` must be refused immediately:

> Write refused: target path [path] is outside the allowed directory
> [SKILL_TARGET]. Aborting.

**Workspace-mode guard:** In workspace mode, any write path that resolves into
a per-repo `.claude/` (i.e., `<workspace>/<repo>/.claude/`) rather than the
meta-repo is rejected:

> Write refused: workspace mode prohibits writing into a per-repo .claude/.
> feature-workflow is generated once at the workspace root; per-repo copies
> are not generated. Aborting.

**Per-repo feature-workflow scan (workspace mode only):** Before the
confirmation gate, scan for any existing `feature-workflow/` directories in
per-repo `.claude/` directories and record their paths. These are listed in
the completion report with the removal command — NOT auto-deleted.

```bash
find <workspace> -maxdepth 3 -type d \
  -name "feature-workflow" \
  -path "*/.claude/skills/feature-workflow" \
  ! -path "<workspace>/.claude/*"
```

---

## Phase 6: Template Rendering and File Writes

Resolve the absolute path of `references/feature-workflow.template/` relative to
this skill file. Hold it as `$TEMPLATE_DIR` for the rest of this phase.

### 6a. Batch-copy verbatim files

Verbatim files have no `.template` suffix — no flag evaluation or variable
substitution needed. Copy them via a single bash block to avoid loading file
contents into the conversation context. **Do NOT use Read+Write for these files.**

```bash
mkdir -p "$SKILL_TARGET/agents" "$SKILL_TARGET/scripts" "$SKILL_TARGET/references"

# Unconditional copies
cp "$TEMPLATE_DIR/scripts/lib.sh"                "$SKILL_TARGET/scripts/"
cp "$TEMPLATE_DIR/scripts/prepare-commit.sh"     "$SKILL_TARGET/scripts/"
cp "$TEMPLATE_DIR/scripts/prepare-pr.sh"         "$SKILL_TARGET/scripts/"
cp "$TEMPLATE_DIR/scripts/prepare-squash.sh"     "$SKILL_TARGET/scripts/"
cp "$TEMPLATE_DIR/references/claude-pricing.md"  "$SKILL_TARGET/references/"
```

Conditional copies — run each `cp` only when the corresponding flag is `true`:

| Flag | File |
|------|------|
| `TRACKER_JIRA` | `cp "$TEMPLATE_DIR/agents/jira-agent.md" "$SKILL_TARGET/agents/"` |
| `TRACKER_JIRA` | `cp "$TEMPLATE_DIR/scripts/jira-add-labels.sh" "$SKILL_TARGET/scripts/"` |
| `TRACKER_TR` | `cp "$TEMPLATE_DIR/agents/tr-agent.md" "$SKILL_TARGET/agents/"` |
| `REPO_ADO` | `cp "$TEMPLATE_DIR/agents/pr-agent-ado.md" "$SKILL_TARGET/agents/"` |
| `REPO_GITHUB` | `cp "$TEMPLATE_DIR/agents/pr-agent-github.md" "$SKILL_TARGET/agents/"` |
| `WORKSPACE_MODE` | `cp "$TEMPLATE_DIR/scripts/load-repo-context.sh" "$SKILL_TARGET/scripts/"` |

Verify that all expected files exist after the copy:

```bash
ls -la "$SKILL_TARGET/scripts/" "$SKILL_TARGET/references/"
ls -la "$SKILL_TARGET/agents/"  # conditional files only
```

### 6b. Template rendering algorithm

For each `.template` file:

**Step 1 — Capability block evaluation:**

Scan for `<!-- IF FLAG -->...<!-- ENDIF -->` blocks.

For each block found:
- If the flag resolves to `true`: remove the `<!-- IF FLAG -->` and `<!-- ENDIF
  -->` comment lines; keep the inner content unchanged.
- If the flag resolves to `false`: remove the entire block including its
  surrounding whitespace lines.
- If the flag name is not in the v1 catalog: log a warning
  (`Unknown capability flag: FLAG_NAME — treating as disabled`) and remove the
  block.

Blocks may be nested only if the outer flag is distinct from the inner flag.
Process outer blocks before inner blocks.

**Step 2 — Variable substitution:**

Scan for `{{VAR_NAME}}` tokens.

For each token found:
- Replace with the resolved value from Phase 4.
- If the resolved value is `[TODO: VAR_NAME]`, leave it as-is (the literal
  appears in the output so the user knows to fill it in).

**Step 3 — Write output:**

Strip the `.template` suffix from the filename to get the output filename.
Write to `.claude/skills/feature-workflow/<relative-path-within-template-dir>`.

Verify the write succeeded before moving to the next file.

### 6c. File mapping

**Templated files** (rendered in 6b, written via Write tool):

| Template file | Output file |
|---------------|-------------|
| `SKILL.md.template` | `SKILL.md` |
| `config.json.template` | `config.json` |
| `agents/architect-agent.md.template` | `agents/architect-agent.md` |
| `agents/design-reviewer.md.template` | `agents/design-reviewer.md` |
| `agents/git-agent.md.template` | `agents/git-agent.md` |
| `agents/implementation-agent.md.template` | `agents/implementation-agent.md` |
| `agents/sdd-expert-agent.md.template` | `agents/sdd-expert-agent.md` |
| `agents/spec-reviewer.md.template` | `agents/spec-reviewer.md` |

All output paths are relative to `$SKILL_TARGET`.

**Verbatim files** (batch-copied in 6a via bash — NOT read into context):

| File | Condition |
|------|-----------|
| `scripts/lib.sh` | always |
| `scripts/prepare-commit.sh` | always |
| `scripts/prepare-pr.sh` | always |
| `scripts/prepare-squash.sh` | always |
| `references/claude-pricing.md` | always |
| `agents/jira-agent.md` | `TRACKER_JIRA = true` |
| `scripts/jira-add-labels.sh` | `TRACKER_JIRA = true` |
| `agents/tr-agent.md` | `TRACKER_TR = true` |
| `agents/pr-agent-ado.md` | `REPO_ADO = true` |
| `agents/pr-agent-github.md` | `REPO_GITHUB = true` |
| `scripts/load-repo-context.sh` | `WORKSPACE_MODE = true` |

### 6d. Upgrade path footer

After rendering `SKILL.md.template`, append the following section at the bottom
of the rendered `.claude/skills/feature-workflow/SKILL.md` before writing:

```markdown
## Upgrade Path

Generated by claudboard-workflow on {{GENERATION_DATE}} from template version v1.
To regenerate with updated templates, remove this directory and re-run
`/claudboard-workflow`.
```

Replace `{{GENERATION_DATE}}` with today's date in `YYYY-MM-DD` format.

### 6e. Write config.json

After rendering `config.json.template`, parse the rendered content and write it
as properly formatted JSON to `.claude/skills/feature-workflow/config.json`.

---

## Phase 7: Completion Report

After all files are written, present a full completion report.

```
## claudboard-workflow — Done

### Files written:
  .claude/skills/feature-workflow/SKILL.md
  .claude/skills/feature-workflow/config.json
  .claude/skills/feature-workflow/references/claude-pricing.md
  .claude/skills/feature-workflow/scripts/jira-add-labels.sh    ← if TRACKER_JIRA
  .claude/skills/feature-workflow/scripts/lib.sh
  .claude/skills/feature-workflow/scripts/prepare-commit.sh
  .claude/skills/feature-workflow/scripts/prepare-pr.sh
  .claude/skills/feature-workflow/scripts/prepare-squash.sh
  .claude/skills/feature-workflow/agents/architect-agent.md
  .claude/skills/feature-workflow/agents/design-reviewer.md
  .claude/skills/feature-workflow/agents/git-agent.md
  .claude/skills/feature-workflow/agents/implementation-agent.md
  .claude/skills/feature-workflow/agents/jira-agent.md
  .claude/skills/feature-workflow/agents/pr-agent.md
  .claude/skills/feature-workflow/agents/sdd-expert-agent.md
  .claude/skills/feature-workflow/agents/spec-reviewer.md

### Capability blocks:
  Enabled:  TRACKER_JIRA, JPA, AUTH_PERIMETER
  Disabled: REPO_ADO, REPO_GITHUB, TRACKER_TR, WORKSPACE_MODE, CROSS_SERVICE_EDGES,
            SHARED_LIB, MEMORIES_PRESENT, MONGODB, KAFKA

### MCP detection:

| Backend | Result | Source |
|---------|--------|--------|
| TRACKER_JIRA (Atlassian Jira) | detected | .mcp.json |
| TRACKER_TR (Bosch T&R) | not detected | — |
| REPO_ADO (Azure DevOps) | not detected | — |
| REPO_GITHUB (GitHub) | not detected | — |

[list any precedence prompts answered and any indirect-match warnings]

[IF TRACKER_TR active, append:]
### T&R v1 limitations:

The generated workflow uses Bosch Track & Release via bosch-jira-mcp. The
following capabilities are not available in v1 due to limitations in the
underlying MCP tool surface (6 tools: jira_search, jira_get_issue,
jira_add_comment, jira_transition, jira_update_issue, jira_get_myself):

1. **No auto-create ticket (Path A only)** — The T&R MCP has no issue-creation
   tool. Use `/start-feature TR-XXXXX` with an existing ticket key.
   Lifts when: `jira_create_issue` lands in bosch-jira-mcp.

2. **No sprint assignment** — T&R MCP cannot write custom fields. Sprint field
   is skipped; `sprintAssigned: false` is noted in the fetchAndPrepare result.
   Lifts when: `jira_update_issue` gains custom-field write support.

3. **No worklog** — T&R MCP has no worklog tool. Refinement and implementation
   time are folded into the Phase 7 final summary comment body instead.
   Lifts when: `jira_add_worklog` lands in bosch-jira-mcp.

4. **AC inlined in description** — Acceptance Criteria are written under a
   `## Acceptance Criteria` heading in the ticket description body, not in a
   separate custom field.
   Lifts when: `jira_update_issue` gains custom-field write support.

5. **Labels via read-modify-write (non-atomic)** — T&R's `jira_update_issue`
   labels semantics are REPLACE, not the Jira REST `update.labels[{add:…}]`
   atomic add. The agent reads current labels, computes the union, then writes
   the merged set. Low concurrency risk for single-user workflows.
   Lifts when: `jira_update_issue` gains atomic label-add support.

[IF migrated from legacy flags, append:]
### Migrated from legacy flag names:

This generation detected an existing feature-workflow directory with the older
flag naming convention. The following flag renames are now in effect:

| Old name | New name |
|----------|----------|
| `JIRA_AVAILABLE` | `TRACKER_JIRA` |
| `ADO_AVAILABLE` | `REPO_ADO` |

Any `<!-- IF JIRA_AVAILABLE -->` or `<!-- IF ADO_AVAILABLE -->` blocks in hand-
edited skill files should be updated to use the new names.

### Config stubs (fields left as TODO — fill before first use):

[list any [TODO: ...] placeholders written to config.json with hints for where
to find the correct values]

Clarification autonomy default set to `{{CLARIFY_AUTONOMY_DEFAULT}}` (override per-invocation or edit `clarify.defaultAutonomy` in `config.json`).

**Next steps:** Try `/start-feature` on a small ticket to validate the wiring.
```

**Workspace-mode completion report additions (append when WORKSPACE_MODE=true):**

```
### Workspace skill location
  Generated into: <workspace>/.claude/skills/feature-workflow/
  Resolved path:  <meta-repo-path>/.claude/skills/feature-workflow/

### config.json — repos map
  All N repo entries are stubbed with [TODO: repositoryId].
  Fill in the Azure DevOps repositoryId for each repo before first use:
    az repos show --repository <repo-name> --query id -o tsv
  Or find it in ADO under Repos → [Repo] → Clone → HTTPS URL.

### Commit to meta-repo
  The generated files are in the meta-repo through the symlink.
  After review, commit them:
    cd <meta-repo-path>
    git add .claude/skills/feature-workflow/
    git commit -m "feat: generate multi-repo feature-workflow skill via claudboard-workflow"
    git push

### Per-repo feature-workflow skills found (not auto-deleted)
  These pre-existing skills are now superseded by the workspace skill.
  Remove them manually when ready:
  [listed paths with: rm -rf <path>]

### Validation
  From the workspace root, start a feature to validate end-to-end:
    /start-feature [some small cross-service feature description]
  Verify: affected_repos inference, per-repo branches, parallel PRs.
```

---

## Error Handling

| Condition | Behavior |
|-----------|----------|
| Prereq check fails | Stop with exact message from 1a |
| Analysis report missing | Stop with exact message from 1b |
| Analysis report stale | Warn with day count, offer continue or re-run |
| Workflow Signals missing | Warn, continue with flags defaulted off |
| Existing skill found | Stop with exact message from 1c |
| Unknown capability flag in template | Log warning, treat block as disabled |
| `{{VAR}}` unresolvable | Use `[TODO: VAR_NAME]`, record in completion report |
| Write outside allowed path | Refuse with path-violation message, abort |
| Template file not found | Warn, skip file, list as missing in completion report |

## Constraints

- **Never write outside** `.claude/skills/feature-workflow/`. The path guard in
  Phase 5 is non-negotiable.
- **No source code modifications.** Only `.claude/` is touched.
- **Verbatim files are not templated.** Do not substitute variables in files
  without the `.template` suffix.
- **Tracker agent files are conditional.** Write `jira-agent.md` only when
  `TRACKER_JIRA = true`; write `tr-agent.md` only when `TRACKER_TR = true`.
  Never write both.
- **Repo agent files are conditional.** Write `pr-agent-ado.md` only when
  `REPO_ADO = true`; write `pr-agent-github.md` only when `REPO_GITHUB = true`.
  Never write both.

## Backend Support

The generator supports 4 MCP backends across 2 independent dimensions:

| Dimension | Backend | Flag | Detection |
|-----------|---------|------|-----------|
| Tracker | Atlassian Jira | `TRACKER_JIRA` | Server name contains "atlassian"/"jira"/"confluence" or args reference `@atlassian/` |
| Tracker | Bosch Track & Release | `TRACKER_TR` | Server name contains "bosch-jira-mcp" or args reference `bosch-jira-mcp` |
| Repo | Azure DevOps | `REPO_ADO` | Server name contains "azure-devops"/"ado" or args reference `azure-devops-mcp`/`@microsoft/azure` |
| Repo | GitHub | `REPO_GITHUB` | Server name contains "github" or args reference `github-mcp-server`/`@modelcontextprotocol/server-github` |

**Mutual-exclusion rule:** Within each dimension, at most one flag may be true.
If both MCPs in a dimension are detected, the user is prompted to choose.
If neither is detected, that dimension's phases are omitted from the generated
workflow and a warning is emitted.

**T&R v1 limitations:** When `TRACKER_TR` is active, the following capabilities
are unavailable (each tied to a missing tool in bosch-jira-mcp v1.0.0):
auto-create, worklog, sprint assignment, AC custom field, atomic label add.
These are documented in the completion report and explicitly handled (not
silently skipped) in `tr-agent.md`.

## Reference Files

| File | When to load |
|------|-------------|
| `references/block-catalog.md` | Phase 3 — flag resolution rules for all v1 flags |
| `references/substitution-catalog.md` | Phase 4 — variable source fields, fallbacks, examples |
| `references/tracker-config-prompts.md` | Phase 2 — prompt text for Jira and T&R config fields |
| `references/repo-config-prompts.md` | Phase 2 — prompt text for ADO and GitHub config fields |
| `references/feature-workflow.template/*` | Phase 6 — template files to render |
