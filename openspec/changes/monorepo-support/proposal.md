## Why

Claudboard treats every repository as a single-project blob. For monorepos with multiple services and shared libraries, this produces misleading results: quality scores are averaged across services with different maturity, conventions from one service bleed into rules for another, and techdebt findings lack service-scoped ownership. craftsphere.cloud — our primary test project — is a monorepo, so this gap directly affects our golden-standard evaluation.

## What Changes

- **Monorepo auto-detection** in analyse Phase 1a: find independent build roots, classify each as service or library using Dockerfile presence, main entry point, and publish task signals
- **Per-service full analysis**: run complete Phase 1 (d-f) and Phase 2 per detected service, producing N+1 reports (one global + one per service)
- **Global analysis layer**: CI/CD, GitOps/IaC, cross-service communication, shared library inventory, branch/commit conventions — reported once at repo level
- **Per-service scoped artifact proposals**: each service report proposes rules with `paths:` frontmatter scoped to that service's directory
- **Namespaced techdebt IDs**: per-service prefix (e.g., `OS-01` for order-service, `FE-01` for frontend) with cross-report dependency support
- **Generate consumes N+1 reports**: reads global + all service reports, produces CLAUDE.md with monorepo topology and per-service build/test commands, plus per-service scoped rules
- **Refresh handles service additions/removals**: detects new services since last scan, removed services with stale reports

## Capabilities

### New Capabilities
- `monorepo-detection`: Auto-detect monorepo structure, classify build roots as services vs libraries
- `per-service-analysis`: Run full analysis and techdebt per service with scoped reports and namespaced IDs
- `monorepo-generation`: Generate CLAUDE.md and rules from N+1 analysis reports with per-service scoping

### Modified Capabilities
- `techdebt-scanner`: TD-ID namespacing with service prefix, cross-report dependencies

## Impact

- **analyse SKILL.md**: Phase 1a restructured, Phase 1d-f runs per service, Phase 2 produces N+1 reports
- **techdebt SKILL.md**: Per-service scanning, prefixed TD-IDs, cross-report `Depends on` field
- **generate SKILL.md**: Multi-report consumption, monorepo CLAUDE.md template, per-service rules
- **refresh SKILL.md**: Service addition/removal detection in delta discovery
- **stack-detectors.md**: Service boundary detection heuristics added
- **claude-md-template.md**: Monorepo variant section added
- **severity-matrix.md**: No structural changes, but techdebt-scanner spec updated for ID namespacing
