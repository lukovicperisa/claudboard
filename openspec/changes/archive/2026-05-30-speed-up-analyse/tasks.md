## 1. Baseline & instrumentation

- [ ] 1.1 Run `/analyse` on craftsphere.cloud (single Java service) with `time`, capture transcript and tool-call count → record as `baseline-craftsphere.md`
- [ ] 1.2 Run `/analyse` on azure-devops-mcp (TS service) with `time`, capture transcript and tool-call count → record as `baseline-azure-devops-mcp.md`
- [ ] 1.3 Run `/analyse` on a 3+ repo workspace (e.g., a synthetic 3-service Spring workspace), capture per-sub-agent + orchestrator timings → record as `baseline-workspace.md`
- [ ] 1.4 Note token usage from the runs (input + output) for cost baseline

## 2. Lever 1 — Discovery script (`scripts/discover.sh`)

- [x] 2.1 Define the v1 JSON schema in `skills/claudboard-analyse/scripts/schema/discover-v1.md` (shape, field semantics, examples)
- [x] 2.2 Create `skills/claudboard-analyse/scripts/discover.sh` orchestrator: argument parsing, language detection from build files, dispatch to language packs, JSON assembly via `jq`
- [x] 2.3 Add `scripts/lang/_common.sh` for shared greps (build files, infra, CI/CD, docs, existing `.claude/`)
- [x] 2.4 Add `scripts/lang/java.sh` covering Spring annotation triggers, Java anti-patterns, Java conventions, Java security/observability greps
- [x] 2.5 Add `scripts/lang/typescript.sh` covering React/Next/Vue triggers, TS anti-patterns (`any`, `@ts-ignore`), TS conventions
- [x] 2.6 Add `scripts/lang/python.sh` covering FastAPI/Flask/Celery triggers, Python anti-patterns, Pydantic markers
- [x] 2.7 Add `scripts/lang/go.sh` covering Go HTTP frameworks, Go anti-patterns, Go conventions
- [x] 2.8 Add `scripts/lang/rust.sh` covering Actix/Axum/Rocket triggers, Rust conventions
- [x] 2.9 Add `scripts/lang/dotnet.sh` covering ASP.NET Core triggers, .NET anti-patterns
- [x] 2.10 Add `ref_load_signals` computation block to `discover.sh` (messaging/streaming/graphql/architectural booleans)
- [x] 2.11 Add jq-availability preflight; emit actionable error if missing
- [ ] 2.12 Test `discover.sh` on darwin (BSD grep) and linux (GNU grep) for portability; fix any flag incompatibilities
- [ ] 2.13 Test `discover.sh` against craftsphere; diff output JSON against hand-curated expected JSON for that repo
- [ ] 2.14 Test `discover.sh` against azure-devops-mcp; diff output JSON against expected
- [x] 2.15 Update `skills/claudboard-analyse/SKILL.md` Phase 1b/1c/1g sections to invoke `scripts/discover.sh` and consume the JSON; keep legacy prose path under a "Fallback: discover.sh unavailable" subsection
- [x] 2.16 Add `schema_version` assertion to SKILL.md with the actionable error message
- [ ] 2.17 Re-run baseline 1.1 with Lever 1 in place; record wall-clock + tool-call delta

## 3. Lever 2 — Conditional reference loading

- [x] 3.1 Add "Reference Load Gates" subsection to analyse SKILL.md (mapping table per D3 in design.md)
- [x] 3.2 Replace unconditional load instructions for `edges/messaging.md`, `edges/streaming.md`, `edges/graphql.md`, `patterns/architectural.md` with gated loads keyed off `ref_load_signals.*`
- [x] 3.3 Confirm `workflow-signals.md` stays unconditional (dispatcher schema)
- [ ] 3.4 Run `/analyse` on craftsphere (REST-only Java); verify model loads none of the four gated refs
- [ ] 3.5 Run `/analyse` on a Kafka-using repo; verify model loads only `edges/messaging.md`
- [ ] 3.6 Confirm reports still produce `cross_service_edges: []` and `architectural_patterns: []` correctly when refs are skipped

## 4. Lever 3 — Elastic phases

- [x] 4.1 Update Phase 1f prose: replace "trace 3-5 paths" with "trace each path type whose `When to include` condition is satisfied by the discovery JSON"
- [x] 4.2 Make each path type's condition machine-verifiable against discovery JSON fields (Simple CRUD: always; Complex business: god_class_candidates non-empty; Async/event: `@Async` or `@EventListener` count > 0; Auth/security: custom auth annotations count > 0; External integration: `@FeignClient` or HTTP client count > 0)
- [x] 4.3 Update Phase 1g prose: add "Skip when `repo.source_file_count < 30`" as an explicit precondition
- [x] 4.4 Update Phase 2 report template so the "Code duplication" line is "None detected" when 1g was skipped (no disclaimer)
- [ ] 4.5 Validate on craftsphere (expect 4-5 paths) and azure-devops-mcp (expect 2-3 paths)

## 5. Lever 4 — SKILL.md trim

- [x] 5.1 Catalog the Wide Scan trigger blocks currently in analyse SKILL.md lines ~299-333 (Spring, frontend, Python, infra)
- [x] 5.2 Move Spring annotation triggers into `stack-detectors-java.md`
- [x] 5.3 Move React/TypeScript triggers into `stack-detectors-typescript.md`
- [x] 5.4 Move Python decorator triggers into `stack-detectors-python.md`
- [x] 5.5 Move infrastructure markers (migrations, helm, pulumi) into a new shared `stack-detectors-infra.md` (or distribute per-language if cleaner)
- [x] 5.6 Move the inline anti-pattern grep block (lines ~338-362) into the per-language stack-detectors files
- [x] 5.7 Update analyse SKILL.md Phase 1c prose to say "load the language pack matching detected stack; trigger and anti-pattern catalogs live there"
- [x] 5.8 Measure analyse SKILL.md final size; confirm ≤8K tokens / ≤750 lines (per Requirement: analyse SKILL.md size budget)
- [x] 5.9 If over budget, identify additional procedural-but-data lines to migrate; reiterate

## 6. End-to-end validation

- [ ] 6.1 Re-run `/analyse` on craftsphere; capture wall-clock + tool-call count + token usage; compute deltas vs baseline 1.1
- [ ] 6.2 Re-run `/analyse` on azure-devops-mcp; compute deltas vs baseline 1.2
- [ ] 6.3 Re-run `/analyse` on the workspace fixture; compute deltas vs baseline 1.3
- [ ] 6.4 Verify success criteria from proposal: ≥50% single-project wall-clock reduction, ≥50% workspace wall-clock reduction, 25-50% token cost reduction
- [ ] 6.5 Diff post-change reports vs baseline reports; confirm content equivalence (modulo non-deterministic ordering)
- [ ] 6.6 Run `/generate` on a project whose report was produced by post-change `/analyse`; confirm it proceeds without errors and produces the same artifacts
- [ ] 6.7 Run `/refresh` and `/claudboard-workflow` against the same post-change report; confirm no consumer regressions

## 7. Documentation & cleanup

- [x] 7.1 Update CLAUDE.md "Skill Anatomy" section to mention `scripts/discover.sh` under `claudboard-analyse/`
- [x] 7.2 Add a "Reference Load Gates" entry to the analyse SKILL.md "Reference Files" table at the bottom
- [x] 7.3 Update `references/quality-signals.md` "Adaptive Depth" section if anything there assumed prose-driven Wide Scan path
- [x] 7.4 Note the `discover.sh` v1 schema version and document the schema-bump procedure in the analyse SKILL.md
- [ ] 7.5 Record baseline + post-change measurements in the change archive as part of `/opsx:archive`
