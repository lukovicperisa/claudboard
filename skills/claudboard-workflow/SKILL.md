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

Inspect MCP configuration to determine tool availability:

1. **Project-level first:** read `.mcp.json` in the project root if it exists.
2. **User-level fallback:** read `~/.claude/mcp_servers.json` or `~/.claude.json`
   (whichever exists).

Set capability flags based on what you find:

- `JIRA_AVAILABLE = true` — if an Atlassian MCP server entry is present in any
  inspected config (look for server names/keys containing "atlassian", "jira",
  or "confluence", or command/args referencing `@atlassian/`).
- `ADO_AVAILABLE = true` — if an Azure DevOps MCP server entry is present (look
  for server names/keys containing "azure-devops", "ado", or command/args
  referencing `azure-devops-mcp` or `@microsoft/azure`).

Record both flags. Accumulate any missing-MCP warnings for Phase 5.

---

## Phase 2: Config Gathering

Gather values for `config.json` and substitution variables. Work through each
source in order — auto-detect first, inherit from siblings second, prompt last.

### 2a. ADO auto-detect from git remote

Run:

```bash
git remote -v
```

Parse the output for Azure DevOps remote URL patterns:

- `https://dev.azure.com/{org}/{project}/_git/{repo}` (modern)
- `https://{org}.visualstudio.com/{project}/_git/{repo}` (legacy)

If a match is found, extract and set:

- `azureDevOps.org` — the `{org}` segment
- `azureDevOps.project` — the `{project}` segment
- `azureDevOps.repositoryName` — the `{repo}` segment (record for display;
  `repositoryId` is a UUID and cannot be auto-detected)

Inform the user of what was auto-detected before moving on.

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

Load the reference file `references/jira-config-prompts.md` for the exact
inheritance offer wording.

Fields that CAN be inherited from siblings:
- `jira.cloudId`
- `jira.projectKey`
- `jira.urlBase`
- `jira.customFields.sprint`
- `jira.customFields.acceptanceCriteria`
- `azureDevOps.org` (if not auto-detected)
- `azureDevOps.project` (if not auto-detected)

Fields that MUST NOT be inherited (always per-repo):
- `azureDevOps.repositoryId`
- `azureDevOps.repositoryName`

### 2c. Prompt for remaining fields

For each `config.json` field not resolved by auto-detect or inheritance, prompt
the user using the prompt text from `references/jira-config-prompts.md`.

Every prompt must offer a "stub with TODO" escape:

> Type 's' to stub with [TODO: FIELD_NAME] and continue.

Fields requiring prompts (when not auto-detected/inherited):

| Field | Default |
|-------|---------|
| `jira.cloudId` | none |
| `jira.projectKey` | none |
| `jira.urlBase` | none |
| `jira.customFields.sprint` | `customfield_10001` |
| `jira.customFields.acceptanceCriteria` | `customfield_12206` |
| `azureDevOps.repositoryId` | none (always prompted) |
| `git.branchTypes` | `["feature","bugfix","hotfix"]` |
| `git.branchPattern` | `{type}/{ticket}/{slug}` if JIRA_AVAILABLE else `{type}/{slug}` |
| `git.ticketRegex` | `[A-Z]+-[0-9]+` |

Skip Jira fields entirely if `JIRA_AVAILABLE = false` (stub them all with TODO).
Skip ADO fields entirely if `ADO_AVAILABLE = false` (stub them all with TODO).

---

## Phase 3: Capability-Flag Resolution

Resolve all 10 v1 capability flags from workflow signals in the analysis report
and from runtime checks. Load `references/block-catalog.md` for the full
resolution table.

| Flag | Source | Resolution logic |
|------|--------|-----------------|
| `JIRA_AVAILABLE` | MCP config (Phase 1d) | Set in Phase 1d |
| `ADO_AVAILABLE` | MCP config (Phase 1d) | Set in Phase 1d |
| `WORKSPACE_MODE` | Analysis report | `true` if report frontmatter has `workspace: true` or report body contains "Workspace mode" section |
| `CROSS_SERVICE_EDGES` | Workflow Signals subsection | `true` if Workflow Signals lists ≥1 cross-service edge |
| `SHARED_LIB` | Workflow Signals subsection | `true` if Workflow Signals lists ≥1 shared library with `consumer_count ≥ 2` |
| `AUTH_PERIMETER` | Workflow Signals subsection | `true` if `auth_perimeter` field is not "none" and not "unknown" |
| `MEMORIES_PRESENT` | Filesystem check | `true` if `.claude/memories/` exists and contains ≥1 `.md` file |
| `MONGODB` | Analysis report | `true` if Spring Data MongoDB detected (look for `spring-data-mongodb` or `@Document`) |
| `JPA` | Analysis report | `true` if Spring Data JPA / Hibernate detected (look for `spring-data-jpa`, `@Entity`, `@Repository`) |
| `KAFKA` | Analysis report | `true` if Kafka producers/consumers detected (look for `spring-kafka`, `@KafkaListener`, `KafkaTemplate`) |

**Flags with missing Workflow Signals:** If the "Workflow Signals" subsection is
absent (warned in Phase 1b), default `WORKSPACE_MODE`, `CROSS_SERVICE_EDGES`,
`SHARED_LIB`, `AUTH_PERIMETER` all to `false` and note them as "defaulted off
(no workflow signals)".

Record every resolved flag value and its evidence source for display in Phase 5.

---

## Phase 4: Substitution Resolution

Resolve all 18 v1 substitution variables from the analysis report and runtime
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
      ├── jira-agent.md       ← enabled (JIRA_AVAILABLE=true)
      ├── pr-agent.md
      ├── sdd-expert-agent.md
      └── spec-reviewer.md

### Capability blocks:
  ENABLED:  JIRA_AVAILABLE, JPA, AUTH_PERIMETER
  DISABLED: ADO_AVAILABLE, WORKSPACE_MODE, CROSS_SERVICE_EDGES, SHARED_LIB,
            MEMORIES_PRESENT, MONGODB, KAFKA

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

Read each template file from `references/feature-workflow.template/`, render it,
and write the output to the target path under `.claude/skills/feature-workflow/`.

### 6a. Template rendering algorithm

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

### 6b. File mapping

| Template file | Output file |
|---------------|-------------|
| `SKILL.md.template` | `.claude/skills/feature-workflow/SKILL.md` |
| `config.json.template` | `.claude/skills/feature-workflow/config.json` |
| `agents/architect-agent.md.template` | `.claude/skills/feature-workflow/agents/architect-agent.md` |
| `agents/design-reviewer.md.template` | `.claude/skills/feature-workflow/agents/design-reviewer.md` |
| `agents/git-agent.md.template` | `.claude/skills/feature-workflow/agents/git-agent.md` |
| `agents/implementation-agent.md.template` | `.claude/skills/feature-workflow/agents/implementation-agent.md` |
| `agents/jira-agent.md` (verbatim) | `.claude/skills/feature-workflow/agents/jira-agent.md` (only if JIRA_AVAILABLE) |
| `agents/pr-agent.md.template` | `.claude/skills/feature-workflow/agents/pr-agent.md` |
| `agents/sdd-expert-agent.md.template` | `.claude/skills/feature-workflow/agents/sdd-expert-agent.md` |
| `agents/spec-reviewer.md.template` | `.claude/skills/feature-workflow/agents/spec-reviewer.md` |
| `references/claude-pricing.md` (verbatim) | `.claude/skills/feature-workflow/references/claude-pricing.md` |
| `scripts/lib.sh` (verbatim) | `.claude/skills/feature-workflow/scripts/lib.sh` |
| `scripts/prepare-commit.sh` (verbatim) | `.claude/skills/feature-workflow/scripts/prepare-commit.sh` |
| `scripts/prepare-pr.sh` (verbatim) | `.claude/skills/feature-workflow/scripts/prepare-pr.sh` |
| `scripts/prepare-squash.sh` (verbatim) | `.claude/skills/feature-workflow/scripts/prepare-squash.sh` |
| `scripts/load-repo-context.sh` (verbatim, WORKSPACE_MODE only) | `.claude/skills/feature-workflow/scripts/load-repo-context.sh` |

**Verbatim files** (no `.template` suffix, no rendering needed): copy as-is.
`jira-agent.md` is verbatim but conditional — only write it when
`JIRA_AVAILABLE = true`. `load-repo-context.sh` is verbatim but conditional —
only write it when `WORKSPACE_MODE = true`.

### 6c. Upgrade path footer

After rendering `SKILL.md.template`, append the following section at the bottom
of the rendered `.claude/skills/feature-workflow/SKILL.md` before writing:

```markdown
## Upgrade Path

Generated by claudboard-workflow on {{GENERATION_DATE}} from template version v1.
To regenerate with updated templates, remove this directory and re-run
`/claudboard-workflow`.
```

Replace `{{GENERATION_DATE}}` with today's date in `YYYY-MM-DD` format.

### 6d. Write config.json

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
  Enabled:  JIRA_AVAILABLE, JPA, AUTH_PERIMETER
  Disabled: ADO_AVAILABLE, WORKSPACE_MODE, CROSS_SERVICE_EDGES, SHARED_LIB,
            MEMORIES_PRESENT, MONGODB, KAFKA

### Config stubs (fields left as TODO — fill before first use):
  azureDevOps.repositoryId — Find in Azure DevOps under Repos → [Repo Name] →
                              Clone → HTTPS URL; the UUID is in the URL or use
                              `az repos show --repository <name>` CLI.

### MCP warnings:
  ⚠ ADO_AVAILABLE = false — Azure DevOps MCP not detected. ADO-specific phases
    in the generated skill are stubbed. To enable, configure the Azure DevOps
    MCP server and re-generate.

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
- **jira-agent.md is conditional.** Write it only when `JIRA_AVAILABLE = true`.

## Reference Files

| File | When to load |
|------|-------------|
| `references/block-catalog.md` | Phase 3 — flag resolution rules for all 10 v1 flags |
| `references/substitution-catalog.md` | Phase 4 — variable source fields, fallbacks, examples for all 18 vars |
| `references/jira-config-prompts.md` | Phase 2 — exact prompt text, defaults, inheritance UI, stub escape wording |
| `references/feature-workflow.template/*` | Phase 6 — template files to render |
