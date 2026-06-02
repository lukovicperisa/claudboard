## MODIFIED Requirements

### Requirement: `/generate` SHALL read `.claudboard/catalog.json` as its primary input source

`/generate` SHALL look for the convention catalog at `<project>/.claudboard/catalog.json` first. If present, it SHALL read the catalog and proceed with generation using catalog fields as the sole structural input. It SHALL NOT walk `.claude/reports/*.md` for generative input when the catalog is present.

The catalog provides everything `/generate` requires: project-wide conventions (`catalog.conventions`), per-stack adaptive depth (`catalog.adaptive_depth`), proposed artifacts (`catalog.proposed_artifacts`), per-pattern exemplar paths (`catalog.patterns[<id>].exemplar_path`), per-stack scope (`catalog.stacks[].applicable_paths`).

The previously-documented "detect monorepo report structure" requirement (which scanned `.claude/reports/` for `claudboard-analysis-*.md` files) is superseded by the catalog-first behaviour. Per-service audit reports at `.claudboard/audits/*.md` are NOT consumed by `/generate`.

#### Scenario: `/generate` consumes catalog
- **WHEN** `/generate` runs against a project with `.claudboard/catalog.json` present
- **THEN** `/generate` reads only the catalog plus the standard reference templates; it does not Read() any audit report files

#### Scenario: Monorepo mode flag derived from catalog
- **WHEN** the catalog has `mode: "monorepo"`
- **THEN** `/generate` enters monorepo-generation behaviour (services table in CLAUDE.md, per-stack rule scoping, etc.) based on `catalog.stacks` and `catalog.proposed_artifacts`, not on the presence of per-service report files

#### Scenario: Single-project mode flag derived from catalog
- **WHEN** the catalog has `mode: "single-project"`
- **THEN** `/generate` follows the single-project generation path; per-service / per-stack scoping does not apply

---

### Requirement: `/generate` SHALL fall back to legacy reports with one-time migration when the catalog is absent

When `.claudboard/catalog.json` is absent and `.claude/reports/claudboard-analysis.md` is present (legacy state from prior claudboard versions), `/generate` SHALL:

1. Parse the legacy report(s) on a best-effort basis.
2. Extract recoverable catalog fields: proposed artifacts, project-wide conventions, per-pattern exemplars (from the report's "Best example" references), stacks (from the report's services/topology table).
3. Synthesise a catalog at `.claudboard/catalog.json` with `from_audit: <true if per-service reports also present, else false>`.
4. Log one line informing the user the migration ran.
5. Proceed with normal catalog-driven generation.

Subsequent `/generate` invocations see the catalog and skip the migration entirely.

The migration SHALL NOT delete, move, or overwrite any legacy report files. Old reports remain at their old paths until the user manually cleans them up or runs `/analyse --audit` to refresh under the new path.

If parsing legacy reports fails (corrupted file, schema from a much older claudboard version that lacks the expected sections), `/generate` SHALL exit with a clear message naming the offending file and instructing the user to run `/analyse` for a fresh catalog.

#### Scenario: First post-change `/generate` migrates legacy state
- **WHEN** `/generate` runs against a project with `.claude/reports/claudboard-analysis.md` and `.claude/reports/claudboard-analysis-foo-service.md` but no `.claudboard/catalog.json`
- **THEN** `/generate` writes `.claudboard/catalog.json` (with `from_audit: true` since per-service reports are present), logs the migration, proceeds with generation, and leaves the legacy report files in place

#### Scenario: Project with global report only (no per-service reports)
- **WHEN** `/generate` runs against a single-project repo with only `.claude/reports/claudboard-analysis.md` and no `.claudboard/catalog.json`
- **THEN** migration produces a catalog with `from_audit: false` and `mode: "single-project"`, and generation proceeds

#### Scenario: Neither catalog nor legacy reports
- **WHEN** `/generate` runs against a project with neither `.claudboard/catalog.json` nor any `.claude/reports/claudboard-analysis*.md`
- **THEN** `/generate` exits with the existing "no analysis report found, run `/analyse` first" message (text updated to reference the catalog: "No catalog or legacy reports found. Run `/analyse` first to produce `.claudboard/catalog.json`.")

#### Scenario: Migration parsing failure
- **WHEN** `/generate` attempts to migrate a legacy report that lacks the expected "Proposed Artifacts" section
- **THEN** `/generate` exits with an error naming the offending file path and instructing the user to run `/analyse`

---

### Requirement: `/generate` SHALL run on the Sonnet model tier

`/generate` orchestrator SHALL run on the Sonnet model tier. The rationale: `/generate`'s work is template-fill on a structured catalog input. There is no cross-document synthesis, no outlier detection, no creative pattern discovery — those happen in `/analyse`'s catalog production. Sonnet is competent for template-fill; Opus is overkill.

This tier choice is documented in `/generate`'s SKILL.md and is intended as guidance to harness operators / SDK consumers who configure the orchestrator model.

The one place this requirement may be revisited is the SKILL.md authoring step (Phase 3c) — generated skills' SKILL.md files include architecture diagrams, prose explanations of canonical patterns, and code examples extracted from the codebase. This is the most "creative" of `/generate`'s outputs. If empirical diffs (Sonnet vs Opus generation, both reading the same catalog) show meaningful quality degradation on SKILL.md authoring specifically, the tier decision may be split: Sonnet for CLAUDE.md and rules, Opus for SKILL.md authoring. This is a follow-up to evaluate, not part of v1.

#### Scenario: `/generate` documents Sonnet tier
- **WHEN** the `/generate` SKILL.md is loaded
- **THEN** the SKILL.md includes an explicit "Model tier: Sonnet" guideline near the top, with rationale linking back to the catalog-as-structured-input architectural decision

#### Scenario: Quality acceptance criterion applies to merge
- **WHEN** this change is merged
- **THEN** `/generate` (Sonnet, catalog-driven) on craftsphere.cloud has been compared against `/generate` (Opus, full-reports-driven) and the diff has been confirmed substantively equivalent (see tasks 6.4)

---

### Requirement: Generated rule scoping SHALL use catalog `stacks` and `applicable_paths`

The existing per-service rule scoping (e.g. `rules/<service-name>-conventions.md` with `paths: ["<service-dir>/**"]`) is preserved, but its inputs change source. The rule's `paths:` glob SHALL be derived from `catalog.stacks[<stack-id>].applicable_paths` (the union of all services in that stack), and the rule's content SHALL be derived from `catalog.conventions` and `catalog.adaptive_depth[<stack-id>]`.

In monorepos where multiple services share a stack (e.g. 11 Java services), this naturally produces a single shared rule file with `paths:` covering all 11 services — replacing the previous behaviour of producing N separate per-service rule files (which were near-duplicates anyway).

When `/analyse --audit` discovers that a specific service diverges from its stack's canonical conventions, the audit report (`.claudboard/audits/<svc>.md`) captures the divergence. `/generate` does NOT produce a per-service override rule by default; if the user wants service-specific rule overrides, they edit the generated stack rule manually or wait for a future capability that consumes audit findings into generation.

#### Scenario: Single rule for a shared-stack monorepo
- **WHEN** `/generate` runs against a monorepo whose catalog has one `java-spring` stack with 11 services
- **THEN** a single `rules/java-conventions.md` file is generated with `paths:` covering all 11 service directories; not 11 separate rule files

#### Scenario: Per-stack rules for a multi-stack monorepo
- **WHEN** the catalog has stacks `java-spring` (11 services), `react-ts` (5 services), `node-bff` (1 service), `kotlin-spring` (1 service)
- **THEN** `/generate` produces four rule files (`java-conventions.md`, `react-conventions.md`, `bff-conventions.md`, `kotlin-conventions.md`), each scoped via `paths:` to its stack's services
