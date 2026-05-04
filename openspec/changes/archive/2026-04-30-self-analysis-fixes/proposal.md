# Self-Analysis Fixes: Severity Consolidation + Language Parity

## Problem

Six iterations of recursive self-analysis found 34 open issues (N-01 through N-34). Four are HIGH severity and block correct behavior:

1. **Severity source-of-truth conflict (N-12 + N-13 + N-14):** `pattern-catalog.md` and `severity-matrix.md` both define severity for overlapping findings with different values (God class = MEDIUM in one, HIGH in the other). Compound severity rules exist in both files with no documented ownership. Claude picks whichever file it loaded, producing inconsistent output.

2. **Wide Scan language coverage gap (N-07):** Stack-detectors.md has 7 scan categories for Java/Kotlin but only 3 for TypeScript/Python and none for Go/Rust/.NET. The analyse SKILL.md says "see stack-detectors.md for exact commands per language" — which is a lie for 3 of the 6 supported languages.

## Solution

### A. Severity Consolidation

Consolidate into `severity-matrix.md` as the single source of truth. Add two-column scoring:

| Signal | Overview (analyse) | Debt (techdebt) |
|--------|-------------------|-----------------|
| God class >500 LOC | MEDIUM | HIGH |
| God class >500, no tests | HIGH | CRITICAL |

- `pattern-catalog.md` drops its severity column — becomes detection-only
- Compound severity rules stay in their respective files (pattern-catalog has 5 analyse-scoped rules, severity-matrix has 8 techdebt-scoped rules) but each file explicitly states its scope and cross-references the other
- `severity-matrix.md` adds a fallback rule: "matrix takes precedence when present; for findings not in the matrix, use MEDIUM as default"

### B. Stack-Detectors Language Parity

Split `stack-detectors.md` into per-language files. Bring all languages to 7-category parity:

```
references/
├── stack-detectors.md              # Shared: monorepo detection, repo sizing,
│                                   #   custom patterns, workflow detection (~170 lines)
├── stack-detectors-java.md         # Extract existing Java/Kotlin (~200 lines)
├── stack-detectors-typescript.md   # Extract existing + add security/API/observability/deps (~200 lines)
├── stack-detectors-python.md       # Extract existing + add security/API/observability/deps (~200 lines)
├── stack-detectors-go.md           # New — all 7 categories (~180 lines)
├── stack-detectors-rust.md         # New — all 7 categories (~150 lines)
└── stack-detectors-dotnet.md       # New — all 7 categories (~180 lines)
```

**7 categories per language:**
1. Custom patterns (inheritance, interfaces, abstractions)
2. Anti-pattern signals (God class, broad catches, type-unsafety)
3. Convention frequency (DI style, logging, naming)
4. Security posture signals (auth framework, endpoint protection, CORS)
5. API surface signals (endpoint count, versioning, documentation tooling)
6. Observability signals (metrics, tracing, structured logging)
7. Dependency deep-scan signals (lockfiles, BOM, version conflicts)

Each language adapts these to its ecosystem (e.g., Go doesn't have DI injection — convention category covers `golangci-lint`, `go vet`, naming conventions instead).

### C. Quick Fixes (yes/no decisions from explore session)

- **N-03:** Add quality score summary table to analyse Phase 2 (dimension → rating → adaptive depth)
- **N-09:** Load severity-matrix.md once at Phase 2 start, not per-pass
- **N-04:** Techdebt reuses call-path findings from existing analyse reports
- **N-28:** Techdebt detects and stops cleanly for test-only projects
- **N-26:** Generate validates "Proposed Artifacts" section exists before proceeding
- **N-10 + N-34:** Monorepo quality scores per-service AND global; file budget scales with service count

## Non-Goals

- Adding new anti-pattern categories beyond what's already defined
- Changing the /analyse or /techdebt workflow structure
- Fixing LOW or MEDIUM issues (those can be tackled separately)
- Adding new languages beyond the 6 already in stack-detectors.md

## Impact

### Files Modified

| File | Change | Est. lines after |
|------|--------|-----------------|
| `references/stack-detectors.md` | Keep shared sections only | ~170 |
| `references/stack-detectors-java.md` | Extract from current file | ~200 |
| `references/stack-detectors-typescript.md` | Extract + add 4 categories | ~200 |
| `references/stack-detectors-python.md` | Extract + add 4 categories | ~200 |
| `references/stack-detectors-go.md` | New — full 7 categories | ~180 |
| `references/stack-detectors-rust.md` | New — full 7 categories | ~150 |
| `references/stack-detectors-dotnet.md` | New — full 7 categories | ~180 |
| `references/severity-matrix.md` | Add overview/debt columns, fallback rule | ~140 |
| `references/pattern-catalog.md` | Drop severity column from anti-pattern tables | ~400 |
| `claudboard-analyse/SKILL.md` | Quality score table, monorepo scoring, ref updates | ~455 |
| `claudboard-techdebt/SKILL.md` | Reuse call-paths, test-only guard, matrix load once | ~415 |
| `claudboard-generate/SKILL.md` | Validate report structure | ~190 |
| `claudboard/SKILL.md` | Update reference table for split files | ~65 |

### Reference Loading Changes

The analyse SKILL.md currently says "Load `stack-detectors.md`". After the split:
- Load `stack-detectors.md` (shared) always
- Load `stack-detectors-{language}.md` based on detected stack from Phase 1a
- For polyglot repos: load multiple language files

All sub-skills referencing `../claudboard/references/stack-detectors.md` need path updates.

## Success Criteria

1. `severity-matrix.md` is the only file containing severity values — `pattern-catalog.md` has none
2. Every language in "Tested on" (README) has all 7 Wide Scan categories in its stack-detectors file
3. All per-language files are under 250 lines
4. `stack-detectors.md` shared file is under 200 lines
5. `/analyse` on a Go or Rust project produces the same category coverage as a Java project
6. Quality score summary table appears in analyse Phase 2 output
7. No broken cross-references between files after the split
