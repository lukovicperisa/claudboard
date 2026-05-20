## 1. Script (`scripts/jira-add-labels.sh`)

- [x] 1.1 Create `skills/claudboard-workflow/references/feature-workflow.template/scripts/jira-add-labels.sh` (template) with strict-mode shebang (`set -euo pipefail`) and a usage banner
- [x] 1.2 Implement env-var preflight: fail closed with one-line remediation if `JIRA_EMAIL` or `JIRA_API_TOKEN` is unset
- [x] 1.3 Implement dependency preflight: fail closed if `curl` or `jq` is missing from `PATH`
- [x] 1.4 Parse CLI args: required `--ticket <KEY>` plus one or more `--add <label>` arguments (collect into an array, deduplicate locally)
- [x] 1.5 Read `<config:urlBase>` and `<config:cloudId>` from `.claude/skills/feature-workflow/config.json` via `jq` (no substitution at render time — script reads config at runtime)
- [x] 1.6 Implement Step 1 (read current labels): `GET /rest/api/3/issue/<KEY>?fields=labels` via `curl -u "$JIRA_EMAIL:$JIRA_API_TOKEN"`, capture labels array via `jq -r '.fields.labels[]'`
- [x] 1.7 Implement Step 2 (write additive): `PUT /rest/api/3/issue/<KEY>` with body `{"update":{"labels":[{"add":"L1"},{"add":"L2"},...]}}` constructed by `jq` from the `--add` arguments
- [x] 1.8 Implement Step 3 (verify): re-read labels, assert every label in `(pre ∪ adds)` is present in `post`, emit structured JSON error block and exit non-zero if any are missing
- [x] 1.9 On all success exits, emit a single-line JSON success block to stdout: `{"ticket":"<KEY>","preLabels":[...],"added":[...],"postLabels":[...]}`
- [x] 1.10 Add usage examples and a "Why a script and not the MCP tool?" comment block at the top of the file linking the design doc

## 2. jira-agent template (`agents/jira-agent.md`)

- [x] 2.1 Remove the entire `Action: applyLabels` section
- [x] 2.2 Add a new `Action: addLabels` section documenting: INPUT CONTEXT (`ticketKey`, `labelsToAdd[]`), the single tool call (`Bash` invoking `scripts/jira-add-labels.sh --ticket <key> --add <label> ...`), and the parse-and-return contract for the script's stdout JSON
- [x] 2.3 Modify `Action: create` Step 2: remove `"labels": <labels array>` from `additional_fields` in the `createJiraIssue` call; the resulting call body SHALL contain only `priority` and `<config:acField>`
- [x] 2.4 Modify `Action: create` to add a new "Step 4: Apply additive labels" after Step 3c that invokes the same script-based flow as `addLabels` with the orchestrator-supplied additive set
- [x] 2.5 Modify `Action: fetchAndPrepare`: remove the `existingLabels` field from the result-block schema; remove the "Return the existing labels in the result" paragraph; the result block SHALL contain only `ticketKey`, `ticketUrl`, `existingDescription`, `currentStatus`
- [x] 2.6 Add `Bash` to the `allowedTools` list in the agent frontmatter; verify all other allowed tools are still needed
- [x] 2.7 Replace the "Labels: Use the `labels` array from INPUT CONTEXT exactly as provided" callout in `create` with the equivalent guidance for the additive set

## 3. Orchestrator template (`SKILL.md.template`)

- [x] 3.1 Remove the `mergeLabels(...)` pseudo-code from the "Area-label resolution" section
- [x] 3.2 Remove the `resolveAreaLabel(...)` pseudo-code OR keep it but rename the surrounding section to "Additive label resolution" — it is still used to decide whether to add an area label
- [x] 3.3 Remove all references to `existingLabels` in the orchestrator prose (Phase 1-pre Path A "Compute and apply labels" block)
- [x] 3.4 Rewrite Path A "Compute and apply labels" to compute only `labelsToAdd = ai ∪ {resolvedAreaLabel if non-null}` and invoke `addLabels` with that
- [x] 3.5 Rewrite Path B "Compute labels" section to compute the same additive set and pass it to `create` (which now triggers `addLabels` internally after ticket creation)
- [x] 3.6 Remove the `applyLabels` invocation block in Path A; replace with the `addLabels` invocation block
- [x] 3.7 Verify no other phase in `SKILL.md.template` references `applyLabels`, `mergeLabels`, or `existingLabels` (grep should return empty)

## 4. Config template

- [x] 4.1 Remove the `preserveExisting` field from `jira.labels` in `config.json.template` and its `<!-- IF -->` guards
- [x] 4.2 Confirm `jira.labels.ai` and `jira.labels.area` blocks are unchanged
- [x] 4.3 Add a top-of-file comment block in `config.json.template` documenting that label preservation is now structural (script-based) and not configurable

## 5. Config prompts (`jira-config-prompts.md`)

- [x] 5.1 Remove any prompt entry for `JIRA_LABELS_PRESERVE_EXISTING` (if one exists)
- [x] 5.2 Add a new "Environment-variable requirements" section at the top documenting `JIRA_EMAIL` and `JIRA_API_TOKEN`, including: where to get a Jira API token (link to Atlassian token management page), how to export them for an interactive shell, and the one-line remediation users will see if they forget
- [x] 5.3 Add a callout cross-referencing the new `scripts/jira-add-labels.sh` and noting that no Jira credentials are stored in `config.json` or anywhere in the project tree

## 6. Substitution / block catalog (only if needed)

- [x] 6.1 Check `substitution-catalog.md` — no new `{{VAR}}` tokens are introduced by this change, so likely no edit
- [x] 6.2 Check `block-catalog.md` — the new script is unconditional when `JIRA_AVAILABLE`, so likely no new capability flag

## 7. Verification

- [x] 7.1 Hand-render the template with Craftsphere-style defaults and confirm: `scripts/jira-add-labels.sh` is present, `agents/jira-agent.md` has `addLabels` but no `applyLabels`, `SKILL.md` invokes `addLabels`, `config.json` has no `preserveExisting`
- [x] 7.2 Hand-render with MEAS-style answers (`area: null`) and confirm the orchestrator passes only AI labels to `addLabels`
- [x] 7.3 Trace through each spec scenario against the rendered output and confirm the rendered text instructs the orchestrator/agent correctly for: prior-labels-preserved, empty-prior-labels, newly-created ticket, area-label-null, env-var-missing failure path, and verify-step-catches-loss failure path
- [ ] 7.4 Smoke-test the rendered `jira-add-labels.sh` against a real Jira sandbox: create a test ticket with one label `["Existing"]`, run the script with `--add AI --add AI_CLI`, confirm post-write labels are `["Existing", "AI", "AI_CLI"]` and the script exits 0 with a clean stdout JSON block
- [ ] 7.5 Smoke-test failure paths against the same sandbox: unset `JIRA_API_TOKEN` and confirm clear stderr + non-zero exit; manually mangle the curl output and confirm the verify step catches a simulated label loss
- [x] 7.6 Run `openspec validate jira-additive-labels --strict` and resolve any reported issues
- [x] 7.7 Update `proposal.md` Impact section if any file beyond the listed ones is touched
