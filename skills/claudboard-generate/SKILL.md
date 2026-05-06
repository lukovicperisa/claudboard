---
name: claudboard-generate
description: >
  Generates Claude Code artifacts (CLAUDE.md, rules, full-scope skills) from a
  claudboard analysis report. Reads .claude/reports/claudboard-analysis.md and
  produces production-ready .claude/ artifacts tailored to the project's actual
  patterns. Requires a prior `/analyse` run — does not analyse inline.
  Use when: /generate, "generate rules", "create CLAUDE.md", "bootstrap Claude
  for this repo", "generate skills for this project", "set up Claude Code for
  this project", "onboard this project".
---

# Generate — Artifact Generation from Analysis

Reads a claudboard analysis report and generates Claude Code artifacts: CLAUDE.md, rules, and full-scope skills.

## Invocation

```
/generate [path]
```

Path defaults to the current working directory.

---

## Phase 1: Load Analysis Report

**Recommendation:** Run this skill in a fresh Claude Code session for best results. The analysis phase fills context with discovery data that isn't needed for generation — a clean session gives better output quality.

Look for `.claude/reports/claudboard-analysis.md` in the target project.

**If found:**
- Read the report
- Check `generated_at` in frontmatter — if older than 24 hours, warn: "Analysis report is N days old. Consider running `/analyse` first for fresh results."
- Validate structure: check that "Proposed Artifacts" section exists. If missing, tell user: "Analysis report is incomplete or malformed — missing 'Proposed Artifacts' section. Run `/analyse` again to regenerate." Stop here.
- **Check for monorepo mode:** look for `claudboard-analysis-*.md` files alongside the global report. If found, read each per-service report. Validate each: if a per-service report is missing "Proposed Artifacts", warn "Service report for <name> is incomplete — skipping that service. Re-run `/analyse` to regenerate." and continue with remaining services.
- Display a summary of the Proposed Artifacts section (global + per-service if monorepo)

**If not found:**
- Tell the user: "No analysis report found. Run `/analyse` first to scan the codebase, then `/generate` to create artifacts."
- Stop here. Do not run analysis inline — the two-step workflow ensures the user reviews findings before generation.

---

## Phase 2: Confirmation

Show the Proposed Artifacts from the report. If the report contains skill dedup decisions (merged or separated skills), preserve those decisions — don't re-evaluate.

```
## Artifacts to Generate

**CLAUDE.md** — [create/update] — [outline]

**Rules (N files):**
- `<filename>.md` (paths: `<glob>`) — <depth: full/medium/skeleton>

**Skills (M files):**
- `<skill-name>/` — <SKILL.md + references/ + scripts/>

[If existing .claude/ found:]
**Already covered (skipping):**
- `<existing artifact>` — no gaps

---
Generate these artifacts? [y/n]
If n: which parts should I skip or change?
```

**Pause here.** Wait for user confirmation before proceeding.

---

## Phase 3: Generate Artifacts

Write files to `.claude/` in the target project. Never write outside `.claude/` (except CLAUDE.md at project root). Never modify existing source files.

Load these references as needed:
- `../claudboard/references/claude-md-template.md` → for CLAUDE.md structure
- `../claudboard/references/rule-templates.md` → for rule file templates
- `../claudboard/references/skill-generation.md` → for full-scope skill generation

### 3a. Generate or update CLAUDE.md

Follow `../claudboard/references/claude-md-template.md` exactly.

**Single-project:** Use the standard template. Target 60-120 lines.

**Monorepo:** Use the monorepo variant template from `claude-md-template.md`. Target 80-150 lines. Include:
- Services table (name, stack, directory, purpose)
- Shared libraries table (name, directory, consumers)
- Per-service build/test commands grouped by service
- Global conventions (branch, commit, CI/CD)
- Critical Rules section covering cross-service concerns

**Workspace (multi-repo):** Generate CLAUDE.md per service repo (not at workspace level). For each service:
- Use standard single-project template as base
- Add **Ecosystem** section (task 6.8):
  ```markdown
  ## Ecosystem
  
  This service is part of [project/workspace name if detectable]. Cross-service dependencies and coupling analysis: `.claude/memories/ecosystem.md` (auto-loaded).
  ```
- Do not duplicate ecosystem.md content in CLAUDE.md — the memory file is auto-loaded by Claude Code

**If CLAUDE.md exists:** Read it, add only gaps — new commands, new architecture notes, new rules/skills table entries, new critical rules, ecosystem reference (workspace mode). Do not rewrite.

**If new:** Generate from scratch using detected values for every field.

Write to: `<project>/CLAUDE.md` (project root, not inside `.claude/`)

### 3b. Generate rules

For each rule to generate, follow `../claudboard/references/rule-templates.md` → appropriate template. Fill all placeholders with values from actual source code — never use generic examples.

**Adaptive depth** (from quality score average in the analysis report):
- Average ≥7.0 → full rules (80-120 lines) with real code examples from sampled files
- Average 4.0-6.9 → medium rules (50-70 lines)
- Average <4.0 → skeleton rules (30-50 lines) with TODO markers

**Single-project:** Standard rules with `paths:` globs covering the whole codebase.

**Monorepo:**
- **Per-service rules:** `rules/<service-name>-conventions.md` with `paths: ["<service-dir>/**"]`. Use each service's own adaptive depth (from its per-service quality score). Use the service's directory name as-is for the filename.
- **Global rules (no `paths:`):** `rules/ci-cd.md`, `rules/gitops.md`, etc. — for CI/CD, deployment, and cross-service conventions that apply everywhere.
- If two services share identical conventions, they may share one rule file with multiple `paths:` entries: `paths: ["service-a/**", "service-b/**"]`.

Write to: `<project>/.claude/rules/<name>.md`

**If rule file exists:** Read it, add only what's missing. Append new sections. Never overwrite.

### 3c. Generate full-scope skills

For each skill, follow `../claudboard/references/skill-generation.md` → full-scope skill structure.

**Every generated skill includes:**
- `SKILL.md` (100-250 lines): architecture diagram specific to this project, step-by-step workflow, real code examples extracted from actual codebase files
- `references/` dir: at minimum one template file matching detected conventions; add annotated example from real code
- `scripts/scaffold.sh` if the skill creates 3+ boilerplate files with predictable naming

**Adaptive depth:** Full for clean codebases, skeleton+ask for inconsistent patterns.

**Monorepo:** If a skill is proposed from a per-service report, scope it to that service's directory. Reference only that service's conventions and code examples in the skill content.

Write to: `<project>/.claude/skills/<name>/`

**If skill exists:** Add only missing components. If same domain, extend. If naming collision, warn user.

### 3d. Completion report

```
## Generation Complete

Generated:
- CLAUDE.md [created/updated — N lines]
- Rules: [list with adaptive depth used]
- Skills: [list, each with: SKILL.md ✓, references/ ✓/✗, scripts/ ✓/✗]

Next steps:
- Review generated artifacts and adjust to team preferences
- Run `/refresh` as the project evolves to keep artifacts current
- Flesh out any TODO sections in skeleton rules or skills
- Try the suggested validation tasks below to verify artifacts work
```

### 3e. Validation suggestions

After presenting the completion report, propose 3-5 representative tasks the user can try in a fresh Claude Code session to verify the generated artifacts actually help. Select tasks based on what was detected:

**Task selection** (pick 3-5 from this priority list based on what was generated):

1. **If skills were generated:** "Create a new [entity/component/endpoint] using the generated `[skill-name]` skill" — tests whether the skill workflow produces correct code
2. **If rules cover conventions:** "Modify [file from god-class list or hotspot] — does Claude follow the [DI/logging/error-handling] conventions?" — tests rule loading
3. **If CLAUDE.md has build commands:** "Build and test the project" — tests whether the commands table is accurate
4. **If infra rules generated:** "Add a new [Helm value/pipeline step/Dockerfile]" — tests infrastructure context
5. **If testing rules generated:** "Write tests for [existing untested file]" — tests test convention rules

**Output format:**

```
## Suggested Validation Tasks

Try these in a fresh Claude Code session to verify the artifacts work:

1. [Task description] — validates: [artifact name]
2. [Task description] — validates: [artifact name]
3. [Task description] — validates: [artifact name]

If Claude stumbles on any of these, run `/refresh` to update the artifacts.
```

---

## Error Handling

| Condition | Behavior |
|-----------|----------|
| Target path doesn't exist | Report error with path and stop |
| No analysis report found | Tell user to run `/analyse` first, stop — do not analyse inline |
| Report older than 24 hours | Warn but proceed if user confirms |
| Report contains unresolved ambiguities or "ASK USER" markers | Pause and ask user before generating those artifacts |

## Constraints

- **Never modify source code** — only write to `.claude/` and project-root CLAUDE.md.
- **Merge, don't replace** — when `.claude/` artifacts exist, append or update sections, never delete existing content.
- **Secrets:** Never include secret values in generated artifacts.

## Reference Files

| File | When to load |
|------|-------------|
| `../claudboard/references/claude-md-template.md` | Phase 3a — CLAUDE.md generation |
| `../claudboard/references/rule-templates.md` | Phase 3b — rule file generation |
| `../claudboard/references/skill-generation.md` | Phase 3c — full-scope skill generation |
