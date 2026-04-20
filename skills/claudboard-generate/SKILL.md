---
name: claudboard-generate
description: >
  Generates Claude Code artifacts (CLAUDE.md, rules, full-scope skills) from a
  claudboard analysis report. Reads .claude/reports/claudboard-analysis.md and
  produces production-ready .claude/ artifacts tailored to the project's actual
  patterns. Can run standalone if no report exists (will analyse first).
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

## Step 1: Load Analysis Report

Look for `.claude/reports/claudboard-analysis.md` in the target project.

**If found:**
- Read the report
- Check `generated_at` in frontmatter — if older than 24 hours, warn: "Analysis report is N days old. Consider running `/analyse` first for fresh results."
- Display a summary of the Proposed Artifacts section

**If not found:**
- Tell the user: "No analysis report found. Run `/analyse` first to scan the codebase, then `/generate` to create artifacts."
- Stop here. Do not run analysis inline — the two-step workflow ensures the user reviews findings before generation.

---

## Step 2: Confirmation

Show the Proposed Artifacts from the report:

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

## Step 3: Generate Artifacts

Write files to `.claude/` in the target project. Never write outside `.claude/` (except CLAUDE.md at project root). Never modify existing source files.

Load these references as needed:
- `../claudboard/references/claude-md-template.md` → for CLAUDE.md structure
- `../claudboard/references/rule-templates.md` → for rule file templates
- `../claudboard/references/skill-generation.md` → for full-scope skill generation

### 3a. Generate or update CLAUDE.md

Follow `../claudboard/references/claude-md-template.md` exactly. Target 60-120 lines.

**If CLAUDE.md exists:** Read it, add only gaps — new commands, new architecture notes, new rules/skills table entries, new critical rules. Do not rewrite.

**If new:** Generate from scratch using detected values for every field.

Write to: `<project>/CLAUDE.md` (project root, not inside `.claude/`)

### 3b. Generate rules

For each rule to generate, follow `../claudboard/references/rule-templates.md` → appropriate template. Fill all placeholders with values from actual source code — never use generic examples.

**Adaptive depth** (from quality-signals scoring in the analysis report):
- 4+ dimensions "Good" → full rules (80-120 lines) with real code examples from sampled files
- 2-3 "Good" → medium rules (50-70 lines)
- <2 "Good" → skeleton rules (30-50 lines) with TODO markers

Write to: `<project>/.claude/rules/<name>.md`

**If rule file exists:** Read it, add only what's missing. Append new sections. Never overwrite.

### 3c. Generate full-scope skills

For each skill, follow `../claudboard/references/skill-generation.md` → full-scope skill structure.

**Every generated skill includes:**
- `SKILL.md` (100-250 lines): architecture diagram specific to this project, step-by-step workflow, real code examples extracted from actual codebase files
- `references/` dir: at minimum one template file matching detected conventions; add annotated example from real code
- `scripts/scaffold.sh` if the skill creates 3+ boilerplate files with predictable naming

**Adaptive depth:** Full for clean codebases, skeleton+ask for inconsistent patterns.

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
```

---

## Constraints

- **Write only to `.claude/` and project-root CLAUDE.md.**
- **Never modify source code, tests, or any existing file outside `.claude/`.**
- **Merge, don't replace** — when artifacts exist, fill gaps only.
- **Secrets:** Never include secret values in generated artifacts.

## Reference Files

| File | When to load |
|------|-------------|
| `../claudboard/references/claude-md-template.md` | Step 3a — CLAUDE.md generation |
| `../claudboard/references/rule-templates.md` | Step 3b — rule file generation |
| `../claudboard/references/skill-generation.md` | Step 3c — full-scope skill generation |
