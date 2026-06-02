# Convention Catalog Format

The convention catalog (`.claudboard/catalog.json`) is the primary artifact on the analyse→generate path. It is a strict-JSON document conforming to `catalog-schema.json`.

## Location

```
<project-root>/
  .claudboard/
    catalog.json          ← primary artifact (this file)
    audits/               ← per-service audit reports (--audit only)
      <service-name>.md
  .claude/
    reports/
      claudboard-analysis.md  ← thin human-readable summary (always)
    rules/, skills/, ...      ← runtime context (auto-loaded)
```

`.claudboard/` is **build state**, not runtime context. Claude Code does not auto-load its contents during normal sessions. The catalog exists so that `/generate` (and future `/refresh`) have a reliable, machine-correct input without re-reading N per-service report files.

## Required vs Optional Fields

| Field | Required | Producer | Consumer |
|---|---|---|---|
| `schema_version` | ✓ | `/analyse` | `/generate`, `/refresh` |
| `generated_at` | ✓ | `/analyse` | human review |
| `from_audit` | ✓ | `/analyse` | `/generate` |
| `repo` | ✓ | `/analyse` | `/generate` |
| `mode` | ✓ | `/analyse` | `/generate` |
| `stacks` | ✓ | `/analyse` | `/generate` |
| `conventions` | ✓ | `/analyse` | `/generate` |
| `patterns` | ✓ | `/analyse` | `/generate` |
| `proposed_artifacts` | ✓ | `/analyse` | `/generate` |
| `adaptive_depth` | ✓ | `/analyse` | `/generate` |
| `audit_summary` | optional | `/analyse --audit` | human review |

## How `/analyse` Populates Each Field

| Field | Data source |
|---|---|
| `schema_version` | Hard-coded `"1"` |
| `generated_at` | System clock at write time |
| `from_audit` | Whether `--audit` flag was passed |
| `repo` | Absolute path resolved from CWD or provided path |
| `mode` | Result of monorepo/workspace detection in Phase 1a |
| `stacks` | discover.sh output (`wide_scan.conventions`, `wide_scan.skill_triggers`) + reference-service deep pass; one entry per detected runtime/framework |
| `stacks[].applicable_paths` | Union of service directories that belong to this stack |
| `stacks[].exemplar_paths` | `wide_scan.skill_triggers[<trigger>].best_example` from the reference service |
| `conventions` | Orchestrator synthesis across reference services from all detected stacks |
| `patterns` | `wide_scan.skill_triggers` best_example + frequency; keyed by pattern id |
| `proposed_artifacts` | Skill dedup + convention catalog synthesis; replaces per-service "Proposed Artifacts" markdown section |
| `adaptive_depth` | Quality score average per stack → `full` (≥7.0) / `medium` (4.0-6.9) / `skeleton` (<4.0) |
| `audit_summary` | Set only when `from_audit: true`; enumerates `.claudboard/audits/*.md` paths and extracts top Watch findings |

In **default mode** (no `--audit`): only ONE reference service per detected stack undergoes the full deep pass (Phases 1c-1h). The remaining M-1 services in that stack contribute their stack identity and applicable paths to `stacks[]` but not to convention details. The catalog is still complete for `/generate`'s needs — conventions are canonical per-stack, not per-service.

In **`--audit` mode**: every detected service runs Phases 1c-1h via Sonnet sub-agents. The catalog is produced with the same structure but richer data (all services contribute to pattern frequency counts, audit reports cross-reference Watch findings in `audit_summary`).

## How `/generate` Consumes Each Field

| `/generate` action | Catalog field used |
|---|---|
| Detect single-project / monorepo / workspace | `mode` |
| Build services table in CLAUDE.md | `stacks[].id`, `stacks[].service_count`, `stacks[].applicable_paths` |
| Write per-stack rule files with `paths:` | `stacks[].applicable_paths`, `proposed_artifacts[type=rule].paths` |
| Set rule/skill depth | `adaptive_depth[stack-id]` or `proposed_artifacts[].depth_signal` |
| Source skill exemplar file content | `patterns[id].exemplar_path` |
| Enumerate artifacts to generate | `proposed_artifacts` (iterate in order) |
| Fill CLAUDE.md conventions section | `conventions.*` |
| Schema version validation | `schema_version` (assert `== "1"`) |

## Regeneration Contract

`/analyse` **always regenerates the catalog from scratch**. It does not merge with an existing catalog or preserve fields from prior runs. Stale partial updates are worse than a full rebuild — the catalog reflects current codebase state on every write.

**`/refresh`** (future capability, not in this change) will adopt a different model: diff against the catalog rather than rebuild. That work is deferred.

## Catalog ↔ Audit Relationship

Two catalog flavours:

| | Default `/analyse` | `/analyse --audit` |
|---|---|---|
| `from_audit` | `false` | `true` |
| Catalog completeness | Full (all required fields) | Full + richer frequency counts |
| Per-service audit files | None | `.claudboard/audits/<svc>.md` |
| `audit_summary` field | absent | present |
| Cost model | Lower (reference-service deep pass per stack) | Higher (full fan-out per service) |

When `from_audit: true`, the catalog and audit reports are sibling outputs of the same orchestrator run — their data is consistent. When `from_audit: false`, the catalog is derived from fewer data points (reference services only) but is still complete for generation.

Human readers who want per-service Watch findings, quality scores, or cross-service Kafka graphs need the audit reports. `/generate` does not need them.

## Schema Version Compatibility

The catalog carries `schema_version: "1"`. Consumers (`/generate`, future `/refresh`) assert this on every read:

```
if catalog.schema_version != "1":
    error: "Catalog schema mismatch: got <observed>, expected 1.
            Re-run /analyse to produce a fresh catalog, or check that
            claudboard SKILL.md files and catalog-schema.json are at
            the same version."
```

This mirrors the `schema_version` discipline used by `discover.sh`. Increment `schema_version` only when a field is added/removed/renamed in a way that breaks existing consumers. Add new optional fields without bumping.

## Migration from Legacy Reports

Projects that ran `/analyse` before this change have `.claude/reports/claudboard-analysis.md` (and optionally `claudboard-analysis-<svc>.md` files) but no `.claudboard/catalog.json`.

On the first post-change `/generate` invocation, `/generate` automatically migrates:

1. Detects: `.claudboard/catalog.json` absent AND `.claude/reports/claudboard-analysis.md` present
2. Parses the legacy report(s) best-effort
3. Writes `.claudboard/catalog.json` with `from_audit: <true if per-service reports present>`
4. Logs one line: "Migrated legacy analysis reports to .claudboard/catalog.json"
5. Proceeds with normal catalog-driven generation

Legacy report files are **not moved, deleted, or modified**. Subsequent `/generate` runs see the catalog and skip migration.

If parsing fails (corrupted report or incompatible older format), `/generate` exits with a clear error naming the offending file and instructing the user to run `/analyse` for a fresh catalog.

## .gitignore Posture

`.claudboard/` is build state — it is regenerated by `/analyse` on demand.

**Recommended for most projects (gitignore):**
```gitignore
# claudboard build state — regenerate with /analyse
.claudboard/
```

Ignored catalog means no merge conflicts when multiple developers run `/analyse` on different branches. The cost is that CI or teammates must re-run `/analyse` themselves.

**Alternative (commit the catalog):**

Teams that want to track artifact history across PRs, or share a stable catalog without requiring every developer to re-run `/analyse`, may commit `.claudboard/catalog.json`. This is especially useful for monorepos where the full `/analyse` run is expensive.

Trade-off summary:

| | Gitignored | Committed |
|---|---|---|
| Merge conflicts | None (regenerated) | Possible (catalog changes per branch) |
| CI setup | Developers run `/analyse` locally | CI can use the committed catalog directly |
| Cost per developer | `/analyse` cost per local setup | One run per PR that changes code patterns |
| Audit files | Usually gitignored regardless | May commit per-service audits for PR review |

Audit reports (`.claudboard/audits/*.md`) are almost always gitignored regardless of the catalog posture — they are large, frequently regenerated, and change on every `/analyse --audit` run.
