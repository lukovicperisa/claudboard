## 1. Baseline & instrumentation

- [ ] 1.1 Run `/claudboard-workflow` on a Bosch-style repo (craftsphere or a MEAS service) with `time`, capture transcript and tool-call count → record as `baseline-craftsphere.md`
- [ ] 1.2 Run `/claudboard-workflow` on a GitHub-flavored project (one with GitHub MCP + Jira MCP), capture transcript and tool-call count → record as `baseline-github.md`
- [ ] 1.3 Run `/claudboard-workflow` in workspace mode (a 3+ repo workspace with meta-repo bootstrapped), capture timings and tool-call count → record as `baseline-workspace.md`
- [ ] 1.4 Note token usage from the runs (input + output) for cost baseline

## 2. Lever 1 — Detection script (`scripts/detect.sh`)

- [x] 2.1 Define the v1 JSON schema in `skills/claudboard-workflow/scripts/schema/detect-v1.md` (shape, field semantics, examples, ambiguity / warning encodings)
- [x] 2.2 Create `skills/claudboard-workflow/scripts/detect.sh`: argument parsing (`<project-path>`), preflight (`jq` availability check with actionable error), top-level JSON assembly
- [x] 2.3 Implement MCP detection block: read `.mcp.json` (project), `~/.claude/mcp_servers.json`, `~/.claude.json` (user); apply the four keyword tables; record source + matched_via per detected backend
- [x] 2.4 Implement project-level precedence resolution inside the script (project-level entries suppress conflicting user-level entries in the same dimension)
- [x] 2.5 Implement ambiguity detection: when both backends in a dimension match, populate the `ambiguities` array with the conflicting source paths (the SKILL.md prompts the user; the script does NOT prompt)
- [x] 2.6 Implement git remote parsing block: run `git remote -v` in the project; apply Azure DevOps + GitHub URL regex tables; populate the `git_remote` block
- [x] 2.7 Implement sibling scan block: enumerate `../*/` under the project parent; for each that contains `.claude/skills/feature-workflow/config.json`, read and summarize the inheritable fields into the `siblings` array
- [x] 2.8 Implement the `unresolved` block computation: derive per-dimension lists of config fields that detection could not satisfy
- [x] 2.9 Add `schema_version` field and the `warnings` array for soft-failure conditions (malformed JSON, exotic encodings, indirect-match warnings)
- [x] 2.10 Test `detect.sh` on darwin (BSD shell tools) and linux (GNU shell tools) for portability; fix any flag incompatibilities
- [x] 2.11 Test `detect.sh` against craftsphere fixture; diff output JSON against hand-curated expected JSON for that repo
- [x] 2.12 Test `detect.sh` against a GitHub-flavored fixture; diff output JSON against expected
- [x] 2.13 Test `detect.sh` against a workspace-mode fixture (run from inside one of the workspace repos); confirm sibling scan picks up the right peers
- [x] 2.14 Update `skills/claudboard-workflow/SKILL.md` Phase 1d, 2a, 2b sections to invoke `scripts/detect.sh` and consume the JSON; keep legacy prose path under a "Fallback: detect.sh unavailable" subsection
- [x] 2.15 Add `schema_version` assertion to SKILL.md with the actionable error message
- [ ] 2.16 Re-run baseline 1.1 with Lever 1 in place; record wall-clock + tool-call delta

## 3. Lever 2 — Conditional reference loading

- [x] 3.1 Add "Reference Load Gates" subsection to workflow SKILL.md (mapping table per D3 in design.md)
- [x] 3.2 Replace unconditional load instructions for `references/tracker-config-prompts.md` with a gated load keyed off `mcp.tracker_jira || mcp.tracker_tr` AND non-empty `unresolved.tracker`
- [x] 3.3 Replace unconditional load instructions for `references/repo-config-prompts.md` symmetrically (repo dimension)
- [x] 3.4 Move `references/block-catalog.md` load to Phase 3 (render time) only; add explicit "load at the start of Phase 3" instruction
- [x] 3.5 Move `references/substitution-catalog.md` load to Phase 3 (render time) only
- [ ] 3.6 Run `/claudboard-workflow` on craftsphere (fully resolved single tracker + repo); verify model loads neither prompt-reference file
- [ ] 3.7 Run `/claudboard-workflow` on a fixture with missing `jira.cloudId`; verify model loads only `tracker-config-prompts.md`
- [ ] 3.8 Confirm generated `feature-workflow/` output is byte-identical to the pre-change run on the same fixture

## 4. Lever 3 — SKILL.md trim

- [x] 4.1 Catalog the data blocks currently in workflow SKILL.md: MCP keyword tables (Phase 1d Step 2), git remote regex tables (Phase 2a), sibling-inheritance field allowlist (Phase 2b)
- [x] 4.2 Confirm MCP keyword tables now live inside `detect.sh` (encoded as the script's matching logic); remove from SKILL.md
- [x] 4.3 Confirm git remote regex tables now live inside `detect.sh`; remove from SKILL.md
- [x] 4.4 Create `references/sibling-inheritance.md` containing the field allowlist (the "can be inherited" / "must not be inherited" lists)
- [x] 4.5 Update SKILL.md Phase 2b to reference `references/sibling-inheritance.md` instead of inlining the lists; gate the load on `siblings` non-empty
- [x] 4.6 Collapse Phase 1d Steps 1-6 prose to the new shorthand: "run `scripts/detect.sh`, read `mcp` block, apply Step 4 dimension-resolution prompt only if `ambiguities` is non-empty, apply Step 5 halt-on-conflict guard"
- [x] 4.7 Measure workflow SKILL.md final size; confirm ≤6K tokens / ≤550 lines (per Requirement: workflow SKILL.md size budget) — 546 lines ✓
- [x] 4.8 If over budget, identify additional procedural-but-data lines to migrate; iterate

## 5. End-to-end validation

- [ ] 5.1 Re-run `/claudboard-workflow` on craftsphere; capture wall-clock + tool-call count + token usage; compute deltas vs baseline 1.1
- [ ] 5.2 Re-run `/claudboard-workflow` on the GitHub-flavored fixture; compute deltas vs baseline 1.2
- [ ] 5.3 Re-run `/claudboard-workflow` in workspace mode; compute deltas vs baseline 1.3
- [ ] 5.4 Diff generated `feature-workflow/` output between baseline and post-change runs for each fixture; confirm byte-identical for the same inputs
- [ ] 5.5 Verify schema_version mismatch path: hand-edit `detect.sh` to emit `schema_version: "999"`; confirm SKILL.md stops with the actionable error
- [ ] 5.6 Verify fallback path: rename `scripts/detect.sh` temporarily; confirm SKILL.md uses the legacy prose path and still produces a working `feature-workflow/`

## 6. Documentation & release

- [x] 6.1 Update `skills/claudboard-workflow/SKILL.md` header comment (if any) noting the script-driven detection path
- [x] 6.2 Add a short note in `CLAUDE.md` (this repo) under "Generated feature-workflow" or a sibling section pointing at `scripts/detect.sh` as the detection contract
- [ ] 6.3 Archive this change once 5.4 passes on all three fixtures (`openspec archive speed-up-workflow`)
