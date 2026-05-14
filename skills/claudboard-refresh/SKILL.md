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

### 2d. Prior analysis report
- Check for `.claude/reports/claudboard-analysis.md`
- If found: read `generated_at` timestamp for delta comparison and check `monorepo: true` in frontmatter
- **Monorepo:** also list all `claudboard-analysis-<name>.md` files — these represent the previously detected services. Record service names (derived from filenames) as the prior service list.

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

**Workspace mode refresh behavior** (tasks 7.1-7.4):

Workspace mode is detected when:
- CWD contains subdirectories with independent `.git/` repos AND each has a build file
- OR: prior analysis report exists with `workspace: true` in frontmatter (to be added in future — for now, detect by CWD structure)

**Workspace-level refresh** (task 7.1, CWD is workspace root):

When `/refresh` is run from the workspace root (directory containing multiple repos with `.git/`):

1. Re-run per-repo surface extraction:
   - Follow `../claudboard/references/stack-detectors.md` → "Cross-Service Surface Detection"
   - For each service repo: extract service identity, outbound REST/Kafka/Solace, inbound REST/Kafka/Solace
   - Record surface data for graph construction

2. Re-run Phase 1c from analyse skill (graph construction):
   - Match outbound references against inbound surfaces across all repos
   - Classify coupling strength (TIGHT/MODERATE/LOOSE)
   - Detect synchronous chains and circular dependencies
   - Present updated graph to user for confirmation

3. **Completely overwrite** all `<repo>/.claude/memories/ecosystem.md` files with current graph data:
   - Each service's Role, Depends On, Used By, Shared Contracts, Coupling Warnings sections
   - Skip library repos and workspace root (no ecosystem.md written there)

4. **New-service detection** (task 7.2):
   - Compare current repo list against prior analysis (if prior report exists)
   - If a new repo directory appears that was not in the prior analysis:
     - Flag: "New repo detected: {dir-name}. Run `/analyse` from workspace root to include it in the ecosystem graph."
   - Do not attempt to analyse the new repo during refresh — full `/analyse` required for cross-service context

**Service-level refresh** (task 7.3, CWD is a single service repo):

When `/refresh` is run from within a single service repo directory:

1. Check for sibling repos at parent level (same check as right-level detection in analyse):
   - Scan `../` for directories with build files + `.git/`
   - If N≥2 siblings found → workspace context exists

2. If workspace context exists:
   - Re-run surface extraction for this service only (follow `../claudboard/references/stack-detectors.md` → "Cross-Service Surface Detection")
   - Update this service's `ecosystem.md` from its own outbound perspective:
     - **Depends On** section: re-derive from current outbound calls
     - **Shared Contracts** section: update published topics from current code
     - **Used By and Coupling Warnings**: cannot be updated (requires full workspace graph) — leave existing content
   - Display stale warning:
     ```
     Updated ecosystem context for this service.
     
     ⚠ Warning: Ecosystem files in sibling services may be stale:
     • user-service/.claude/memories/ecosystem.md
     • notification-service/.claude/memories/ecosystem.md
     
     Run `/refresh` from workspace root to sync all services.
     ```

3. **No-workspace-context case** (task 7.4):
   - If no sibling repos detectable at parent level (workspace context does not exist)
   - Proceed with normal service-level refresh (delta discovery against existing rules/skills)
   - Do not attempt ecosystem updates or warnings

---

## Phase 4: Gap Analysis Report

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

## Phase 5: Selective Generation

Apply only the confirmed updates. Load references as needed:
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

Overwrite `.claude/reports/claudboard-analysis.md` with a fresh full analysis (combining prior report data with new discoveries). Update `generated_at` timestamp.

---

## Error Handling

| Condition | Behavior |
|-----------|----------|
| Target path doesn't exist | Report error with path and stop |
| No existing `.claude/` context found | Tell user to run `/analyse` first, stop |
| Prior analysis report malformed/unreadable | Ignore it, run abbreviated Wide Scan as if no prior report |
| Git history unavailable | Skip git-based delta detection, run full Wide Scan comparison instead |

## Constraints

- **Write only to `.claude/` and project-root CLAUDE.md.**
- **Never modify source code, tests, or any existing file outside `.claude/`.**
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
