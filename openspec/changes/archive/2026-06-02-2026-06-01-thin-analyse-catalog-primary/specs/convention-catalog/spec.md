## ADDED Requirements

### Requirement: Convention catalog SHALL be the primary artifact on the analyse → generate path

The system SHALL produce a strict-JSON convention catalog as the canonical artifact on the analyse → generate path. The catalog is the single contract between `/analyse` (producer), `/generate` (consumer), and any future skill that consumes analysis output (e.g. `/refresh`).

The catalog file SHALL be located at `<project>/.claudboard/catalog.json`. This location is outside `.claude/` because the catalog is build state, not runtime context — Claude Code does not auto-load it during normal sessions.

`/generate` SHALL prefer the catalog over any other source of analysis input. When the catalog is present, `/generate` SHALL NOT walk `.claude/reports/*.md` for generative input. The reports remain available for human review but are not consumed by automation on the generation path.

#### Scenario: Catalog is the single source of truth for `/generate`
- **WHEN** `/generate` runs against a project with `.claudboard/catalog.json` present
- **THEN** `/generate` reads the catalog as its sole structural input; per-service audit reports (`.claudboard/audits/*.md`) are not read by `/generate` even when present

#### Scenario: Catalog location is outside `.claude/`
- **WHEN** `/analyse` writes the catalog
- **THEN** the catalog file is at `<project>/.claudboard/catalog.json`, not under `.claude/`

---

### Requirement: Catalog SHALL conform to a versioned JSON Schema

The catalog SHALL conform to a published JSON Schema document at `skills/claudboard/references/catalog-schema.json`. The schema SHALL declare `schema_version` as a required string field with the current literal value `"1"`.

Producers (`/analyse` in any mode) SHALL set `schema_version` to the current value on every write.

Consumers (`/generate`, future `/refresh`) SHALL assert that the catalog's `schema_version` matches the consumer's expected version on every read. On mismatch, the consumer SHALL exit with a clear error message naming both the observed version and the expected version, and instructing the user to either re-run `/analyse` or check that the claudboard skill files and SKILL.md are at the same version.

This mirrors the `schema_version` discipline already established by `discover.sh` (see `analyse-performance` spec).

#### Scenario: Producer writes current schema version
- **WHEN** `/analyse` writes the catalog
- **THEN** the catalog's `schema_version` field is `"1"`

#### Scenario: Consumer asserts schema version on read
- **WHEN** `/generate` reads a catalog whose `schema_version` is `"0"` or `"2"` (not `"1"`)
- **THEN** `/generate` exits non-zero with an error naming both versions and the expected version

#### Scenario: Missing schema_version is treated as schema violation
- **WHEN** `/generate` reads a catalog whose JSON lacks a `schema_version` field
- **THEN** `/generate` exits non-zero with an error naming the missing required field

---

### Requirement: Catalog SHALL include the fields `/generate` consumes

The catalog SHALL include the following top-level fields. Required fields are marked `(required)`; optional fields are marked `(optional)`. The full JSON Schema is the canonical reference.

- `schema_version` (required, string, literal `"1"`)
- `generated_at` (required, ISO-8601 timestamp string)
- `from_audit` (required, boolean) — `true` if produced by `/analyse --audit` and is sibling to `.claudboard/audits/*.md`; `false` if produced by default `/analyse`
- `repo` (required, string) — absolute path to the analysed project
- `mode` (required, string enum) — one of `"single-project"`, `"monorepo"`, `"workspace"`
- `stacks` (required, array) — one entry per detected stack, each `{id: string, service_count: int, reference_service: string?, exemplar_paths: object<pattern-name → path>}`
- `conventions` (required, object) — canonical conventions across the project: `{di_style, logging, error_handling, test_framework, naming, …}`. Values are short strings naming the convention; nulls allowed when undetected.
- `patterns` (required, object) — keyed by pattern id (e.g. `"kafka_consumer"`, `"rest_controller"`, `"spock_spec"`, `"react_component"`); each value `{exemplar_path: string, frequency: int, variations: string[], applicable_paths: string[]}`
- `proposed_artifacts` (required, array) — each entry `{type: "rule" | "skill", name: string, paths: string[]?, exemplar: string?, depth_signal: "full" | "medium" | "skeleton"}`. This is the deduplicated, project-wide artifact list `/generate` instantiates.
- `adaptive_depth` (required, object) — per-stack rule/skill depth signal `{<stack-id>: "full" | "medium" | "skeleton"}` driven by quality scoring
- `audit_summary` (optional, object) — present only when `from_audit: true`; references the audit files and surfaces the top-level Watch findings

#### Scenario: Catalog contains all required fields after default `/analyse`
- **WHEN** default `/analyse` produces a catalog for a single-project repo
- **THEN** the catalog has `schema_version`, `generated_at`, `from_audit: false`, `repo`, `mode: "single-project"`, `stacks`, `conventions`, `patterns`, `proposed_artifacts`, and `adaptive_depth`

#### Scenario: Catalog from `--audit` includes audit summary
- **WHEN** `/analyse --audit` produces a catalog for a monorepo
- **THEN** the catalog additionally has `from_audit: true` and an `audit_summary` object naming the audit files in `.claudboard/audits/`

#### Scenario: Catalog has stacks entry per detected stack
- **WHEN** `/analyse` runs against a monorepo with 11 Java services, 6 React MFEs, 1 Node BFF, 1 Go service, 1 Kotlin service, and 1 Quarkus service
- **THEN** the catalog's `stacks` array has 6 entries (java-spring, react-ts, node-bff, go, kotlin-spring, quarkus), each with `service_count` populated

---

### Requirement: `/generate` SHALL render artifacts purely from catalog fields

`/generate` SHALL produce CLAUDE.md, rules, and skills using only the catalog and the existing reference templates (`claude-md-template.md`, `rule-templates.md`, `skill-generation.md`). It SHALL NOT require per-service audit reports as input.

When the catalog includes `from_audit: false`, `/generate` SHALL proceed normally; the catalog content is sufficient for generation regardless of whether audit detail exists on disk.

#### Scenario: Generation works from default-mode catalog
- **WHEN** `/generate` runs against a project whose catalog has `from_audit: false`
- **THEN** `/generate` produces the full set of `.claude/` artifacts (CLAUDE.md, rules, skills) without erroring on missing audit data

#### Scenario: Skill exemplar paths from catalog
- **WHEN** `/generate` generates a `kafka-consumer` skill
- **THEN** the skill's references/template files are derived from `catalog.patterns["kafka_consumer"].exemplar_path`

#### Scenario: Adaptive depth from catalog
- **WHEN** `/generate` generates a `java-conventions` rule for a stack whose `catalog.adaptive_depth["java-spring"]` is `"full"`
- **THEN** the rule is generated at full depth (80-120 lines with real code examples)

---

### Requirement: Legacy reports SHALL be migrated to a catalog on first post-change `/generate` invocation

When `.claudboard/catalog.json` is absent AND `.claude/reports/claudboard-analysis.md` is present, `/generate` SHALL synthesise a catalog from the legacy reports on a best-effort basis, write it to `.claudboard/catalog.json`, log one line informing the user of the migration, then proceed with normal generation.

The migration SHALL preserve all data the catalog requires that is recoverable from the legacy reports. Information not present in the legacy reports (e.g. the explicit `stacks` taxonomy if the legacy report did not emit it) MAY be reconstructed from the per-service reports if present, or set to defaults (e.g. empty arrays) if absent.

The migration SHALL NOT delete, move, or overwrite the legacy report files.

If parsing the legacy reports fails (corrupted file, incompatible schema from a much older claudboard version), `/generate` SHALL emit a clear error message naming the offending report file and instruct the user to run `/analyse` for a fresh catalog. The user can then re-run `/generate`.

#### Scenario: Migration runs once on first post-change `/generate`
- **WHEN** `/generate` runs against a project that has `.claude/reports/claudboard-analysis.md` but no `.claudboard/catalog.json`
- **THEN** `/generate` writes `.claudboard/catalog.json` synthesised from the legacy reports, prints one line indicating the migration, and proceeds with generation

#### Scenario: Subsequent `/generate` runs skip migration
- **WHEN** `/generate` runs against a project that now has `.claudboard/catalog.json` (from a prior migration or from a fresh `/analyse`)
- **THEN** `/generate` skips the migration check and reads the catalog directly

#### Scenario: Migration leaves legacy reports in place
- **WHEN** `/generate` migrates a project that had `.claude/reports/claudboard-analysis.md` and `.claude/reports/claudboard-analysis-companies-service.md`
- **THEN** both legacy report files remain on disk after migration; only the new catalog is written

#### Scenario: Migration failure surfaces a clear error
- **WHEN** `/generate` attempts to migrate a legacy report file that does not contain the expected structure (e.g. missing "Proposed Artifacts" section)
- **THEN** `/generate` exits with an error naming the offending file and instructing the user to run `/analyse`

---

### Requirement: Catalog SHALL be regenerated, not incrementally updated, by `/analyse`

`/analyse` SHALL write the catalog from scratch on every invocation. It SHALL NOT attempt to merge with an existing catalog or preserve fields from prior runs.

The rationale is correctness: the catalog reflects the current codebase state; partial updates risk stale fields surviving across runs where the underlying code has changed. Regeneration is cheap (the orchestrator synthesis is the same work regardless of whether a prior catalog exists).

`/refresh` (future capability, out of scope here) MAY adopt a different model — diff against catalog rather than rebuild — but `/analyse` is full-rebuild only.

#### Scenario: `/analyse` overwrites existing catalog
- **WHEN** `/analyse` runs against a project that already has a catalog at `.claudboard/catalog.json`
- **THEN** the catalog is overwritten with newly-derived content; no fields from the old catalog are preserved
