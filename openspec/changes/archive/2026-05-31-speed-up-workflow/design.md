## Context

`/claudboard-workflow` is the second entry point in the claudboard pipeline — it runs after `/analyse` and `/generate` have prepared the project, and it writes a tailored `feature-workflow/` skill into the target project (or workspace meta-repo). Today it takes several minutes per run on a typical Bosch repo, with per-run cost dominated by:

- **Tool-call round-trips in detection.** Phase 1d (MCP detection) reads 1-3 config files and applies four keyword tables in prose across 6 documented steps. Phase 2a runs `git remote -v` and applies two URL regex tables in prose. Phase 2b scans `../*/` for sibling `.claude/skills/feature-workflow/config.json` files and reads each. Net: 5-10 separate tool calls executing rules that are pure data.
- **Bloated reference loads.** `block-catalog.md` (589 lines) and `substitution-catalog.md` (589 lines) load on every run, even though their content only matters at Phase 3 render time. `tracker-config-prompts.md` (439 lines) and `repo-config-prompts.md` (214 lines) load on every run, even when their dimension is fully auto-resolved and no prompts will fire.
- **Inline data in SKILL.md.** The MCP keyword tables (Phase 1d Step 2, ~15 lines), git remote regex tables (Phase 2a, ~30 lines), sibling-inheritance field allowlist (Phase 2b, ~20 lines), and prompt field tables (Phase 2c, ~80 lines) sit inside the 852-line SKILL.md (~9.5K tokens always loaded) instead of being data the script consumes or a small reference file.

The generated `feature-workflow/` skill itself is the output and not a cost lever here — its size is the concern of the sibling `slim-feature-workflow-*` changes. This change is strictly about the generator's per-run efficiency.

## Goals / Non-Goals

**Goals:**
- Cut `/claudboard-workflow` wall-clock by 30-50% on a typical Bosch repo (one tracker + one repo backend resolved).
- Cut per-run token cost by 25-40% across modes.
- Preserve generated-artifact fidelity: byte-identical output for the same inputs.
- Make the detection-script output a versioned contract so the SKILL.md and script can evolve safely together — mirroring the speed-up-analyse contract style.
- Keep all levers composable: each can be shipped and validated independently.

**Non-Goals:**
- Render automation (capability-block resolution, template substitution) — explicitly deferred.
- Slimming the generated `feature-workflow/` artifact — covered by sibling changes.
- `/generate` performance — deferred (see explore session: was excluded because /generate is already lean and output-bound).
- Changing what `/claudboard-workflow` generates, prompts, or guards against — only how detection and config-gathering execute.

## Decisions

### D1. Single detection script under `scripts/`

`skills/claudboard-workflow/scripts/detect.sh` is invoked with the target project path. It runs Phase 1d (MCP detection), Phase 2a (git remote parsing), and Phase 2b (sibling-repo `config.json` scan) in one bash invocation. The script encapsulates:

- The four MCP keyword tables (Atlassian Jira, Bosch T&R, Azure DevOps, GitHub)
- The Azure DevOps and GitHub URL regex tables for git remote
- The sibling-repo filesystem scan (`../*/.claude/skills/feature-workflow/config.json`)
- Project-level vs user-level precedence resolution for MCP detection

The script reads from but does NOT modify the project. All output goes to stdout as a single JSON document.

**Alternatives considered:**
- *Multiple scripts per phase* — rejected: defeats round-trip consolidation; nothing about the three phases needs to run separately.
- *Python script for richer parsing* — rejected: bash + `jq` matches the speed-up-analyse precedent and avoids a new runtime dependency.
- *Inline detection in SKILL.md prose (status quo)* — rejected: that's exactly what we're moving away from.

### D2. Versioned JSON output schema

`detect.sh` emits a single JSON document with a top-level `schema_version` field. The SKILL.md asserts on the version and stops with a clear error if mismatched. v1 schema (shape, not exhaustive):

```
{
  "schema_version": "1",
  "mcp": {
    "tracker_jira": false,
    "tracker_tr": true,
    "repo_ado": true,
    "repo_github": false,
    "sources": {
      "tracker_tr": { "source": "project", "config_path": ".mcp.json", "matched_via": "name" },
      "repo_ado":  { "source": "user",    "config_path": "~/.claude.json", "matched_via": "args" }
    },
    "ambiguities": []     // populated when both backends in a dimension matched
  },
  "git_remote": {
    "provider": "azure-devops",
    "azure_devops": { "org": "bosch-meas", "project": "platform", "repo": "datahandler" },
    "github": null
  },
  "siblings": [
    {
      "path": "../order-service",
      "config_summary": { "jira_projectKey": "PLAT", "jira_urlBase": "https://example.atlassian.net" }
    }
  ],
  "unresolved": {
    "tracker": ["jira.cloudId", "jira.projectKey"],   // empty when tracker fully resolved
    "repo":    ["azureDevOps.repositoryId"]
  }
}
```

The `unresolved` block is the explicit contract for Lever 2 — the SKILL.md decides which prompt-reference files to load based on whether either array is non-empty.

**Alternatives considered:**
- *Stream the result as text lines* — rejected: complicates parsing without saving anything; the document is small.
- *Separate JSON file per phase* — rejected: defeats consolidation.

### D3. Conditional reference loading expressed as a load table

The workflow SKILL.md adds a "Reference Load Gates" subsection that maps detection JSON state to specific reference files. The gates:

| Reference file | Load when |
|---|---|
| `references/tracker-config-prompts.md` | `mcp.tracker_jira || mcp.tracker_tr` AND `unresolved.tracker` is non-empty |
| `references/repo-config-prompts.md` | `mcp.repo_ado || mcp.repo_github` AND `unresolved.repo` is non-empty |
| `references/sibling-inheritance.md` (NEW) | `siblings` is non-empty AND a Phase 2b inheritance offer is being prepared |
| `references/block-catalog.md` | Phase 3 render time only |
| `references/substitution-catalog.md` | Phase 3 render time only |

The `block-catalog.md` and `substitution-catalog.md` gating is the bigger win — ~21K tokens of catalog content moves from "loaded every run" to "loaded only when rendering." The prompt-reference gating saves another ~7K tokens on runs with fully-resolved config.

**Alternative considered:** a manifest-driven autoload mechanism — rejected: more machinery for the same effect; explicit gates in the SKILL.md mirror the speed-up-analyse pattern and are reviewable.

### D4. SKILL.md trim — data moves to detect.sh or to a tiny reference

The workflow SKILL.md trims by relocating:

- **Phase 1d Step 2 MCP keyword tables (~15 lines)** → encoded inside `detect.sh`. The SKILL.md keeps the "what dimensions exist and how to interpret the JSON" narrative; the rules execute in the script.
- **Phase 2a Azure DevOps + GitHub URL regex tables (~30 lines)** → encoded inside `detect.sh`. The SKILL.md keeps the "auto-detect from git remote happens here" narrative.
- **Phase 2b sibling-inheritance field allowlist (~20 lines)** → moves to `references/sibling-inheritance.md` (new small reference). Loaded only when siblings are present.
- **Phase 1d Steps 1-6 prose (~80 lines)** → collapses to "run `scripts/detect.sh`, read `mcp` block, apply Step 4 dimension-resolution prompt only if `ambiguities` is non-empty, apply Step 5 halt-on-conflict guard."

Procedure stays in SKILL.md; data and rule application move to the script. Target sizes:

- workflow SKILL.md: 852 → ~500 lines (~9.5K → ~5.5K tokens)
- `detect.sh`: ~250-350 lines including the keyword/regex data and JSON assembly
- `references/sibling-inheritance.md`: ~30 lines

### D5. Backwards compatibility & rollback

The detection script is additive — the existing prose-driven Phase 1d/2a/2b paths remain in the SKILL.md under a "If scripts/detect.sh is unavailable (legacy path)" subsection. The fallback exists so the skill still works when run on a stripped clone of the repo or when bash is unavailable in some sandbox. After two release cycles of stable script use, the fallback can be removed in a follow-up change.

This mirrors speed-up-analyse's D6.

## Risks / Trade-offs

- **Script ↔ SKILL.md drift** → Mitigation: `schema_version` field in JSON output; SKILL.md asserts on it; bumping the version is a breaking-change checklist item. Same mechanism as speed-up-analyse.
- **Cross-platform shell differences (BSD vs GNU)** → Mitigation: stick to the portable subset (POSIX `grep`, `awk`, `sed`); no `-P`, no GNU-only flags. Test on darwin and linux before merge.
- **`jq` not always installed** → Mitigation: detect once at script start; if missing, emit a clear error pointing the user at `brew install jq` / `apt install jq`. Don't try to hand-roll JSON in pure bash.
- **MCP config file shape varies** → Mitigation: the script reads `.mcp.json`, `~/.claude/mcp_servers.json`, and `~/.claude.json` defensively, treating missing files as empty. Edge cases (malformed JSON, exotic encodings) produce a structured warning in the JSON output, not a script abort — the SKILL.md surfaces warnings to the user.
- **Git remote regex misses an exotic URL** → Mitigation: the regex tables are the same patterns currently encoded in prose. Unrecognised URLs are silently skipped in both paths, matching today's behavior. The SKILL.md still prompts in Phase 2c for unresolved fields.
- **Sibling-config scan may surface stale or experimental configs** → Mitigation: the script reports siblings; the SKILL.md still asks the user before inheriting. No behavior change vs today.
- **Render-time refs (block-catalog, substitution-catalog) not loading early enough** → Mitigation: the SKILL.md's Phase 3 instructions become explicit: "load these refs at the start of Phase 3, before rendering." Validate during Phase 3 walkthrough.
- **Conditional prompt-ref loading misses a real need** → Mitigation: gates are explicit and conservative. When in doubt, load. The cost of a false-positive load is ~3-5K tokens; the cost of a false-negative is a missing prompt.

## Migration Plan

Levers ship in this order so each can be validated independently before stacking the next:

1. **Lever 1 (detection script) first** — biggest single round-trip win, establishes the JSON contract subsequent levers consume. Test on craftsphere + a Bosch MEAS repo; compare detection results to the prose-driven path and validate identical config gathering.
2. **Lever 2 (conditional ref loading)** — drops in once `unresolved` and the catalog-gating semantics are reliable.
3. **Lever 3 (SKILL.md trim)** — last, because it's the most invasive textual change to the SKILL.md and benefits most from the surrounding cleanup already being in place.

Rollback: revert the SKILL.md changes and delete `scripts/`. The skill returns to the prose-driven path with no other state to clean up.

## Open Questions

- Should `detect.sh` accept a `--workspace-root` flag for workspace mode, or always detect workspace mode from the project structure? Defer to implementation — the script needs to know which `.mcp.json` to read first either way.
- Is the v1 JSON schema sufficient for the future `render.sh` to consume the same `mcp` and `git_remote` blocks, or should render.sh have its own schema? Defer — render automation is explicitly out of scope, but the schema shouldn't paint us into a corner.
- Should the `sibling-inheritance.md` reference also include the inheritance offer wording (currently mostly in `tracker-config-prompts.md` and `repo-config-prompts.md`), or stay just the field allowlist? Defer to implementation — depends on what the trim measurement reveals.
