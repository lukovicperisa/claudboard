## 1. Reference templates and catalogs

- [x] 1.1 Create `skills/claudboard-workflow/` directory and stub `SKILL.md` with frontmatter and trigger phrases
- [x] 1.2 Copy verbatim portable files into `skills/claudboard-workflow/references/feature-workflow.template/`: `scripts/lib.sh`, `scripts/prepare-commit.sh`, `scripts/prepare-pr.sh`, `scripts/prepare-squash.sh`, `references/claude-pricing.md`, `agents/jira-agent.md` (sourced from craftsphere copy since it's identical to MEAS)
- [x] 1.3 Author `references/feature-workflow.template/config.json.template` with `{{VAR}}` placeholders and `<!-- IF JIRA_AVAILABLE -->` / `<!-- IF ADO_AVAILABLE -->` block fences around the `jira` and `azureDevOps` top-level keys
- [x] 1.4 Author `references/feature-workflow.template/SKILL.md.template` by starting from craftsphere `SKILL.md`, replacing project-specific text with `{{VARS}}`, and wrapping Jira-dependent and ADO-dependent phases in capability blocks
- [x] 1.5 Author `references/feature-workflow.template/agents/git-agent.md.template` and `agents/pr-agent.md.template` (small terminology diffs only)
- [x] 1.6 Author `references/feature-workflow.template/agents/spec-reviewer.md.template` and `agents/design-reviewer.md.template`
- [x] 1.7 Author `references/feature-workflow.template/agents/architect-agent.md.template` using the four-layer model: universal text, `{{VAR}}` substitutions, pointers into `.claude/` context, capability blocks (`WORKSPACE_MODE`, `CROSS_SERVICE_EDGES`, `SHARED_LIB`, `AUTH_PERIMETER`, `MEMORIES_PRESENT`, `MONGODB`, `JPA`, `KAFKA`), and `{{STACK_REMINDERS}}` escape-hatch section
- [x] 1.8 Author `references/feature-workflow.template/agents/implementation-agent.md.template` with the same four-layer structure
- [x] 1.9 Author `references/feature-workflow.template/agents/sdd-expert-agent.md.template` with the same four-layer structure
- [x] 1.10 Author `references/block-catalog.md` documenting each v1 capability flag: name, when it resolves true, what blocks reference it
- [x] 1.11 Author `references/substitution-catalog.md` documenting every `{{VAR}}` token: source field in analysis report, fallback behavior when missing, example resolved value
- [x] 1.12 Author `references/jira-config-prompts.md` with: prompt text per `config.json` field, default values, sibling-repo inheritance UI text, "stub with TODO" escape wording, MCP-missing warning text for both Jira and ADO

## 2. Workflow signals in claudboard-analyse

- [x] 2.1 Update `skills/claudboard-analyse/SKILL.md` to include a new "Workflow Signals" subsection in the report output schema
- [x] 2.2 Document the workflow-signals subsection format in `skills/claudboard/references/quality-signals.md` (or a new `workflow-signals.md` reference if cleaner)
- [x] 2.3 Add detection guidance for cross-service edges: HTTP client (RestTemplate, WebClient, RestClient, axios, fetch, requests), Feign (`@FeignClient`), Kafka producers (`KafkaTemplate`, `@SendTo`), gRPC clients
- [x] 2.4 Add detection guidance for shared libraries: Maven artifacts referenced from 2+ service `pom.xml` files; npm workspace packages referenced from 2+ `package.json` dependency lists
- [x] 2.5 Add detection guidance for auth perimeter classification: `gateway` (Spring Cloud Gateway, Kong, Traefik, gateway-named service), `in-service-jwt` (JWT decoder beans, OAuth2 resource server config, FastAPI OAuth2PasswordBearer), `none`, `unknown`
- [x] 2.6 Add detection guidance for ticket prefix heuristic: scan last 50 commits + last 20 branch names, extract consistent `[A-Z]+-[0-9]+` prefix
- [x] 2.7 Confirm backward compatibility: existing reports without the subsection still parse cleanly in `claudboard-generate`, `claudboard-refresh`, `claudboard-techdebt`

## 3. claudboard-workflow SKILL.md orchestrator

- [x] 3.1 Write the orchestrator phases in `skills/claudboard-workflow/SKILL.md`: pre-flight (prereq check + analysis report check + MCP detection), config gathering, template rendering, confirmation gate, file writes, completion report
- [x] 3.2 Implement prereq check: refuse if `CLAUDE.md` missing OR `.claude/rules/` empty, with the exact error message from the spec
- [x] 3.3 Implement analysis report check: refuse if missing, warn if older than 7 days, warn if "Workflow Signals" subsection missing
- [x] 3.4 Implement MCP availability detection by inspecting MCP configuration (project-level then user-level); set `JIRA_AVAILABLE` / `ADO_AVAILABLE` accordingly
- [x] 3.5 Implement capability-flag resolution from the workflow-signals subsection plus runtime checks (`MEMORIES_PRESENT` from filesystem, persistence flags from stack detection)
- [x] 3.6 Implement substitution resolution: pull every `{{VAR}}` value from analysis report or runtime context; fall back to `[TODO: VAR]` literal with warning when unresolvable
- [x] 3.7 Implement `{{STACK_REMINDERS}}` lift from the analysis report's "Patterns detected" section
- [x] 3.8 Implement Azure DevOps remote auto-detection from `git remote -v` (both `dev.azure.com/{org}/{project}/_git/{repo}` and `{org}.visualstudio.com/{project}/_git/{repo}` patterns)
- [x] 3.9 Implement sibling-repo inheritance scan: look for `.claude/skills/feature-workflow/config.json` in sibling directories of the parent dir; offer to inherit shared fields excluding `repositoryId`
- [x] 3.10 Implement user prompts for unresolved `config.json` fields, each with "stub with TODO" escape
- [x] 3.11 Implement template rendering: read each `.template` file, evaluate `<!-- IF FLAG -->...<!-- ENDIF -->` blocks, substitute `{{VAR}}` tokens, write rendered output to target path; warn on unknown flags
- [x] 3.12 Implement existing-skill guard: refuse if `.claude/skills/feature-workflow/` already exists; print upgrade-not-available message
- [x] 3.13 Implement path-violation guard: any write outside `<project>/.claude/skills/feature-workflow/` SHALL fail
- [x] 3.14 Implement confirmation-gate UX: print summary of files to write + enabled/disabled blocks + resolved config; pause for `y/n/edit`; loop on `edit`
- [x] 3.15 Implement completion report: list files written, group capability blocks into enabled/disabled, list any TODO-stubbed config fields, include MCP-missing warnings, end with "next steps: try /start-feature on a small ticket to validate the wiring"

## 4. Refresh exclusion

- [x] 4.1 Update `skills/claudboard-refresh/SKILL.md` to explicitly skip `.claude/skills/feature-workflow/` directories
- [x] 4.2 Update the refresh report wording to note: "Skipped feature-workflow/ — upgrade path is opt-in via future /claudboard-workflow --upgrade"

## 5. Dispatcher and plugin manifest

- [x] 5.1 Update `skills/claudboard/SKILL.md` to list `claudboard-workflow` in the routing table with its trigger phrases (`/claudboard-workflow`, "set up feature workflow", "install start-feature skill", "generate feature-workflow")
- [x] 5.2 Update `plugin/.claude-plugin/plugin.json` to include `claudboard-workflow` in the skill list
- [x] 5.3 Mention `/claudboard-workflow` in `claudboard-generate`'s completion report under "Next steps" only when the analysis report indicates Jira+ADO MCPs are configured

## 6. Validation and golden file

- [x] 6.1 Render the templates against the existing craftsphere analysis output (or a synthesized report mirroring craftsphere's signals) and diff the rendered files against the hand-edited copies under `craftsphere.cloud/.claude/skills/feature-workflow/`. Significant divergence flags template debt — adjust templates until diff is acceptable
- [x] 6.2 Render the templates against the existing meas.cloud.datahandler signals and diff against that repo's hand-edited copy. Same acceptance criterion
- [x] 6.3 Render the templates against a synthetic "stranger project" analysis (e.g., a vanilla FastAPI service with no workspace, no shared libs, no Jira/ADO) and confirm output is coherent and useful
- [x] 6.4 Save one rendered output set as a checked-in golden file under `tests/golden/feature-workflow-craftsphere/` (or equivalent) so future template changes can be reviewed via diff
- [x] 6.5 Manually run `/claudboard-workflow` end-to-end on a clean copy of the meas.cloud.datahandler repo (after running /analyse and /generate first) and verify the generated skill compiles cleanly with the existing `start-feature` flow

## 7. Documentation

- [x] 7.1 Update root `CLAUDE.md` to mention `claudboard-workflow` in the skill anatomy section
- [x] 7.2 Add a brief "Generated feature-workflow" section to root `CLAUDE.md` explaining the relationship between `/claudboard-workflow` and the existing hand-edited copies, plus the upgrade-path caveat
- [x] 7.3 Confirm the `claudboard-workflow` SKILL.md description field is "pushy" enough to auto-trigger on the documented natural-language phrases (use the same description-tuning checklist applied to the other claudboard sibling skills)
