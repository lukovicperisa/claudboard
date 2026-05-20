## ADDED Requirements

### Requirement: Four-MCP detection across two dimensions

The system SHALL scan the user's MCP configuration during the orchestrator's Phase 1d for four supported MCP servers across two independent dimensions:

- Tracker dimension: Atlassian Jira MCP, Bosch Track & Release MCP
- Repo dimension: Azure DevOps MCP, official GitHub MCP

Each dimension SHALL resolve to exactly one backend (one capability flag true) or zero (neither flag true). The two flags within a dimension SHALL be mutually exclusive in the generated output.

The detection SHALL inspect project-level `.mcp.json` first, then user-level (`~/.claude/mcp_servers.json` and `~/.claude.json`). Project-level entries SHALL take precedence over user-level entries.

#### Scenario: One tracker, one repo
- **WHEN** exactly one tracker MCP and exactly one repo MCP are detected
- **THEN** the corresponding flags SHALL be set true (e.g., `TRACKER_TR=true`, `REPO_GITHUB=true`) and the other flags in each dimension SHALL be false

#### Scenario: Project-level overrides user-level
- **WHEN** the project's `.mcp.json` declares the Bosch T&R MCP and the user-level config declares only the Atlassian MCP
- **THEN** `TRACKER_TR` SHALL be true and `TRACKER_JIRA` SHALL be false (project-level wins)

### Requirement: Detection keyword rules per backend

The system SHALL use the following keyword rules to detect each MCP backend. Detection is case-insensitive and SHALL inspect both server keys/names and command/args fields.

| Backend | Detection keywords |
|---------|--------------------|
| Atlassian Jira (`TRACKER_JIRA`) | server name contains `"atlassian"`, `"jira"`, or `"confluence"`; OR command/args reference `@atlassian/` |
| Bosch T&R (`TRACKER_TR`) | server name contains `"bosch-jira-mcp"` or `"bosch-jira"`; OR command/args reference the `bosch-jira-mcp` binary |
| Azure DevOps (`REPO_ADO`) | server name contains `"azure-devops"` or `"ado"`; OR command/args reference `azure-devops-mcp` or `@microsoft/azure` |
| GitHub (`REPO_GITHUB`) | server name contains `"github"`; OR command/args reference `github-mcp-server` or `@modelcontextprotocol/server-github` |

#### Scenario: Bosch T&R MCP detected
- **WHEN** `.mcp.json` contains an entry with key `"bosch-jira-mcp"` and command `npx bosch-jira-mcp`
- **THEN** `TRACKER_TR` SHALL be true (matched on both name and command)

#### Scenario: Atlassian MCP detected
- **WHEN** `.mcp.json` contains an entry with key `"atlassian"` and command `npx -y @atlassian/mcp-server-atlassian`
- **THEN** `TRACKER_JIRA` SHALL be true

#### Scenario: Generic name with no signal
- **WHEN** `.mcp.json` contains an entry with key `"tracker"` and command `npx some-custom-mcp` (no matching keyword in either field)
- **THEN** no tracker flag SHALL be set true based on that entry

#### Scenario: Ambiguous keyword in commands only
- **WHEN** an entry's server key is `"mcp-x"` but its command/args contain `"jira"` as part of a longer identifier (e.g., a binary path)
- **THEN** the entry SHALL be matched and the relevant flag set true; the system SHALL emit a warning in the completion report noting the indirect match so the user can verify

### Requirement: Precedence-prompt when two MCPs in a dimension are detected

When two MCPs in the same dimension are both detected, the system SHALL prompt the user with a single-select question naming both backends and SHALL set the chosen flag true and the other false. The system SHALL NOT enable both flags in the same dimension under any circumstances.

#### Scenario: Both tracker MCPs detected
- **WHEN** both an Atlassian MCP and a Bosch T&R MCP are detected
- **THEN** the system SHALL prompt: "Two tracker MCPs detected. Which should the generated workflow target? [1] Atlassian Jira [2] Bosch Track & Release" and SHALL set `TRACKER_JIRA=true` if the user picks 1, else `TRACKER_TR=true`

#### Scenario: Both repo MCPs detected
- **WHEN** both an Azure DevOps MCP and a GitHub MCP are detected
- **THEN** the system SHALL prompt: "Two repo MCPs detected. Which should the generated workflow target? [1] Azure DevOps [2] GitHub" and SHALL set `REPO_ADO=true` if the user picks 1, else `REPO_GITHUB=true`

#### Scenario: Both prompts independent
- **WHEN** both dimensions have two MCPs each
- **THEN** the system SHALL present the two prompts in sequence; the user's choice in one dimension SHALL NOT affect the prompt or default in the other

### Requirement: Dimension-stub when no MCP detected

When neither MCP in a dimension is detected, the system SHALL set both flags in that dimension to false and SHALL emit a warning naming the dimension. The generated workflow SHALL omit all phases that depend on that dimension's flags.

#### Scenario: No tracker MCP detected
- **WHEN** neither Atlassian nor Bosch T&R MCP is detected
- **THEN** `TRACKER_JIRA=false` and `TRACKER_TR=false` SHALL be set; the warning "No tracker MCP detected. Generated feature-workflow has no ticket integration. To enable: configure Atlassian Jira MCP or Bosch T&R MCP, then re-run /claudboard-workflow." SHALL be emitted; the generated `SKILL.md` SHALL omit Phase 1-pre, Phase 1d worklog, Phase 7a worklog, Phase 7b comment, and Phase 7 transition

#### Scenario: No repo MCP detected
- **WHEN** neither Azure DevOps nor GitHub MCP is detected
- **THEN** `REPO_ADO=false` and `REPO_GITHUB=false` SHALL be set; the warning "No repo MCP detected. Generated feature-workflow has no PR creation. To enable: configure Azure DevOps MCP or GitHub MCP, then re-run /claudboard-workflow." SHALL be emitted; the generated `SKILL.md` SHALL omit Phase 6 entirely

### Requirement: Detection result logged in completion report

The completion report SHALL include a "MCP detection" section listing: which MCPs were found in which config file (project vs user), which flags resolved true, and any prompts that were asked. This enables users to verify the detection was correct.

#### Scenario: Detection summary in completion report
- **WHEN** generation completes
- **THEN** the completion report SHALL contain a "MCP detection" section with a table showing each backend (TRACKER_JIRA, TRACKER_TR, REPO_ADO, REPO_GITHUB), the detection result (detected / not detected / chosen via prompt / overridden by project-level), and the source config path where the MCP entry was found
