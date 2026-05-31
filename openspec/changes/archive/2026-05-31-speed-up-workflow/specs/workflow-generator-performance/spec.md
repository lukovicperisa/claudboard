## ADDED Requirements

### Requirement: Detection script consolidates Phase 1d, 2a, and 2b into one tool call

The `claudboard-workflow` skill SHALL provide an executable `scripts/detect.sh` that runs MCP detection (Phase 1d), git remote parsing (Phase 2a), and sibling-repo `config.json` scan (Phase 2b) for a target project path in a single bash invocation. The script SHALL emit a single JSON document to stdout containing all detection results. The workflow SKILL.md SHALL invoke `scripts/detect.sh <project-path>` as its primary detection step and consume the JSON output, replacing the prose-driven sequence of individual file reads and regex applications for those phases.

#### Scenario: Single-repo run uses the detection script

- **WHEN** `/claudboard-workflow` runs on a single repo
- **THEN** the model invokes `bash scripts/detect.sh <project-path>` exactly once
- **AND** the model does NOT issue separate `Read` or `Bash` tool calls for the patterns covered by the script (Phase 1d MCP config files, Phase 2a `git remote -v`, Phase 2b sibling enumeration)
- **AND** the detection JSON appears in the conversation as a single tool result

#### Scenario: Workspace mode run uses the detection script

- **WHEN** `/claudboard-workflow` runs in workspace mode
- **THEN** the model invokes `scripts/detect.sh` once scoped to the project path resolved by the existing-skill guard (Phase 1c)
- **AND** the JSON includes the workspace-level `.mcp.json` results when present, with `source: "project"` recording the workspace-root path

### Requirement: Detection script output has a versioned schema

The `scripts/detect.sh` JSON output SHALL include a top-level `schema_version` field whose value is a string identifying the contract version. The workflow SKILL.md SHALL assert on the `schema_version` and stop with an actionable error message if the version does not match the version the SKILL.md was authored against.

#### Scenario: Schema version matches

- **WHEN** the detection JSON contains `schema_version` matching the SKILL.md's expected version
- **THEN** the model proceeds with the run

#### Scenario: Schema version mismatch

- **WHEN** the detection JSON contains a `schema_version` the SKILL.md does not recognise
- **THEN** the model stops the run and reports an error naming both the observed and expected versions and the path to `scripts/detect.sh`
- **AND** the model does NOT proceed to Phase 2c prompts, Phase 3 render, or any filesystem writes

### Requirement: Detection script exposes resolved MCP detection and ambiguities

The `scripts/detect.sh` JSON output SHALL include an `mcp` object containing boolean fields `tracker_jira`, `tracker_tr`, `repo_ado`, `repo_github`, plus a `sources` map naming the config path and match style (`name` vs `args`) for each detected backend, plus an `ambiguities` array populated when both backends in a dimension matched and require user resolution. Project-level matches SHALL take precedence over user-level matches within the same dimension; the precedence resolution SHALL be applied inside the script, not in the SKILL.md.

#### Scenario: One tracker, one repo, all clean

- **WHEN** the project's `.mcp.json` declares the Bosch T&R MCP and the Azure DevOps MCP, and no user-level MCPs are configured
- **THEN** `mcp.tracker_tr` is true, `mcp.tracker_jira` is false, `mcp.repo_ado` is true, `mcp.repo_github` is false
- **AND** `mcp.ambiguities` is an empty array

#### Scenario: Both tracker backends detected — script populates ambiguity

- **WHEN** the project's `.mcp.json` declares Atlassian Jira AND the user-level config declares Bosch T&R
- **THEN** `mcp.ambiguities` contains one entry naming `tracker` as the dimension and both source paths
- **AND** the workflow SKILL.md surfaces the dimension-resolution prompt only when `mcp.ambiguities` is non-empty

#### Scenario: Project-level precedence applied inside the script

- **WHEN** the project's `.mcp.json` declares the Bosch T&R MCP and the user-level config declares the Atlassian Jira MCP
- **THEN** the script outputs `mcp.tracker_tr: true`, `mcp.tracker_jira: false`, `mcp.ambiguities: []`
- **AND** the user-level Atlassian Jira entry is recorded in a `suppressed` array for diagnostic purposes (but not in `sources`)

### Requirement: Detection script exposes git remote and sibling-config state

The `scripts/detect.sh` JSON output SHALL include a `git_remote` object capturing the provider (`azure-devops`, `github`, or `null`) and the parsed URL segments (org/project/repo for Azure DevOps; owner/repo for GitHub), and a `siblings` array enumerating sibling repos under `../*/` that contain `.claude/skills/feature-workflow/config.json`. Each sibling entry SHALL include the path and an inheritable-field summary extracted from the sibling's `config.json`.

#### Scenario: Azure DevOps modern URL parses correctly

- **WHEN** `git remote -v` returns `https://dev.azure.com/bosch-meas/platform/_git/datahandler`
- **THEN** `git_remote.provider` is `azure-devops`
- **AND** `git_remote.azure_devops.org` is `bosch-meas`, `project` is `platform`, `repo` is `datahandler`
- **AND** `git_remote.github` is `null`

#### Scenario: GitHub SSH URL parses correctly

- **WHEN** `git remote -v` returns `git@github.com:acme/widget.git`
- **THEN** `git_remote.provider` is `github`
- **AND** `git_remote.github.owner` is `acme`, `repo` is `widget`
- **AND** `git_remote.azure_devops` is `null`

#### Scenario: Sibling enumeration finds peers

- **WHEN** the project's parent directory contains `order-service/` and `billing-service/`, each with `.claude/skills/feature-workflow/config.json`
- **THEN** `siblings` contains two entries, one per sibling, each with the relative path and a summary of inheritable fields (`jira.projectKey`, `jira.urlBase`, etc.)

### Requirement: Detection script reports unresolved config fields

The `scripts/detect.sh` JSON output SHALL include an `unresolved` object with `tracker` and `repo` string arrays listing config fields that detection could not satisfy (auto-detect from MCP / git remote / sibling scan). The workflow SKILL.md SHALL use these arrays to decide whether to prompt the user in Phase 2c and which prompt-reference files to load.

#### Scenario: Fully resolved single-tracker repo reports no unresolved fields

- **WHEN** a project has Bosch T&R MCP configured and `git remote -v` returns a recognised Azure DevOps URL, and no Jira fields apply because `tracker_jira` is false
- **THEN** `unresolved.tracker` includes the T&R-required fields not derivable from the MCP config alone (e.g., `tr.baseUrl` if not present elsewhere)
- **AND** `unresolved.repo` includes `azureDevOps.repositoryId` because the UUID cannot be auto-detected

#### Scenario: Sibling inheritance closes unresolved fields

- **WHEN** the script detects a sibling whose `config.json` contains a `jira.urlBase` value and the current project has Atlassian Jira MCP
- **THEN** `unresolved.tracker` does NOT include `jira.urlBase` (the script records it as inheritable; the SKILL.md still asks the user before applying)

### Requirement: Conditional reference loading gated by detection signals

The workflow SKILL.md SHALL load the following references conditionally based on the detection JSON, rather than unconditionally on every run:

- `references/tracker-config-prompts.md` — load only when (`mcp.tracker_jira || mcp.tracker_tr`) AND `unresolved.tracker` is non-empty
- `references/repo-config-prompts.md` — load only when (`mcp.repo_ado || mcp.repo_github`) AND `unresolved.repo` is non-empty
- `references/sibling-inheritance.md` — load only when `siblings` is non-empty
- `references/block-catalog.md` — load only at the start of Phase 3 (render time), never during Phase 1 or Phase 2
- `references/substitution-catalog.md` — load only at the start of Phase 3 (render time), never during Phase 1 or Phase 2

#### Scenario: Fully resolved single-tracker repo skips both prompt-reference files

- **WHEN** detection resolves one tracker and one repo backend AND all config fields are derivable from MCP, git remote, or sibling sources
- **THEN** the model does NOT load `references/tracker-config-prompts.md`
- **AND** the model does NOT load `references/repo-config-prompts.md`

#### Scenario: Catalogs load at Phase 3 only

- **WHEN** the run reaches Phase 3 (template render)
- **THEN** the model loads `references/block-catalog.md` and `references/substitution-catalog.md`
- **AND** the model did NOT load either file during Phase 1 or Phase 2

### Requirement: Workflow SKILL.md size budget

The `skills/claudboard-workflow/SKILL.md` file SHALL be ≤ 6,000 tokens (approximately ≤ 550 lines) measured at the time of merge. The size reduction SHALL come from relocating data (MCP keyword tables, git remote regex tables, sibling-inheritance field allowlist) into `scripts/detect.sh` and a new small `references/sibling-inheritance.md`, NOT from removing user-visible behavior, prompts, or guards.

#### Scenario: Post-change SKILL.md size

- **WHEN** the change is ready for merge
- **THEN** `wc -l skills/claudboard-workflow/SKILL.md` reports ≤ 550 lines
- **AND** the Phase 1c existing-skill guard, Phase 2c prompt structure, Phase 3 render orchestration, and Phase 7 completion report SHALL be functionally unchanged from the pre-change version

### Requirement: Detection script preserves generated-artifact output

Given identical inputs (analysis report, MCP config, git remote, sibling configs, and Phase 2c user answers), the post-change `/claudboard-workflow` run SHALL produce a generated `feature-workflow/` directory whose file contents are byte-identical to the pre-change run's output.

#### Scenario: Output diff is empty

- **WHEN** `/claudboard-workflow` runs against the same fixture before and after this change with the same Phase 2c user answers
- **THEN** `diff -r` between the two generated `feature-workflow/` trees reports no differences

### Requirement: Fallback path when detection script is unavailable

The workflow SKILL.md SHALL retain the prose-driven Phase 1d, 2a, and 2b paths under a clearly labeled "Fallback: detect.sh unavailable" subsection. When `scripts/detect.sh` is missing or not executable, the model SHALL use the fallback path and still produce a working `feature-workflow/`.

#### Scenario: Fallback path produces a working skill

- **WHEN** `scripts/detect.sh` is removed or has its execute bit cleared, and `/claudboard-workflow` runs
- **THEN** the model detects the unavailability, switches to the fallback path, and completes the generation
- **AND** the generated `feature-workflow/` is functionally equivalent to a script-path run with the same inputs
