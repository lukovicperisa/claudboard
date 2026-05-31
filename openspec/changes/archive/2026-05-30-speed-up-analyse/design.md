## Context

`/analyse` is the entry point for every claudboard workflow: `/generate`, `/refresh`, `/techdebt`, and `/claudboard-workflow` all consume the report it writes. Today it takes ~10 min on small projects and close to an hour on workspaces, with per-run cost in the $1–10+ range depending on size. Static measurement of this repo identified four compounding cost drivers:

- **Tool-call round-trips dominate.** Each individual `grep` / `find` / `Read` is one tool call with ~5–15s of overhead (model decide → emit → execute → result → parse). Phase 1c (Wide Scan) alone fires 20+ greps; the full grep universe a Java workspace run could fire is ~200 commands.
- **Bloated raw output in the conversation tail.** Each grep dumps `file:line:matched-text` for every hit, accumulating ~18K tokens of low-density text the model then has to re-read on subsequent turns.
- **Unconditional reference loading.** `workflow-signals.md` + `edges/*.md` + `patterns/architectural.md` (~14K tokens combined) load on every run, even on REST-only repos where the messaging/streaming/GraphQL/architectural-pattern detection has nothing to find.
- **Inline catalogs in SKILL.md.** Language-specific trigger lists (Spring annotations, frontend hooks, Python decorators) sit inside analyse SKILL.md (~11.9K tokens always loaded) instead of in language-pack data files that already get conditionally loaded.

Workspace mode amplifies all four because each sub-agent re-pays the per-repo cost. Fixing the per-repo flow lifts both single-project and workspace performance.

The reports themselves are small (1.9–3.3K tokens each), so report generation (Phase 2) is NOT the bottleneck and is out of scope.

## Goals / Non-Goals

**Goals:**
- Cut `/analyse` single-project wall-clock by 50–70% on a 200–500-file Spring Boot project.
- Cut `/analyse` workspace wall-clock by 50%+ on a 5-repo Java workspace.
- Cut per-run token cost by 25–50% across modes.
- Preserve report content fidelity: same sections, same YAML frontmatter, same file paths.
- Make the discovery-script output a versioned contract so the SKILL.md and script can evolve safely together.
- Keep all four levers composable: each can be shipped and validated independently.

**Non-Goals:**
- Workspace parallel fan-out audit (cost-neutral; tracked separately).
- Perf passes on `/generate`, `/refresh`, `/techdebt` (learnings transfer but not bundled here).
- Changing what `/analyse` detects (patterns, anti-patterns, quality dimensions, workflow signals) — only how the detection executes.
- Changing the report consumers (`/generate`, `/refresh`, `/claudboard-workflow`, `/techdebt`).

## Decisions

### D1. Composable discovery scripts under `scripts/`

`skills/claudboard-analyse/scripts/discover.sh` is the orchestrator entry point invoked with the repo path. It runs Phase 1b (global file scan), Phase 1c (Wide Scan), and Phase 1g (duplication detection) in one bash invocation. Language packs live as `scripts/lang/{java,typescript,python,go,rust,dotnet}.sh` and the orchestrator dispatches to whichever packs match detected build files.

**Alternatives considered:**
- *One monolithic script with all language greps inlined* — rejected: hard to maintain, runs irrelevant greps, and the per-language file is exactly the right boundary because language packs already exist as `stack-detectors-*.md`.
- *Python script for richer JSON shaping* — rejected: introduces a runtime dependency the rest of the repo doesn't need. Bash + `jq` (already available on darwin/linux) is sufficient and matches the existing skill conventions.

### D2. Versioned JSON output schema

`discover.sh` emits a single JSON document with a top-level `schema_version` field. The SKILL.md asserts on the version and stops with a clear error if mismatched. v1 schema (shape, not exhaustive):

```
{
  "schema_version": "1",
  "repo": { "path": "...", "languages": ["java"], "source_file_count": 412 },
  "build_files": { ... },         // category → list of detected paths
  "wide_scan": {
    "skill_triggers": { "@RestController": { "count": 18, "best_example": "..." }, ... },
    "anti_patterns": { "autowired": 12, "null_returns": 5, ... },
    "conventions": { "di_style": "constructor", "logging": "slf4j" },
    "inheritance_map": [ { "base": "...", "subclasses": 43 }, ... ],
    "god_class_candidates": [ { "file": "...", "loc": 609 }, ... ]
  },
  "duplication": { "candidates": [ ... ] },
  "ref_load_signals": {
    "messaging": true,    // any kafka/amqp/jms/sns/sqs/solace/rabbitmq hit
    "streaming": false,   // any websocket/sse/rsocket hit
    "graphql": false,     // any graphql hit
    "architectural": true // any saga/cqrs/outbox hit
  }
}
```

The `ref_load_signals` block is the explicit contract for Lever 2 — the SKILL.md reads booleans, not raw greps, when deciding which references to load.

**Alternatives considered:**
- *Multiple JSON outputs* (one per phase) — rejected: defeats the round-trip consolidation goal.
- *Streaming JSON lines* — rejected: complicates parsing without saving anything; the full document is small (estimated 2–4K tokens vs ~18K of raw grep output).

### D3. Conditional reference loading expressed as a load table

The analyse SKILL.md adds a "Reference Load Gates" subsection that maps `ref_load_signals.*` booleans to specific reference files. Loading prose moves from "always load these refs" to "after reading the discovery JSON, load only the refs whose gate is true." The gates:

| Gate signal | Reference loaded when true |
|---|---|
| `messaging` | `edges/messaging.md` |
| `streaming` | `edges/streaming.md` |
| `graphql` | `edges/graphql.md` |
| `architectural` | `patterns/architectural.md` |

`workflow-signals.md` itself stays unconditional (it's the dispatcher schema). The savings come from skipping the four sub-catalogs when their signals are absent.

**Alternative considered:** automated ref filtering driven by a manifest — rejected: more machinery for the same effect; explicit gates in the SKILL.md are readable and reviewable.

### D4. Elastic phase rules

Phase 1f (call-path tracing) and Phase 1g (duplication detection) move from fixed budgets to signal-driven budgets:

- **Call-path tracing.** Path types in the existing table (`Simple CRUD`, `Complex business`, `Async/event`, `Auth/security`, `External integration`) each have a "When to include" condition. Today the prose says "trace 3-5 paths" and lists the types. The new rule: trace exactly the path types whose condition is true in the discovery JSON. Always-included types stay; conditional types drop when their signal is missing. Expected: 2-3 paths on simple repos, 5 on complex ones.
- **Duplication detection.** Skip entirely when `repo.source_file_count < 30`. Small repos don't have enough surface area to harbor copy-paste duplication, and the grep cost isn't justified.

### D5. SKILL.md trim — catalogs move to language packs

The trigger lists at analyse SKILL.md lines ~299-333 (Spring/frontend/Python/infrastructure trigger annotations) and the anti-pattern grep block at ~338-362 are language-specific data, not procedure. They move into the corresponding `stack-detectors-{java,typescript,python,...}.md` reference files. The SKILL.md keeps the procedure (when to run Wide Scan, how to use the results) but defers the specific patterns to the language pack already being loaded for that repo.

Target sizes:
- analyse SKILL.md: 1,035 → ~700-750 lines (~11.9K → ~7-8K tokens)
- stack-detectors-java.md and siblings: grow ~50-100 lines each to absorb their share

### D6. Backwards compatibility & rollback

The discovery script is additive — the existing prose-driven Phase 1b/1c/1g paths remain in the SKILL.md as a fallback section labeled "If scripts/discover.sh is unavailable (legacy path)." The fallback exists so the skill still works when run on a stripped clone of the repo or when bash is unavailable in some sandbox. After two release cycles of stable script use, the fallback can be removed in a follow-up change.

## Risks / Trade-offs

- **Script ↔ SKILL.md drift** → Mitigation: `schema_version` field in JSON output; SKILL.md asserts on it; bumping the version is a breaking-change checklist item.
- **Cross-platform grep flag differences (BSD vs GNU)** → Mitigation: stick to the portable subset (`grep -rn`, `-l`, `-c`, `-E` extended regex, `--include`). No `-P`, no GNU-only flags. Test on darwin (BSD grep) and linux (GNU grep) before merge.
- **`jq` not always installed** → Mitigation: detect once at script start; if missing, emit a clear error pointing the user at `brew install jq` / `apt install jq`. Don't try to hand-roll JSON in pure bash.
- **Discovery JSON parsing in the model** → Mitigation: keep the JSON shallow and well-named; the model is already good at reading structured JSON.
- **Conditional ref loading misses a real signal** → Mitigation: gates are explicit and conservative; when in doubt, load the ref. The cost of a false-positive load is ~5K tokens; the cost of a false-negative (missing a real pattern) is wrong report content. Bias toward loading when ambiguous.
- **Elastic phases under-report on complex repos** → Mitigation: the path-type conditions are the same ones the prose already uses informally; we're just enforcing them. Validate on craftsphere (5+ path types fire) and azure-devops-mcp (2-3 fire).
- **Workspace mode regression** → Mitigation: sub-agents invoke the same `discover.sh` scoped to their repo. Validate on a 3+ repo workspace before merging; the orchestrator's coordination logic is unchanged.

## Migration Plan

Levers ship in this order so each can be validated independently before stacking the next:

1. **Lever 1 (discovery script) first** — biggest win, establishes the JSON contract subsequent levers consume. Test on craftsphere + azure-devops-mcp; compare report content diff and tool-call counts.
2. **Lever 2 (conditional ref loading)** — drops in once the `ref_load_signals` block is reliable.
3. **Lever 3 (elastic phases)** — drops in once the discovery JSON exposes the per-signal evidence the gates need.
4. **Lever 4 (SKILL.md trim)** — last, because it's the most invasive textual change to the SKILL.md and benefits most from the surrounding cleanup already being in place.

Rollback: revert the SKILL.md changes and delete `scripts/`. The skill returns to the prose-driven path with no other state to clean up.

## Open Questions

- Should `discover.sh` produce a small markdown summary alongside the JSON for human inspection during dev (e.g., `discover.sh --human`)? Defer to implementation.
- Is the v1 JSON schema sufficient for `/techdebt` to consume too, or do we keep them independent for now? Defer — `/techdebt` perf is out of scope here, but the schema should not paint us into a corner.
- Where does `git log` hotspot detection (Phase 1d step 5) live — inside `discover.sh` or as a separate per-file read? Probably inside, since it's one git command. Confirm during design implementation.
