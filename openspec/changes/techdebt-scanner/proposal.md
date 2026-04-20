# Tech Debt Scanner

## Problem

Claudboard detects anti-patterns during analysis but reports them as quality signals — side observations in a broader codebase scan. There's no dedicated, thorough tech debt analysis that produces a report structured for conversion into refactoring tickets.

Teams need a one-shot, mid-exhaustive scan that goes deeper than claudboard-analyse: tracing call paths for performance debt, reading method bodies for missed design patterns, and clustering God class responsibilities — all producing a module-grouped, ticket-ready report.

## Proposed Solution

New skill `claudboard-techdebt` that:
1. **Reuses** claudboard's Wide Scan + strategic sampling infrastructure (hybrid approach)
2. **Adds** 4 new debt-specific analysis passes: code smells, design pattern analysis, performance flow analysis, architecture debt
3. **Outputs** to `.claude/reports/tech-debt/` with module-grouped debt items + cross-cutting report + priority matrix summary

## Scope

### In scope
- Java/Spring primary focus (extensible later)
- 4 analysis passes: code smells (grep), design patterns (method body reading), performance flows (call-path tracing), architecture debt (cross-module)
- Module-grouped output with ticket-ready debt items (ID, category, severity, location, effort, fix suggestion)
- God class responsibility clustering with split suggestions
- Switch/instanceof → Strategy/polymorphism detection
- Redundant DB call detection in request paths
- Priority matrix (severity × effort)
- Dependency chains between debt items (noted per item, not separate graph)
- Can consume existing claudboard-analysis report if available

### Out of scope
- Non-Java languages (future extension)
- Automatic ticket creation (Jira/Linear integration)
- Incremental/differential scanning (this is run-once-per-repo)
- Auto-fixing detected issues

## Non-goals
- Speed optimization — thoroughness over speed, run once per repo
- Replacing claudboard-analyse — complementary, different purpose
- Generic linting — focuses on design/architecture/performance debt, not style

## Key Decisions
- **Hybrid approach**: reuse Wide Scan infrastructure, add debt-specific passes
- **Mid-exhaustive depth**: grep to find candidates, deep-read top candidates (no hard cap), suggest fix shapes
- **Module grouping**: debt items grouped by module/service, cross-cutting items separate
- **Ticket-ready format**: each item has ID, category, severity, location, effort, description, impact, fix suggestion, dependencies
