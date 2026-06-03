---
name: claudboard-generate
description: >
  Generates Claude Code artifacts (CLAUDE.md, rules, full-scope skills) from a
  claudboard convention catalog. Reads .claudboard/catalog.json as primary input;
  falls back to legacy .claude/reports/claudboard-analysis.md with one-time migration.
  Requires a prior `/analyse` run — does not analyse inline.
  Use when: /generate, "generate rules", "create CLAUDE.md", "bootstrap Claude
  for this repo", "generate skills for this project", "set up Claude Code for
  this project", "onboard this project".
---

# Generate — Artifact Generation from Analysis

Reads the convention catalog and generates Claude Code artifacts: CLAUDE.md, rules, and full-scope skills.

**Model tier: Sonnet.** Generation is template-fill on structured catalog input — no cross-document synthesis or pattern discovery. See `monorepo-generation` spec for rationale.

## Invocation

```
/generate [path]
```

Path defaults to the current working directory.

---

## Phase 1: Load Analysis Input

**Recommendation:** Run this skill in a fresh Claude Code session. Analysis fills context with discovery data not needed for generation — a clean session gives better output.

### 1a. Detect mode and locate input

Check for `.claudboard/catalog.json` first. If present, proceed to 1b-catalog. If absent, check for `.claude/reports/claudboard-analysis.md` (legacy migration path, 1c).

All modes (single-project, monorepo, workspace) use the same catalog-driven path. Workspace detection is not special-cased: the catalog's `mode` and `umbrella_root` fields carry all the information needed. Do NOT branch on `mode` for generation logic — use `umbrella_root` (or `repo` if `umbrella_root` absent) as the write root for all artifacts.

### 1b. Load catalog (primary path)

Read `.claudboard/catalog.json`. Assert `schema_version == "1"`:

```
if catalog.schema_version != "1":
    error: "Catalog schema mismatch: got <observed>, expected 1.
            Re-run /analyse to produce a fresh catalog, or check
            that claudboard SKILL.md and catalog-schema.json are
            at the same version."
```

Check `generated_at` — if older than 24 hours, warn: "Catalog is N days old. Consider re-running `/analyse` for fresh results."

Derive `umbrella_root` from catalog (`umbrella_root` field if present, else `repo`). All artifact writes use `<umbrella_root>/.claude/` and `<umbrella_root>/CLAUDE.md` as the base.

Derive mode (UX text only), stacks, conventions, patterns, proposed artifacts, and adaptive depth from catalog fields. Display a summary of `proposed_artifacts`.

### 1c. Legacy migration (no catalog present)

When `.claudboard/catalog.json` is absent AND `.claude/reports/claudboard-analysis.md` is present:

1. Parse the global legacy report and any per-service `cloudboard-analysis-<svc>.md` files best-effort.
2. Extract `proposed_artifacts`, `conventions`, pattern exemplars (`best_example` file references), and stacks from the reports' sections.
3. Set `from_audit: true` if per-service reports are present, else `false`.
4. Write `.claudboard/catalog.json` with `schema_version: "1"` and synthesised fields.
5. Log: "Migrated legacy analysis reports to .claudboard/catalog.json"
6. Proceed with catalog-driven generation from 1b.

Legacy report files are NOT moved, deleted, or modified. Subsequent runs see the catalog and skip migration.

If parsing fails (missing "Proposed Artifacts" section or incompatible format):
- Exit with: "Migration failed: could not parse <file-path>. Run `/analyse` to produce a fresh `.claudboard/catalog.json`."

### 1d. No input found

**If neither catalog nor legacy reports exist:**
- Single-project / monorepo: "No catalog or legacy reports found. Run `/analyse` first to produce `.claudboard/catalog.json`."
- Workspace mode (detected by structure): "No catalog or legacy reports found. Run `/analyse` from the workspace root to produce `.claudboard/catalog.json`. If the workspace is not bootstrapped, run `/claudboard-workspace-init` first."
- Stop here. Do not run analysis inline.

---

## Phase 2: Pre-write summary

Show the Proposed Artifacts from `catalog.proposed_artifacts`. Preserve any dedup decisions encoded in the catalog — don't re-evaluate.

```
## Artifacts to Generate

Write root: <umbrella_root>/.claude/  (mode: <catalog.mode>)

**Umbrella CLAUDE.md** — [create/update] — [outline]

**Per-service CLAUDE.md (N files):**
- `<service-dir>/CLAUDE.md` — ≤30 lines, service-specific, references umbrella ecosystem.md

**Rules (N files):**
- `<name>.md` (paths: `<catalog.stacks[id].applicable_paths>`) — <depth: catalog.adaptive_depth[stack-id]>

**Skills (M files):**
- `<skill-name>/` — <SKILL.md + references/ + scripts/>
  exemplar: catalog.patterns[<id>].exemplar_path
  [Pattern A dispatcher if per-service variations detected]

[If existing .claude/ found:]
**Already covered (skipping):**
- `<existing artifact>` — no gaps

**NOT generated (umbrella-only rule):**
- No writes to <service>/.claude/skills/, <service>/.claude/rules/, or <service>/.claude/memories/
```

I'll proceed now — interrupt with Esc to abort or adjust.

---

## Phase 3: Generate Artifacts

Write files to `<umbrella_root>/.claude/` and `<umbrella_root>/CLAUDE.md`. **Never write to `<umbrella>/<service>/.claude/`** — per-service `.claude/` directories are outside the generation scope under all modes. Never modify existing source files.

Load these references as needed:
- `../claudboard/references/claude-md-template.md` → for CLAUDE.md structure
- `../claudboard/references/rule-templates.md` → for rule file templates
- `../claudboard/references/skill-generation.md` → for full-scope skill generation and Pattern A

### 3a. Generate or update umbrella CLAUDE.md

Follow `../claudboard/references/claude-md-template.md` exactly.

**Single-project:** Use the standard template. Target 60-120 lines.

**Monorepo / Workspace:** Use the monorepo variant template from `claude-md-template.md`. Target 80-150 lines. Include:
- Services table (name, stack, directory, purpose) — use "Umbrella CLAUDE.md Services Section" from `claude-md-template.md`
- Shared libraries table (name, directory, consumers)
- Per-service build/test commands grouped by service
- Global conventions (branch, commit, CI/CD)
- Critical Rules section covering cross-service concerns
- Note: "Cross-service topology: `.claude/memories/ecosystem.md` (auto-loaded)"

**If CLAUDE.md exists:** Read it, add only gaps — new commands, new architecture notes, new rules/skills table entries, new critical rules. Do not rewrite.

**If new:** Generate from scratch using detected values for every field.

Write to: `<umbrella_root>/CLAUDE.md` (repo root for monorepo/single-project; workspace root for workspace)

### 3a-svc. Generate per-service CLAUDE.md (monorepo and workspace only)

For EACH detected service (not library), generate a short per-service `CLAUDE.md` using the "Per-Service CLAUDE.md Template" from `../claudboard/references/claude-md-template.md`.

Rules:
- ≤30 lines total.
- References the umbrella `ecosystem.md` and rules — never duplicates their content.
- Contains only service-specific facts: entry point, build/test commands, deployment target, known quirks.
- Write to: `<umbrella_root>/<service-dir>/CLAUDE.md`
- If file exists: read it, add only what's missing. Do not rewrite existing content.

### 3b. Generate rules

For each rule in `catalog.proposed_artifacts` where `type == "rule"`, follow `../claudboard/references/rule-templates.md`.

**Adaptive depth:** from `catalog.adaptive_depth[<stack-id>]` (or `proposed_artifact.depth_signal`):
- `full` → 80-120 lines with real code examples
- `medium` → 50-70 lines
- `skeleton` → 30-50 lines with TODO markers

**`paths:` scoping:** use `proposed_artifact.paths` (derived from `catalog.stacks[id].applicable_paths`). In monorepos with multiple services sharing a stack, a SINGLE rule file covers all services in that stack — do NOT generate one rule file per service.

**Global rules (no `paths:`):** `rules/ci-cd.md`, `rules/gitops.md`, etc. — CI/CD and cross-service conventions.

Write to: `<umbrella_root>/.claude/rules/<name>.md`. If file exists: add only what's missing; never overwrite.

### 3c. Generate full-scope skills

For each skill in `catalog.proposed_artifacts` where `type == "skill"`, follow `../claudboard/references/skill-generation.md`.

**Umbrella-only rule:** All generated skills live under `<umbrella_root>/.claude/skills/`. NEVER write into `<umbrella>/<service>/.claude/skills/` under any mode.

**Every generated skill includes:**
- `SKILL.md` (100-250 lines): architecture diagram specific to this project, step-by-step workflow, code examples from `catalog.patterns[<id>].exemplar_path`
- `references/` dir: at minimum one template from detected conventions; annotated example from the exemplar file
- `scripts/scaffold.sh` if the skill creates 3+ boilerplate files with predictable naming

**Adaptive depth:** from `catalog.adaptive_depth` or `proposed_artifact.depth_signal`. Full for clean codebases, skeleton+ask for inconsistent patterns.

**Monorepo / Workspace — Pattern A dispatcher skills:**

When the catalog's `proposed_artifacts` contains a skill where services/repos in the same stack have meaningfully different procedural content, generate a Pattern A dispatcher skill:

```
<umbrella_root>/.claude/skills/<concern>/
├── SKILL.md              # dispatcher — enumerates exact valid service names
└── references/
    ├── <service-a>.md    # per-service content
    ├── <service-b>.md    # per-service content
    └── ...
```

Follow the Pattern A contract from `../claudboard/references/skill-generation.md` → "Pattern A". SKILL.md must enumerate the exact set of valid service names (closed-set lookup). Reference filenames must exactly match those names.

**Scope per-stack skills** to `catalog.stacks[id].applicable_paths`; reference only that stack's conventions and exemplars.

Write to: `<umbrella_root>/.claude/skills/<name>/`. If skill exists: add only missing components.

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

**Conditional next step (include only when analysis report indicates Jira+ADO MCPs are configured):**

> Ready to generate a tailored `feature-workflow` skill? Run `/claudboard-workflow` to create a full ticket→branch→BDD→plan→implement→PR workflow for this project.

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
| No catalog or legacy reports found | Tell user: "No catalog or legacy reports found. Run `/analyse` first to produce `.claudboard/catalog.json`." Stop. |
| Catalog schema mismatch | Exit with error naming observed and expected version; instruct user to re-run `/analyse` |
| Catalog older than 24 hours | Warn but proceed if user confirms |
| Legacy migration parsing fails | Exit with error naming offending file; instruct user to run `/analyse` |
| Catalog contains "ASK USER" markers | Pause and ask user before generating those artifacts |

## Constraints

- **Never modify source code** — only write to `<umbrella_root>/.claude/`, `<umbrella_root>/CLAUDE.md`, and `<umbrella_root>/<service>/CLAUDE.md`.
- **No per-service `.claude/` writes** — NEVER write to `<service>/.claude/skills/`, `<service>/.claude/rules/`, or `<service>/.claude/memories/` under any mode. Per-service content reaches the umbrella via rules with `paths:` globs, `ecosystem.md`, or a Pattern A dispatcher skill.
- **Merge, don't replace** — when `.claude/` artifacts exist, append or update sections, never delete existing content.
- **Secrets:** Never include secret values in generated artifacts.
- **Per-service audit reports** (`.claudboard/audits/*.md`) are NOT consumed by `/generate` even when present — only the catalog is read.
- **`mode` field is UX-only** — never branch on `mode` for generation logic; use `umbrella_root` for write paths.

## Reference Files

| File | When to load |
|------|-------------|
| `../claudboard/references/catalog-schema.json` | Phase 1b — schema validation on catalog read |
| `../claudboard/references/catalog-format.md` | Phase 1b-1c — catalog field semantics and migration rules |
| `../claudboard/references/claude-md-template.md` | Phase 3a — CLAUDE.md generation |
| `../claudboard/references/rule-templates.md` | Phase 3b — rule file generation |
| `../claudboard/references/skill-generation.md` | Phase 3c — full-scope skill generation |
