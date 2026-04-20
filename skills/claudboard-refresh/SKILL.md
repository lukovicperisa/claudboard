---
name: claudboard-refresh
description: >
  Refreshes Claude Code artifacts for a project that already has .claude/ context.
  Performs delta discovery against existing artifacts, identifies what's new, stale,
  or missing, and updates only what changed.
  Use when: /refresh, "update my rules", "refresh Claude context", "sync .claude/
  with codebase changes", "what's changed since last scan", "are my rules up to
  date", "re-scan this project".
---

# Refresh — Delta Update for Existing Projects

For projects that already have `.claude/` artifacts. Compares current codebase state against existing artifacts and updates only the delta.

## Invocation

```
/refresh [path]
```

Path defaults to the current working directory.

---

## Step 1: Prerequisite Check

Verify the project has existing Claude context — at least one of:
- `CLAUDE.md` at project root
- `.claude/rules/*.md`
- `.claude/skills/*/SKILL.md`

**If none found:** Tell the user: "No existing Claude context found. Run `/analyse` to scan the codebase first, then `/generate` to create artifacts." Stop here.

---

## Step 2: Inventory Existing Artifacts

Read all existing Claude artifacts and build a coverage map:

### 2a. CLAUDE.md
- Read `CLAUDE.md` — note which sections exist (Commands, Architecture, Rules/Skills tables, Critical Rules)
- Note any TODOs or incomplete sections

### 2b. Rules
- List all `.claude/rules/*.md`
- For each: read the `paths:` frontmatter globs and the content summary
- Map: which languages/areas are covered

### 2c. Skills
- List all `.claude/skills/*/SKILL.md`
- For each: read the `name:` and `description:` frontmatter
- Note which have `references/` and `scripts/` subdirs

### 2d. Prior analysis report
- Check for `.claude/reports/claudboard-analysis.md`
- If found: read `generated_at` timestamp for delta comparison

---

## Step 3: Delta Discovery

Load `../claudboard/references/stack-detectors.md` for detection heuristics.

### 3a. Find what changed

**If prior report exists** (has `generated_at` timestamp):
- Use `git log --oneline --since=<generated_at>` to gauge change volume
- Use `git diff --name-only <generated_at_approx_commit>..HEAD` or `git diff --stat` to find changed areas
- Focus discovery on changed directories/files only

**If no prior report:**
- Run lightweight Phase 1 discovery (same as `/analyse` Phase 1 but abbreviated):
  - Run Wide Scan (step 1c) — grep-based inventory of whole repo
  - Check structure, build files, new directories, dependency changes
  - Skip deep strategic sampling (no baseline to compare against — do full `/analyse` instead)

### 3b. Check for drift

Compare Wide Scan results against existing artifacts:

- **New dependencies** added to build files not mentioned in rules
- **New directories/modules** not covered by any rule's `paths:` globs
- **New base classes** (Wide Scan inheritance map) not covered by any skill
- **New custom annotations** (Wide Scan) not documented in rules
- **New skill trigger signals** (Wide Scan) not covered by existing skills
- **Removed or renamed files** that existing rules/skills reference
- **Changed CI/CD config** not reflected in CLAUDE.md commands
- **New test frameworks** or test directories
- **New anti-patterns** (Wide Scan God class candidates, reflection, broad catches) not in tech-debt rule
- **New patterns** (e.g., new DI approach, new error handling) not documented in rules

---

## Step 4: Gap Analysis Report

Load `../claudboard/references/pattern-catalog.md` and `../claudboard/references/quality-signals.md` for assessment.

Present findings in delta format:

```
## Refresh Report: <repo-name>
**Last analysis:** <date from prior report, or "none">
**Changes since:** <N commits, M files changed>

### New (not covered by existing artifacts)
- <new module/directory> — needs rule or skill coverage
- <new dependency/framework> — not documented in CLAUDE.md
- <new pattern detected> — should be in rules

### Stale (artifacts reference things that changed)
- `<rule file>` — references <pattern/path> which has been modified
- `CLAUDE.md` — <section> is outdated (e.g., command changed)
- `<skill>` — references files that moved/renamed

### Missing (should exist based on codebase signals)
- No rule for <language/area> despite <N> source files
- No skill for <repetitive workflow> despite boilerplate pattern

### Up to Date (no action needed)
- `<rule>` — still accurate
- `<skill>` — still matches codebase

### Proposed Updates
**CLAUDE.md:** [specific additions/changes]
**Rules:** [new/update list with adaptive depth]
**Skills:** [new/update list]

---
Apply these updates? [y/n/selective]
If selective: which parts should I apply?
```

**Pause here.** Wait for user confirmation.

---

## Step 5: Selective Generation

Apply only the confirmed updates. Load references as needed:
- `../claudboard/references/claude-md-template.md` → for CLAUDE.md updates
- `../claudboard/references/rule-templates.md` → for new/updated rules
- `../claudboard/references/skill-generation.md` → for new/updated skills

### Rules for delta generation:
- **New artifacts:** Create using same process as `/generate`
- **Stale artifacts:** Read existing file, append or update specific sections — never full rewrite
- **Existing content:** Preserve untouched — merge, don't replace
- **Adaptive depth:** Same as `/generate` (based on quality signals)

### Completion

```
## Refresh Complete

Updated:
- CLAUDE.md [updated — added N lines]
- Rules: [list of new/updated]
- Skills: [list of new/updated]

Unchanged:
- [list of artifacts that needed no update]

Next refresh: run `/refresh` after significant codebase changes
```

---

## Step 6: Save Updated Report

Overwrite `.claude/reports/claudboard-analysis.md` with a fresh full analysis (combining prior report data with new discoveries). Update `generated_at` timestamp.

---

## Constraints

- **Write only to `.claude/` and project-root CLAUDE.md.**
- **Never modify source code, tests, or any existing file outside `.claude/`.**
- **Merge, don't replace** — always preserve existing artifact content.
- **Delta-first** — never regenerate from scratch; update only what changed.
- **Secrets:** Never include secret values in generated artifacts.

## Reference Files

| File | When to load |
|------|-------------|
| `../claudboard/references/stack-detectors.md` | Step 3 — delta discovery |
| `../claudboard/references/pattern-catalog.md` | Step 4 — pattern identification |
| `../claudboard/references/quality-signals.md` | Step 4 — quality assessment |
| `../claudboard/references/claude-md-template.md` | Step 5 — CLAUDE.md updates |
| `../claudboard/references/rule-templates.md` | Step 5 — rule generation |
| `../claudboard/references/skill-generation.md` | Step 5 — skill generation |
