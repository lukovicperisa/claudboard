## Context

Claudboard is a Claude Code skill that scans brownfield repos and generates `.claude/` artifacts. It works in 3 phases: Discovery (grep-based wide scan + strategic file sampling) → Analysis Report → Artifact Generation. All detection logic lives in SKILL.md orchestration + reference files (stack-detectors.md, quality-signals.md, pattern-catalog.md, etc.).

Current scanner covers: stack detection, architecture patterns, code anti-patterns, conventions, CI/CD, testing, dependencies (shallow). Missing: security posture, API surface, observability, skill overlap detection, compound severity.

All changes target reference files and SKILL.md — no external dependencies, no new tools.

## Goals / Non-Goals

**Goals:**
- Add 3 new quality dimensions: Security, API Surface, Observability
- Detect and resolve overlapping skill proposals before presenting to user
- Cross-reference anti-pattern findings to escalate compound risks
- Deepen dependency analysis (BOM, conflicts, SBOM)
- Maintain backward compatibility — existing scans still work, output is additive

**Non-Goals:**
- CVE database lookups or real-time vulnerability scanning (too complex, needs external service)
- Runtime security analysis (static scan only)
- Auto-fix or refactoring suggestions (scanner reports, doesn't fix)
- Supporting non-JVM security frameworks in first pass (Spring-focused, extend later)

## Decisions

### 1. Add detection patterns to existing reference files (not new files)

Security, API, and observability patterns go into `stack-detectors.md` (grep patterns) and `quality-signals.md` (scoring dimensions). No new reference files.

**Why:** Scanner already loads these files at known phases. Adding sections keeps the loading model simple. New files would require SKILL.md changes to load them at the right time.

**Alternative:** Separate `security-signals.md` file — rejected because it fragments related concerns and adds a load step.

### 2. Skill dedup as Phase 2 post-processing step

After collecting all skill triggers and before presenting the proposal, run pairwise overlap check:
- Compare target file globs between proposed skills
- Compare trigger annotations/patterns
- If >50% file overlap OR same trigger pattern appears in both → flag for merge or disambiguation

**Why:** Dedup must happen after all triggers are collected but before user sees the proposal. Phase 2 report generation is the natural place.

**Alternative:** Dedup during Phase 1c trigger collection — rejected because you need the full picture before you can compare.

### 3. Compound severity as a lookup table, not algorithmic

Define explicit compound rules in pattern-catalog.md:

```
| Finding A              | Finding B              | Escalation        |
|------------------------|------------------------|-------------------|
| return null            | reflection in hot path  | INFO → HIGH       |
| broad catch(Exception) | cascading deletes       | MEDIUM → HIGH     |
| no auth on endpoint    | PII in response DTO    | MEDIUM → CRITICAL |
| god class              | no tests for class      | MEDIUM → HIGH     |
```

**Why:** Algorithmic severity escalation is fragile and hard to debug. Explicit table is reviewable, extensible, predictable.

**Alternative:** Score-based system (sum individual severities) — rejected because severity isn't additive in meaningful ways.

### 4. Security detection: grep-based, Spring-focused first

Detect via grep patterns: `SecurityFilterChain`, `@PreAuthorize`, `@Secured`, `@Authorize` (custom), `CorsConfigurationSource`, `@CrossOrigin`, `OncePerRequestFilter`. Score based on coverage.

**Why:** Matches existing scanner approach (grep → tally → report). Spring Security is dominant in target repos (Bosch enterprise Java). Other frameworks added later.

### 5. API surface: count + classify, not parse

Count endpoints via `@*Mapping` annotations. Detect versioning via URL patterns (`/api/v1/`, `/api/v2/`). Check for OpenAPI dep. Don't parse OpenAPI specs.

**Why:** Parsing OpenAPI YAML is expensive and error-prone. Counting annotations is fast, reliable, and gives the developer a useful overview without deep analysis.

## Risks / Trade-offs

**grep pattern false positives** → Mitigation: same risk as current scanner; patterns are scoped to production source dirs, exclude tests/comments. Acceptable.

**Compound severity table maintenance** → Mitigation: start small (4-6 rules), expand based on real scan results. Table lives in pattern-catalog.md, easy to edit.

**Security detection shallow** → Mitigation: explicit non-goal to do deep security analysis. Scanner flags presence/absence of security patterns, not their correctness. Deeper analysis belongs in dedicated security tools.

**Skill dedup heuristic may be wrong** → Mitigation: dedup only flags for user decision, never auto-merges. User sees "these skills overlap — merge or keep separate?" in Phase 2 report.
