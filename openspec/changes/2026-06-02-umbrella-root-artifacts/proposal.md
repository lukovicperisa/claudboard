## Why

Two facts uncovered after the 2026-06-02 `thin-analyse-catalog-primary` shipped:

1. **Workspace mode never got the catalog fix.** The change explicitly deferred workspace mode to a follow-up. A 2026-06-02 `/analyse` run against the MEAS workspace (14 service repos) re-triggered the exact $400-class Opus fan-out the monorepo restructure was meant to kill — orchestrator spawned one full-report sub-agent per repo by default. Two onboarding modes, two cost profiles, same logical input shape.

2. **Per-service `.claude/` artifacts don't load at workflow runtime.** Verified against the Claude Code docs ([sub-agents.md](https://code.claude.com/docs/en/sub-agents.md), [memory.md](https://code.claude.com/docs/en/memory.md), [large-codebases.md](https://code.claude.com/docs/en/large-codebases.md)): skills, rules, and memories are discovered by walking **up** from the session's CWD, not down. When feature-workflow runs from the umbrella root (workspace or monorepo), per-service `<svc>/.claude/skills/`, `<svc>/.claude/rules/`, and `<svc>/.claude/memories/*.md` are invisible — they're DOWN from CWD, not UP. Subagents spawned via the Agent tool re-discover from their own CWD, which defaults to the parent's. The only per-service file that genuinely participates in runtime context is per-service `CLAUDE.md`, because Claude Code does a dynamic down-walk when reading files in a subdir. Everything else under per-service `.claude/` directories is dead weight that `/generate` is currently spending tokens to produce.

The two facts compound. Workspace mode produces $400 of analysis output, then `/generate` spends another tier of tokens fanning out per-repo `.claude/` artifacts that the workflow runtime cannot see. The whole per-service `.claude/` shape is wrong for a multi-service umbrella project — monorepo and workspace alike. The fix is one change because the two facts have the same root: there is one umbrella, with N services beneath it, and the architectural artifacts belong at the umbrella.

## What Changes

- **MODIFIED** `analyse-performance` — workspace and monorepo become a single "umbrella + N services" mode under the hood. Default mode in both: orchestrator runs one reference-service deep pass per detected stack (no per-repo / per-service fan-out), writes catalog + thin summary to the umbrella root. `--audit` in both: per-service deep analysis fans out (Sonnet-tier sub-agents), writes audits to `.claudboard/audits/`. The fact that workspace has per-repo `.git/` and monorepo does not affects only one routing rule: where the umbrella `.claudboard/` and `.claude/` live (see workspace-detection MODIFIED).
- **MODIFIED** `workspace-detection` — detection logic unchanged (still discriminates on per-repo `.git/`). But the post-detection behaviour collapses into the same pipeline as monorepo. The detected workspace root is treated as the umbrella; the meta-repo (e.g. `meas.workspace/`) provides the git-tracked home for `.claude/` and `.claudboard/` via the existing symlink.
- **MODIFIED** `workspace-analyse-output` — replaces "per-repo reports under `<workspace>/.claude/reports/`" with the unified umbrella-root layout. Default mode: no per-repo reports, no per-repo sub-agent fan-out. `--audit` mode: per-service audits at `<umbrella>/.claudboard/audits/<svc>.md`. Workspace summary file is replaced by the same thin `claudboard-analysis.md` produced by monorepo mode.
- **MODIFIED** `convention-catalog` — catalog applies to workspace mode the same way it applies to monorepo. Catalog location is `<umbrella>/.claudboard/catalog.json` regardless of mode. Workspace's umbrella root is the workspace dir (with `.claudboard/` reachable via the same symlink convention as `.claude/`).
- **MODIFIED** `ecosystem-injection` — ecosystem.md is written **once** at the umbrella root, not per repo. Single file at `<umbrella>/.claude/memories/ecosystem.md` covering every service's role, dependencies, and edges. Applies to BOTH workspace and monorepo (previously workspace-only). Rationale: memories load from session CWD; only the umbrella-root memory is reliably loaded during feature-workflow runs.
- **MODIFIED** `cross-service-graph` — dependency graph construction applies to both workspace and monorepo (previously workspace-only). Cheap (orchestrator-side, derived from grep output in Phase 1b), and it's the input ecosystem.md is rendered from.
- **NEW** `umbrella-root-output` — formalises the "no per-service `.claude/` artifacts" rule. `/generate` SHALL NOT write into any `<umbrella>/<service>/.claude/skills/`, `<umbrella>/<service>/.claude/rules/`, or `<umbrella>/<service>/.claude/memories/` path. Per-service CLAUDE.md is the only per-service runtime artifact (because of dynamic down-walk). Service-specific content lives in rules (with `paths:` globs), memory (ecosystem.md, umbrella-wide), or a dispatcher skill with per-service references (Pattern A — see Decisions D5).
- **MODIFIED** `monorepo-generation` — `/generate` for both workspace and monorepo modes writes the same artifact set at the umbrella root. No per-service `.claude/` writes anywhere. Per-service skill content (when the catalog has any) lives inside a single `<umbrella>/.claude/skills/service-info/` skill with one reference file per service in `references/`.
- **No change** to: `discover.sh` (still per-repo grep, still produces the inputs the catalog synthesis consumes); `compute-cost.sh`; `pricing.md`; `/techdebt`; `/claudboard-workflow` (workspace-mode generation already writes to the meta-repo root — that's the umbrella, so the umbrella-only rule is already satisfied for feature-workflow); `claude-md-template.md` shape (the template is fine, only the per-service write paths are removed).

## Capabilities

### New Capabilities

- **`umbrella-root-output`** — formalises the rule that `/generate` writes only at the umbrella root (`<repo-root>/.claude/` for monorepo and single-project; `<workspace>/.claude/` for workspace, which is a symlink into the meta-repo). Per-service `.claude/` directories are out of bounds for claudboard-generated artifacts. Documents the runtime-loading semantics that justify the rule and the three patterns (rules with `paths:`, ecosystem.md, dispatcher skill with references) by which service-specific content reaches the umbrella root.

### Modified Capabilities

- **`analyse-performance`** — workspace and monorepo modes share the same pipeline. Default mode is reference-service-per-stack for both. `--audit` fan-out is symmetric. The workspace-mode "preserved pending follow-up adaptation" requirement is removed and replaced with the unified behaviour.
- **`workspace-detection`** — detection logic preserved; post-detection routing collapses into the monorepo path.
- **`workspace-analyse-output`** — replaces per-repo report writes with the unified umbrella-root catalog + thin summary. Per-repo sub-agent fan-out becomes an `--audit`-only behaviour, with output at `.claudboard/audits/`.
- **`convention-catalog`** — catalog applies to workspace mode; location is `<umbrella>/.claudboard/catalog.json` with `mode: "workspace" | "monorepo" | "single-project"`.
- **`ecosystem-injection`** — single file at the umbrella root, not per repo. Applies to both workspace and monorepo modes.
- **`cross-service-graph`** — applies to monorepo and workspace (previously workspace-only).
- **`monorepo-generation`** — generation writes only at the umbrella root; symmetric for workspace and monorepo.

## Impact

- **Affected files (new):**
  - `openspec/changes/2026-06-02-umbrella-root-artifacts/specs/umbrella-root-output/spec.md` — new capability spec
- **Affected files (modified):**
  - `skills/claudboard-analyse/SKILL.md` — workspace-mode section collapses into the monorepo path; the workspace parallelisation protocol becomes "audit-only fan-out, same as monorepo"; Phase 3 writes only umbrella-root artifacts; per-repo report writing paths are removed
  - `skills/claudboard-generate/SKILL.md` — write paths reduced to umbrella root only; per-service write loop removed; service-specific content channels documented (rules with `paths:`, ecosystem.md, dispatcher skill)
  - `skills/claudboard-refresh/SKILL.md` — same unification applied; refresh writes only at umbrella root
  - `skills/claudboard/references/catalog-schema.json` — `mode` enum extended to include `"workspace"`; `stacks` entries carry `repo_count` alongside `service_count` to disambiguate "5 React services" vs "5 React repos"
  - `skills/claudboard/references/catalog-format.md` — documents workspace-mode catalog placement (umbrella root, reached via symlink in workspace) and the unified default/audit shape
  - `skills/claudboard/references/skill-generation.md` — adds Pattern A documentation (dispatcher skill + per-service references); explicitly forbids per-service `<svc>/.claude/skills/` write paths
  - `skills/claudboard/references/claude-md-template.md` — adds a per-service CLAUDE.md template variant (short, service-specific, loaded via dynamic down-walk); umbrella CLAUDE.md references it
- **Affected files (unchanged):**
  - `skills/claudboard-analyse/scripts/discover.sh` — already per-repo, no change needed
  - `skills/claudboard-analyse/scripts/lang/*.sh` — unchanged
  - `skills/claudboard/scripts/compute-cost.sh` — unchanged
  - `skills/claudboard/references/pricing.md` — unchanged
  - `skills/claudboard-techdebt/SKILL.md` — unchanged; not on the analyse → generate path
  - `skills/claudboard-workflow/**` — unchanged; workflow generator already writes to the umbrella root (meta-repo in workspace mode), so the umbrella-only rule is already honoured
  - `skills/claudboard-workspace-init/**`, `skills/claudboard-workspace-link/**` — unchanged; the symlink convention they set up is exactly what this change leans on
- **Downstream consumers:**
  - Existing workspace projects with `<workspace>/.claude/reports/claudboard-analysis-<repo>.md` files (from prior runs): legacy files are left untouched; the next `/analyse` run produces the unified umbrella-root catalog + thin summary instead. The next `/generate` run reads the catalog. The legacy per-repo reports are not consumed.
  - Existing projects (any mode) with per-service `.claude/` directories generated by prior `/generate` runs: those directories are left untouched on disk by this change; they simply stop receiving updates from `/generate` and `/refresh`. Users may delete them manually. A future cleanup change can offer a `--prune-stale` flag if needed (out of scope here).
  - `/claudboard-workflow`: unaffected. Workspace-mode workflow generation already writes to the meta-repo root; single-repo / monorepo workflow generation writes to the repo root. Both are umbrella roots.
- **Cost-model claims (Bosch Vertex rates, see `skills/claudboard/references/pricing.md`):**
  - Default `/analyse` on MEAS workspace (14 service repos, mixed Java + React + Node): **projected ~$30-50** (acceptance cap $80). Driven by single Opus orchestrator + per-stack reference deep passes (~5 stacks: cloud-java, cloud-dotnet, web-mfe, web-microfrontend, shared-dto-library). No per-repo fan-out by default.
  - `/analyse --audit` on MEAS workspace: **projected ~$120-180** (acceptance cap $250). Sonnet sub-agent fan-out across 14 service repos.
  - `/generate` on MEAS workspace, reading umbrella catalog: **projected ~$12-18** (acceptance cap $25). Sonnet template-fill at umbrella root only — no per-service generation loops.
  - Default `/analyse` on craftsphere.cloud monorepo: **unchanged from prior measurement** (~$27 measured, see `thin-analyse-catalog-primary` design.md → Validation).
  - `/analyse --audit` on craftsphere.cloud: **unchanged** (deferred measurement, projected $70-85).
  - `/generate` on craftsphere.cloud: **lower than prior $11.31** because per-service `.claude/` writes are removed from the loop. Projected $8-10.
  - Single-project repos: cost-neutral — default mode is unchanged in shape, and there were no per-service writes to remove.
- **Risks:**
  - *Workspace-mode users lose per-repo report files they were reading.* Mitigation: legacy files are not deleted; users can still read them. The thin umbrella summary plus per-service audits (when `--audit` is run) covers the same ground in a smaller, better-organised form. Documented in CLAUDE.md generation template.
  - *Per-service `.claude/` directories accumulate as stale dead weight on disk.* Mitigation: they were never auto-loaded, so the stale content does no runtime harm; users can `rm -rf <svc>/.claude/skills <svc>/.claude/rules <svc>/.claude/memories` at leisure. A future `--prune-stale` flag can automate this (out of scope here).
  - *Catalog `mode: "workspace"` consumers must handle the symlink correctly.* Mitigation: the catalog's `repo` field uses absolute paths (already standardised); the symlink from workspace `.claude` to the meta-repo's `.claude` resolves transparently for file I/O. Documented in `catalog-format.md`.
  - *Skill dispatcher pattern (Pattern A) is unproven in production.* Mitigation: Pattern A is documented in `skill-generation.md` with explicit "enumerate the reference filenames in SKILL.md, dispatch by exact match" rules to avoid fuzzy string matching. If empirical use shows this is brittle, escape hatch (per-service skill at umbrella root, Pattern B) is documented as the fallback for services with substantial procedural content.
  - *Per-service CLAUDE.md is the only runtime-loaded per-service artifact.* Mitigation: this is by design — the dynamic down-walk in Claude Code is the documented mechanism, and it's the right place for service-specific orientation (one short file per service: "you are in service X, which does Y, see umbrella ecosystem.md for context").
  - *Workspace-mode meta-repo bootstrap is a prerequisite.* When workspace mode encounters no `.claude/` symlink (the workspace hasn't been bootstrapped via `/claudboard-workspace-init`), `/analyse` cannot write the catalog under the workspace. Mitigation: `/analyse` in workspace mode SHALL detect this and either (a) write the catalog and reports inline at `<workspace>/.claudboard/` and `<workspace>/.claude/reports/` (creating the directories), and instruct the user to bootstrap via `/claudboard-workspace-init` to migrate them under git; or (b) refuse and instruct the user to bootstrap first. Decision in D6.
- **Out of scope (deferred to follow-up changes):**
  - `--prune-stale` flag for `/generate` / `/refresh` to delete per-service `.claude/` directories left by prior versions.
  - `/refresh` redesign to diff against the unified catalog (still deferred from `thin-analyse-catalog-primary`; this change makes that follow-up even simpler because workspace is now the same shape).
  - Promotion logic for "this service has enough procedural distinctiveness to warrant its own root-level skill (Pattern B) instead of a reference under the dispatcher (Pattern A)." Pattern A applies uniformly in v1; promotion is a v2 optimisation.
  - Cost preview in `/analyse`'s scope-confirmation `AskUserQuestion` (still deferred from `thin-analyse-catalog-primary`).
  - Workspace meta-repo bootstrap UX improvements (e.g. auto-suggesting `/claudboard-workspace-init` when `.claude/` is missing in workspace mode).
