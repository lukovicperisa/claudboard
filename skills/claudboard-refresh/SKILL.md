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

## Phase 1: Prerequisite Check

Verify the project has existing Claude context — at least one of:
- `CLAUDE.md` at project root
- `.claude/rules/*.md`
- `.claude/skills/*/SKILL.md`

**If none found:** Tell the user: "No existing Claude context found. Run `/analyse` to scan the codebase first, then `/generate` to create artifacts." Stop here.

---

## Phase 2: Inventory Existing Artifacts

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

### 2d. Prior catalog and analysis report

Check for `.claudboard/catalog.json` first (primary input — all modes). If present, read `umbrella_root` and `generated_at`. All write paths use `<umbrella_root>/.claude/`.

Fall back to `.claude/reports/claudboard-analysis.md` (legacy) if catalog absent. In workspace mode without a catalog, look for `cloudboard-analysis.md` at the workspace root's `.claude/reports/` rather than per-repo paths.

**Legacy per-repo reports** (`claudboard-analysis-<repo>.md`) are NOT read by `/refresh` after this change — they are superseded by the unified catalog. They remain on disk as read-only history.

---

## Phase 3: Delta Discovery

Load `../claudboard/references/stack-detectors.md` for detection heuristics.

### 3a. Find what changed

**If prior report exists** (has `generated_at` timestamp):
- Use `git log --oneline --since=<generated_at>` to gauge change volume
- Use `git diff --name-only <generated_at_approx_commit>..HEAD` or `git diff --stat` to find changed areas
- Focus discovery on changed directories/files only

**If no prior report:**
- Run abbreviated Phase 1 discovery (Wide Scan only, no deep file reading):
  - 1a: Parallel file detection (build files, CI/CD, container, infra, docs)
  - 1b: Structure mapping (top-level dirs, monorepo detection)
  - 1c: Wide Scan — grep-based pattern inventory (inheritance, triggers, anti-patterns, conventions)
  - Skip strategic sampling, call-path tracing, and duplication detection (no baseline to compare against — those require full `/analyse`)
  - Goal: build a coverage map to compare against existing artifacts, not a full analysis

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

**Monorepo service topology drift** (if prior report has `monorepo: true`):
- Re-run monorepo detection (see `../claudboard/references/stack-detectors.md` → "Monorepo Detection & Service Classification")
- Compare current detected services against prior service list (from `cloudboard-analysis-*.md` filenames):
  - Build root present now but no matching report → flag: `"New service detected: {dir-name}. Run /analyse to include it."`
  - Report exists but build root directory is gone → flag: `"Service removed: {dir-name}. Stale report and rules can be deleted."`
  - Directory renamed (heuristic: same stack detected in different directory, old directory gone) → flag: `"Service appears renamed: {old-name} → {new-name}. Re-run /analyse to update."`

**Workspace mode refresh behavior:**

Workspace mode is detected when CWD contains subdirectories with independent `.git/` repos AND each has a build file, or from `catalog.mode == "workspace"`.

**Workspace-level refresh (CWD is workspace root):**

1. Re-run per-service surface extraction:
   - Follow `../claudboard/references/stack-detectors.md` → "Cross-Service Surface Detection"
   - For each service repo: extract service identity, outbound REST/Kafka/Solace, inbound REST/Kafka/Solace

2. Re-run graph construction (same as `/analyse` Phase 1i):
   - Match outbound against inbound, classify coupling, detect chains/circles
   - Present updated graph for user confirmation

3. **Overwrite umbrella ecosystem.md** at `<umbrella_root>/.claude/memories/ecosystem.md` with current graph data. This is the ONLY ecosystem.md that exists — there are no per-service copies to update.

4. **New-service detection:**
   - If a new service directory appears not in the prior catalog: flag "New service detected: {dir-name}. Re-run `/analyse` to include it in the catalog and ecosystem."
   - Do not analyse the new service inline — full `/analyse` required.

5. **Per-service CLAUDE.md update** (when catalog indicates a service's role or stack changed):
   - Update the relevant `<service-dir>/CLAUDE.md` — only changed sections.

**Service-level refresh (CWD is a single service repo):**

If `/refresh` is run from within a service subdirectory, check for workspace context (sibling repos with `.git/`). If workspace context exists, warn: "Run `/refresh` from the workspace root to update the ecosystem graph. Service-level refresh cannot update `<umbrella_root>/.claude/memories/ecosystem.md` without the full workspace context." Then proceed with delta discovery for that service's rules and CLAUDE.md only.

---

## Phase 4: Pre-write summary

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
```

I'll proceed now — interrupt with Esc to abort or adjust.

---

## Phase 5: Generation

Apply all proposed updates. Load references as needed:
- `../claudboard/references/claude-md-template.md` → for CLAUDE.md updates
- `../claudboard/references/rule-templates.md` → for new/updated rules
- `../claudboard/references/skill-generation.md` → for new/updated skills

### Exclusion: feature-workflow skill

`/claudboard-refresh` SHALL NOT modify, overwrite, or delete the `.claude/skills/feature-workflow/` directory or any of its contents in v1.

If `.claude/skills/feature-workflow/` is detected during inventory (Phase 2c), note it in the refresh report as:

> **Skipped:** `.claude/skills/feature-workflow/` — upgrade path is opt-in via future `/claudboard-workflow --upgrade`

To regenerate or upgrade the feature-workflow skill, remove the directory manually and re-run `/claudboard-workflow`.

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
For tech debt analysis and refactoring tickets: run `/techdebt`
```

---

## Phase 6: Save Updated Report

Overwrite `<umbrella_root>/.claude/reports/claudboard-analysis.md` (all modes — single-project, monorepo, workspace) with a fresh summary combining prior data with new discoveries. Update `generated_at` timestamp.

Do NOT write per-repo or per-service report files. The unified umbrella report is the single source of truth.

**Legacy per-repo reports** (`<workspace>/.claude/reports/cloudboard-analysis-<repo>.md`) left by prior versions are NOT updated and NOT deleted. They remain on disk as read-only history. A future `--prune-stale` flag will handle cleanup.

---

## Error Handling

| Condition | Behavior |
|-----------|----------|
| Target path doesn't exist | Report error with path and stop |
| No existing `.claude/` context found | Tell user to run `/analyse` first, stop |
| Prior analysis report malformed/unreadable | Ignore it, run abbreviated Wide Scan as if no prior report |
| Git history unavailable | Skip git-based delta detection, run full Wide Scan comparison instead |

## Constraints

- **Write only to `<umbrella_root>/.claude/`, `<umbrella_root>/CLAUDE.md`, and `<umbrella_root>/<service>/CLAUDE.md`.**
- **No per-service `.claude/` writes** — NEVER write to `<service>/.claude/skills/`, `<service>/.claude/rules/`, or `<service>/.claude/memories/` under any mode. These per-service directories are not updated by `/refresh`; they simply stop receiving updates.
- **Legacy per-service `.claude/` directories are left untouched** — they were produced by prior `/generate` versions and do no runtime harm (they were never loaded). Users may delete them at leisure. Future `--prune-stale` flag will automate cleanup.
- **Never modify source code, tests, or any existing file outside the above paths.**
- **Merge, don't replace** — always preserve existing artifact content.
- **Delta-first** — never regenerate from scratch; update only what changed.
- **Secrets:** Never include secret values in generated artifacts.
- **Never modify `.claude/skills/feature-workflow/`** — generated by `claudboard-workflow`, upgrade is opt-in.

## Reference Files

| File | When to load |
|------|-------------|
| `../claudboard/references/stack-detectors.md` | Step 3 — shared detection heuristics |
| `../claudboard/references/stack-detectors-{lang}.md` | Step 3 — language-specific patterns if full Wide Scan needed |
| `../claudboard/references/pattern-catalog.md` | Step 4 — pattern identification |
| `../claudboard/references/quality-signals.md` | Step 4 — quality assessment |
| `../claudboard/references/claude-md-template.md` | Step 5 — CLAUDE.md updates |
| `../claudboard/references/rule-templates.md` | Step 5 — rule generation |
| `../claudboard/references/skill-generation.md` | Step 5 — skill generation |
