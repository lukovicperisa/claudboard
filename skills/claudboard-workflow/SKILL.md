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

Detection is script-driven: Phase 1d runs `scripts/detect.sh` to emit a JSON
detection blob (schema v1). Fallback prose paths are provided for environments
where the script is unavailable.

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

Locate `scripts/detect.sh` relative to this SKILL.md and run it:

```bash
bash scripts/detect.sh "$PROJECT_PATH"
```

**Schema version assertion:** Check `schema_version` in the JSON output. If it
is not `"1"`, stop immediately:

> Error: detect.sh schema_version mismatch (observed: X, expected: 1).
> Update `skills/claudboard-workflow/scripts/detect.sh`, then re-run.

Read the resolved boolean flags: `mcp.tracker_jira`, `mcp.tracker_tr`,
`mcp.repo_ado`, `mcp.repo_github`. Surface any `mcp.warnings` entries to the
user before proceeding.

**If `mcp.ambiguities` is non-empty**, resolve each conflicting dimension:

_Tracker dimension conflict:_
```
Two tracker MCPs detected. Which should the generated workflow target?
[1] Atlassian Jira         (detected in: <source path>)
[2] Bosch Track & Release  (detected in: <source path>)
```
Set the chosen flag true, the other false. Record "chosen via prompt".

_Repo dimension conflict:_
```
Two repo MCPs detected. Which should the generated workflow target?
[1] Azure DevOps  (detected in: <source path>)
[2] GitHub        (detected in: <source path>)
```
Set the chosen flag true, the other false. Record "chosen via prompt".

**Halt-on-conflict guard:** After resolution, if both flags in either dimension
are still true:
```
Error: precedence resolution failed — both flags in the [tracker|repo] dimension
are true after resolution. Cannot generate a deterministic workflow. Aborting.
```

**No-backend warnings** (accumulate for completion report):
- Neither tracker: `⚠ No tracker MCP detected. Generated feature-workflow has no ticket integration. Configure Jira MCP or T&R MCP, then re-run.`
- Neither repo: `⚠ No repo MCP detected. Generated feature-workflow has no PR creation. Configure ADO MCP or GitHub MCP, then re-run.`

Record detection state (flag + source + resolution) for the Phase 7 MCP detection table.

**Fallback (detect.sh unavailable):** Read `.mcp.json`, `~/.claude/mcp_servers.json`,
`~/.claude.json`. Match server names/args: Jira (atlassian/jira/confluence, `@atlassian/`),
T&R (bosch-jira-mcp/bosch-jira, `bosch-jira-mcp`), ADO (azure-devops/ado,
`azure-devops-mcp`/`@microsoft/azure`), GitHub (github,
`github-mcp-server`/`@modelcontextprotocol/server-github`). Apply project-level
precedence. Run ambiguity prompts and conflict guard as above.

---

## Phase 2: Config Gathering

Gather values for `config.json` and substitution variables. Work through each
source in order — auto-detect first, inherit from siblings second, prompt last.

### 2a. Auto-detect from git remote

Read the `git_remote` block from the detect.sh output (Phase 1d):

- `provider`: `"azure-devops"`, `"github"`, or `null`
- When ADO: `azure_devops.org`, `azure_devops.project`, `azure_devops.repo` → set as `azureDevOps.org`, `azureDevOps.project`, `azureDevOps.repositoryName`
- When GitHub: `github.owner`, `github.repo` → set directly; record `github.linkingKeyword = "Closes"` as default

Inform the user of what was auto-detected before moving on. Unrecognised or
missing remote URLs leave the affected fields for Phase 2c prompting.

**Fallback (detect.sh unavailable):** Run `git remote -v` and parse manually.
ADO: `https://dev.azure.com/{org}/{project}/_git/{repo}` (modern) or
`https://{org}.visualstudio.com/{project}/_git/{repo}` (legacy). GitHub:
`git@github.com:{owner}/{repo}[.git]` or `https://github.com/{owner}/{repo}[.git]`.

### 2b. Sibling-repo inheritance

Read the `siblings` array from the detect.sh output (Phase 1d).

If `siblings` is non-empty, load `references/sibling-inheritance.md` for the
field allowlist and exact inheritance offer wording, then present the offer.

After the user accepts, mark all inheritable fields from the chosen sibling's
`config_summary` as resolved. Proceed to Phase 2c for any remaining unresolved
fields.

**Fallback (detect.sh unavailable):** Enumerate `../*/` manually for
`.claude/skills/feature-workflow/config.json`, then follow sibling-inheritance.md.

### 2c. Prompt for remaining fields

**Reference load gates** (load before prompting the relevant fields):

- Load `references/tracker-config-prompts.md` only when
  `(mcp.tracker_jira OR mcp.tracker_tr)` AND `unresolved.tracker` is non-empty.
- Load `references/repo-config-prompts.md` only when
  `(mcp.repo_ado OR mcp.repo_github)` AND `unresolved.repo` is non-empty.

For each `config.json` field not resolved by auto-detect or inheritance, prompt
the user using the exact text and defaults from the loaded reference file.
Every prompt must offer a "stub with TODO" escape:

> Type 's' to stub with [TODO: FIELD_NAME] and continue.

Skip all fields for a backend when its flag is false.

**Shared git fields (always prompted):**

| Field | Default |
|-------|---------|
| `git.branchTypes` | `["feature","bugfix","hotfix"]` |
| `git.branchPattern` | `{type}/{ticket}/{slug}` if either tracker active, else `{type}/{slug}` |
| `git.ticketRegex` | `[A-Z]+-[0-9]+` |

---

## Phase 3: Capability-Flag Resolution

Load `references/block-catalog.md` at the start of Phase 3. Resolve all v1
capability flags per the catalog's resolution table. The four MCP flags
(`TRACKER_JIRA`, `TRACKER_TR`, `REPO_ADO`, `REPO_GITHUB`) are already set from
Phase 1d.

**Missing Workflow Signals:** Default `WORKSPACE_MODE`, `CROSS_SERVICE_EDGES`,
`SHARED_LIB`, `AUTH_PERIMETER`, `RABBITMQ`, `JMS`, `GRAPHQL`, `WEBSOCKET` to
`false` and note "defaulted off (no workflow signals)".

**Missing Architectural Patterns subsection:** Default `SAGA`, `CQRS`, `OUTBOX`,
`CIRCUIT_BREAKER` to `false`; emit: "patterns subsection absent — re-run `/analyse`".

Record every resolved flag value and its evidence source for display in Phase 5.

---

## Phase 4: Substitution Resolution

Load `references/substitution-catalog.md` at the start of Phase 4. For each
`{{VAR_NAME}}` token found in a template:

1. Read the source field from the analysis report (per catalog).
2. If present and non-empty, use its value.
3. If absent or empty, apply the catalog-defined fallback.
4. If still unresolvable, use `[TODO: VAR_NAME]` and record a warning.

For WORKSPACE_MODE-specific variables, resolve as empty string when
`WORKSPACE_MODE = false` unless used in an always-on section.

---

## Phase 5: Confirmation Gate

Before writing any files, present a complete summary and wait for user approval.

```
## claudboard-workflow — Ready to Generate

### Files to write:
  $SKILL_TARGET  (= .claude/skills/feature-workflow/ or workspace equivalent)
  SKILL.md, config.json, references/claude-pricing.md, references/ticket-description-template.md
  references/pricing.md, references/cost-tick.md
  scripts/: lib.sh, prepare-*.sh, compute-cost.sh, [jira-add-labels.sh if TRACKER_JIRA], [load-repo-context.sh if WORKSPACE_MODE]
  agents/: architect, design-reviewer, git, implementation, sdd-expert, spec-reviewer
           [jira-agent if TRACKER_JIRA] [tr-agent if TRACKER_TR]
           [pr-agent-ado if REPO_ADO] [pr-agent-github if REPO_GITHUB]

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
confirmation gate, run `find <workspace> -maxdepth 3 -type d -name "feature-workflow" -path "*/.claude/skills/*" ! -path "<workspace>/.claude/*"` and record any hits. List them in the completion report — NOT auto-deleted.

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
cp "$TEMPLATE_DIR/scripts/lib.sh"                                   "$SKILL_TARGET/scripts/"
cp "$TEMPLATE_DIR/scripts/prepare-commit.sh"                        "$SKILL_TARGET/scripts/"
cp "$TEMPLATE_DIR/scripts/prepare-pr.sh"                            "$SKILL_TARGET/scripts/"
cp "$TEMPLATE_DIR/scripts/prepare-squash.sh"                        "$SKILL_TARGET/scripts/"
cp "$TEMPLATE_DIR/scripts/compute-cost.sh"                          "$SKILL_TARGET/scripts/"
chmod +x "$SKILL_TARGET/scripts/compute-cost.sh"
cp "$TEMPLATE_DIR/references/claude-pricing.md"                     "$SKILL_TARGET/references/"
cp "$TEMPLATE_DIR/references/ticket-description-template.md"        "$SKILL_TARGET/references/"
cp "$TEMPLATE_DIR/references/pricing.md"                            "$SKILL_TARGET/references/"
cp "$TEMPLATE_DIR/references/cost-tick.md"                          "$SKILL_TARGET/references/"
```

Conditional copies — run each `cp` only when the corresponding flag is `true`:

| Flag | File |
|------|------|
| `TRACKER_JIRA` | `cp "$TEMPLATE_DIR/scripts/jira-add-labels.sh" "$SKILL_TARGET/scripts/"` |
| `WORKSPACE_MODE` | `cp "$TEMPLATE_DIR/scripts/load-repo-context.sh" "$SKILL_TARGET/scripts/"` |

Verify that all expected files exist after the copy:

```bash
ls -la "$SKILL_TARGET/scripts/" "$SKILL_TARGET/references/"
ls -la "$SKILL_TARGET/agents/"  # conditional files only
```

### 6b. Template rendering algorithm

For each `.template` file:

**Step 0 — INCLUDE expansion:** Scan for `{{INCLUDE <path>}}` directives; resolve
relative to `$TEMPLATE_DIR`; replace each with verbatim file contents (warn and
replace with `<!-- WARNING: INCLUDE file not found: <path> -->` if missing).
Run before Steps 1 and 2 so included content may contain IF blocks and VAR tokens.

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

| Template file | Output file | Condition |
|---------------|-------------|-----------|
| `SKILL.md.template` | `SKILL.md` | always |
| `config.json.template` | `config.json` | always |
| `agents/architect-agent.md.template` | `agents/architect-agent.md` | always |
| `agents/design-reviewer.md.template` | `agents/design-reviewer.md` | always |
| `agents/git-agent.md.template` | `agents/git-agent.md` | always |
| `agents/implementation-agent.md.template` | `agents/implementation-agent.md` | always |
| `agents/sdd-expert-agent.md.template` | `agents/sdd-expert-agent.md` | always |
| `agents/spec-reviewer.md.template` | `agents/spec-reviewer.md` | always |
| `agents/jira-agent.md.template` | `agents/jira-agent.md` | `TRACKER_JIRA = true` |
| `agents/tr-agent.md.template` | `agents/tr-agent.md` | `TRACKER_TR = true` |
| `agents/pr-agent-ado.md.template` | `agents/pr-agent-ado.md` | `REPO_ADO = true` |
| `agents/pr-agent-github.md.template` | `agents/pr-agent-github.md` | `REPO_GITHUB = true` |

All output paths are relative to `$SKILL_TARGET`. Verbatim files are listed in
the 6a bash block and must not be read into context.

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
  [list each file actually written under $SKILL_TARGET, one per line]

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
bosch-jira-mcp (6 tools) has no create/worklog/sprint-write. Use existing
ticket key; sprint and AC write into description body; labels via
read-modify-write. Each limitation lifts when the missing tool lands in the MCP.

### Config stubs (fields left as TODO — fill before first use):

[list any [TODO: ...] placeholders written to config.json with hints for where
to find the correct values]

Clarification autonomy default set to `{{CLARIFY_AUTONOMY_DEFAULT}}` (override per-invocation or edit `clarify.defaultAutonomy` in `config.json`).

Live per-phase cost ticks enabled — `compute-cost.sh` and `pricing.md` bundled into `scripts/` and `references/`; a one-line cost summary is emitted at the end of each of phases 1–6, with reconciliation in Phase 7b.

**Next steps:** Try `/start-feature` on a small ticket to validate the wiring.
```

**Workspace-mode completion report additions (append when WORKSPACE_MODE=true):**

```
### Workspace skill location
  Generated into: <workspace>/.claude/skills/feature-workflow/
  Resolved via:   <meta-repo-path>/.claude/skills/feature-workflow/

  Stub all [TODO: repositoryId] entries in config.json before first use.
  After review: cd <meta-repo-path> && git add .claude/skills/feature-workflow/ && git commit && git push

### Per-repo feature-workflow skills found (not auto-deleted):
  [listed paths — remove manually: rm -rf <path>]

### Validation: /start-feature [small cross-service feature] from workspace root
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

## Reference Load Gates

Load these references only when their gate condition is met. Loading early wastes
tokens on content the model won't use.

| Reference | Load when |
|-----------|-----------|
| `references/block-catalog.md` | Start of Phase 3 (render time) only |
| `references/substitution-catalog.md` | Start of Phase 4 (render time) only |
| `references/tracker-config-prompts.md` | `(tracker_jira OR tracker_tr)` AND `unresolved.tracker` non-empty |
| `references/repo-config-prompts.md` | `(repo_ado OR repo_github)` AND `unresolved.repo` non-empty |
| `references/sibling-inheritance.md` | `siblings` array non-empty (load before Phase 2b offer) |
| `references/feature-workflow.template/*` | Phase 6 render — load individual templates on demand |
