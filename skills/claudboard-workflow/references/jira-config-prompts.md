# Jira Config Prompts — claudboard-workflow

Exact prompt text, default values, inheritance offer wording, and stub-escape
text for every `config.json` field that requires user input. Use this reference
during Phase 2 (Config Gathering) of the orchestrator.

---

## Prompt Texts per config.json Field

### jira.cloudId

**Prompt text:**
```
What is your Atlassian Cloud ID?
This is the UUID that identifies your Atlassian site
(e.g., a1b2c3d4-e5f6-7890-abcd-ef1234567890).
Find it at: https://admin.atlassian.com → select your site → the UUID is in the URL.

Atlassian Cloud ID: [enter value or 's' to stub]
```

**Default value:** none

**Label when shown in inheritance offer:** `Atlassian Cloud ID`

**Stub-with-TODO escape:**
> Type 's' to stub with [TODO: JIRA_CLOUD_ID] and continue. You will need to
> fill this in before running `/start-feature` for the first time.

---

### jira.projectKey

**Prompt text:**
```
What is your Jira project key?
This is the uppercase prefix used in ticket IDs (e.g., PLAT, MEAS, ORDER).
Look at any ticket in your project — it's the part before the dash (PLAT-123 → PLAT).

Jira project key: [enter value or 's' to stub]
```

**Default value:** none

**Label when shown in inheritance offer:** `Jira project key`

**Stub-with-TODO escape:**
> Type 's' to stub with [TODO: JIRA_PROJECT_KEY] and continue. Branch names
> and commit messages that reference ticket IDs will not auto-populate until
> this is set.

---

### jira.urlBase

**Prompt text:**
```
What is your Jira base URL?
This is the root URL of your Atlassian site, without a trailing slash
(e.g., https://mycompany.atlassian.net).

Jira base URL: [enter value or 's' to stub]
```

**Default value:** none

**Label when shown in inheritance offer:** `Jira base URL`

**Stub-with-TODO escape:**
> Type 's' to stub with [TODO: JIRA_URL_BASE] and continue.

---

### jira.customFields.sprint

**Prompt text:**
```
What is the Jira custom field ID for the Sprint field?
This is used to assign tickets to the current sprint when creating a feature
branch. The default is customfield_10001, which is correct for most Jira Cloud
instances. To confirm yours: open a ticket → View in full page → right-click the
Sprint field → Inspect Element → look for the field ID attribute.

Sprint field ID [default: customfield_10001]: [enter value, press Enter to accept
default, or 's' to stub]
```

**Default value:** `customfield_10001`

**Label when shown in inheritance offer:** `Sprint custom field ID`

**Stub-with-TODO escape:**
> Type 's' to stub with [TODO: JIRA_SPRINT_FIELD] and continue. The sprint
> assignment step in /start-feature will not work until this is set correctly.

---

### jira.customFields.acceptanceCriteria

**Prompt text:**
```
What is the Jira custom field ID for Acceptance Criteria?
This is used to fetch the AC from a ticket so the spec-reviewer agent can check
completeness. The default is customfield_12206, but it varies by Jira instance.
To confirm yours: open a ticket that has AC → View in full page → right-click
the Acceptance Criteria field → Inspect Element → look for the field ID.

Acceptance Criteria field ID [default: customfield_12206]: [enter value, press
Enter to accept default, or 's' to stub]
```

**Default value:** `customfield_12206`

**Label when shown in inheritance offer:** `Acceptance Criteria custom field ID`

**Stub-with-TODO escape:**
> Type 's' to stub with [TODO: JIRA_AC_FIELD] and continue. The spec-reviewer
> agent will not be able to check AC completeness until this is set correctly.

---

### jira.transitions.start

**Prompt text:**
```
What Jira status name does "start work" transition to?
This is the column tickets move to when your team begins active development
(e.g., "In Progress", "Doing", "In Development").

Start transition [default: In Progress]: [enter value, press Enter to accept default, or 's' to stub]
```

**Default value:** `In Progress`

**Label when shown in inheritance offer:** `Jira start transition`

**Stub-with-TODO escape:**
> Type 's' to stub with [TODO: JIRA_TRANSITION_START] and continue. The
> `/start-feature` command will not transition tickets until this is set.

---

### jira.transitions.success

**Prompt text:**
```
What Jira status name does "work complete, ready for review" transition to?
This is the column tickets move to when a PR is opened
(e.g., "In Review", "Code Review", "Review").

Success transition [default: In Review]: [enter value, press Enter to accept default, or 's' to stub]
```

**Default value:** `In Review`

**Label when shown in inheritance offer:** `Jira success transition`

**Stub-with-TODO escape:**
> Type 's' to stub with [TODO: JIRA_TRANSITION_SUCCESS] and continue. The
> PR finalization step will not transition tickets until this is set.

---

### jira.transitions.failure

**Prompt text:**
```
What Jira status name should a ticket transition to when the workflow fails
non-recoverably (e.g., MCP unavailable, transition lookup miss)?
Enter a status name (e.g., "Blocked") or press Enter to skip (no failure transition).

Failure transition [default: Blocked, or Enter to skip]: [enter value, press Enter to accept default, or 's' to stub]
```

**Default value:** `Blocked`

**Label when shown in inheritance offer:** `Jira failure transition`

**Stub-with-TODO escape:**
> Type 's' to stub with [TODO: JIRA_TRANSITION_FAILURE] and continue. Tickets
> will not be marked on non-recoverable workflow failure until this is set.

---

### jira.transitions.pause

**Prompt text:**
```
[RESERVED FOR FUTURE USE — no v1 command fires this transition]
A future "pause workflow" command will use this field. Accept the default
for now to leave a placeholder for future use, or press Enter to set null.

Pause transition [default: null — skip]: [press Enter to accept null]
```

**Default value:** `null`

**Label when shown in inheritance offer:** `Jira pause transition (reserved)`

**Stub-with-TODO escape:**
> Type 's' to stub with [TODO: JIRA_TRANSITION_PAUSE] and continue. This
> field is reserved for future use — no v1 command fires it.

---

### jira.labels — area labels

**Top-level y/n prompt:**
```
Does this project use area labels on Jira tickets?
Area labels identify the work area (backend, frontend, DevOps, docs) on each ticket.
Answer "n" to skip area labels entirely (jira.labels.area will be set to null).

Use area labels? [y/n, default: y]: [enter y or n]
```

**Short-circuit on "n":** Set `jira.labels.area = null` and skip per-area prompts entirely.

**Per-area prompts (shown only when answer is "y"):**

```
Area label for backend work [default: BE, blank to skip]:
Area label for frontend work [default: FE, blank to skip]:
Area label for devops work [default: DevOps, blank to skip]:
Area label for docs work [default: Docs, blank to skip]:
```

Blank input (Enter with no value) maps to `null` for that area (no label applied for that work type).
Default values (Craftsphere-style): `backend: "BE"`, `frontend: "FE"`, `devops: "DevOps"`, `docs: "Docs"`.

**Label when shown in inheritance offer:** `Jira area labels`

**Stub-with-TODO escape (per area):**
> Type 's' to stub with [TODO: JIRA_LABELS_AREA_BACKEND] and continue.

---

### azureDevOps.repositoryId

**Prompt text:**
```
What is the Azure DevOps repository ID (UUID) for this repo?
This is always per-repository and cannot be inherited from a sibling repo.
Find it with:
  az repos show --repository <repo-name> --org https://dev.azure.com/<org> \
    --project <project> --query id -o tsv
Or in the Azure DevOps UI: Repos → [repo name] → Clone → HTTPS URL contains
the repository ID as a query parameter (?version=...) — or use the REST API:
  GET https://dev.azure.com/{org}/{project}/_apis/git/repositories

ADO Repository ID (UUID): [enter value or 's' to stub]
```

**Default value:** none (always per-repo, never has a generic default)

**Label when shown in inheritance offer:** `Azure DevOps Repository ID`
*(Note: this field must NOT be inherited — always prompt per repo even if
other ADO fields were inherited.)*

**Stub-with-TODO escape:**
> Type 's' to stub with [TODO: ADO_REPOSITORY_ID] and continue. The PR
> creation step in /start-feature will not work until this is set.

---

### git.branchTypes

**Prompt text:**
```
What branch type prefixes does your team use?
Enter as a comma-separated list (e.g., feature,bugfix,hotfix).

Branch types [default: feature,bugfix,hotfix]: [enter value or press Enter to accept default]
```

**Default value:** `["feature","bugfix","hotfix"]`

**Label when shown in inheritance offer:** `Git branch types`

**Stub-with-TODO escape:** Not applicable — the default is always valid. If the
user types 's', accept the default instead.

---

### git.branchPattern

**Prompt text (when JIRA_AVAILABLE = true):**
```
What branch naming pattern does your team use?
Tokens: {type} (branch type), {ticket} (Jira ticket ID), {slug} (description).
Example patterns:
  {type}/{ticket}/{slug}   → feature/PLAT-123/add-payment-endpoint
  {ticket}/{type}/{slug}   → PLAT-123/feature/add-payment-endpoint

Branch pattern [default: {type}/{ticket}/{slug}]: [enter value or press Enter]
```

**Prompt text (when JIRA_AVAILABLE = false):**
```
What branch naming pattern does your team use?
Tokens: {type} (branch type), {slug} (description).
Example patterns:
  {type}/{slug}   → feature/add-payment-endpoint

Branch pattern [default: {type}/{slug}]: [enter value or press Enter]
```

**Default value:** `{type}/{ticket}/{slug}` if JIRA_AVAILABLE, else `{type}/{slug}`

**Label when shown in inheritance offer:** `Git branch pattern`

**Stub-with-TODO escape:** Not applicable — the default is always valid.

---

### git.ticketRegex

**Prompt text:**
```
What regex pattern matches your ticket IDs?
This is used to extract ticket IDs from branch names and commit messages.

Ticket regex [default: [A-Z]+-[0-9]+]: [enter value or press Enter to accept default]
```

**Default value:** `[A-Z]+-[0-9]+`

**Label when shown in inheritance offer:** `Ticket ID regex`

**Stub-with-TODO escape:** Not applicable — the default matches standard Jira
ticket format. If the user types 's', accept the default.

---

## Sibling Inheritance UI

When one or more sibling repositories have a valid
`.claude/skills/feature-workflow/config.json`, show this offer:

```
Found feature-workflow config in sibling repo(s):

  • ../order-service/
      Jira project:  PLAT
      Jira URL:      https://mycompany.atlassian.net
      Sprint field:  customfield_10001
      AC field:      customfield_12206
      ADO org:       my-org
      ADO project:   MyProject

Inherit shared values from this sibling? [y/n]
```

If multiple siblings are found:

```
Found feature-workflow config in multiple sibling repos:

  1. ../order-service/  (project: PLAT, url: https://mycompany.atlassian.net)
  2. ../user-service/   (project: MEAS, url: https://mycompany.atlassian.net)

Inherit from which sibling? [1/2/n — n to prompt for all values manually]
```

After the user selects a sibling:

```
Inheriting from ../order-service/:
  ✓ jira.cloudId              → a1b2c3d4-e5f6-7890-abcd-ef1234567890
  ✓ jira.projectKey           → PLAT
  ✓ jira.urlBase              → https://mycompany.atlassian.net
  ✓ jira.customFields.sprint  → customfield_10001
  ✓ jira.customFields.acceptanceCriteria → customfield_12206
  ✓ azureDevOps.org           → my-org
  ✓ azureDevOps.project       → MyProject

Not inherited (always per-repo):
  → azureDevOps.repositoryId  [will prompt next]
```

Always display which fields were inherited and which were not, before prompting
for the remaining fields.

---

## MCP-Missing Warning for Jira

Show this warning in the Phase 7 completion report when `JIRA_AVAILABLE = false`:

```
⚠ JIRA_AVAILABLE = false — Atlassian MCP server not detected in your MCP
  configuration. Jira-specific phases in the generated skill are stubbed and
  jira-agent.md was not written. To enable:
    1. Install the Atlassian MCP server:
       npx @anthropic-ai/create-mcp-server @atlassian/atlassian-mcp
    2. Add it to your project .mcp.json or user-level MCP config.
    3. Remove .claude/skills/feature-workflow/ and re-run /claudboard-workflow.
```

Also show a shorter inline note in the confirmation gate (Phase 5) if Jira was
requested but MCP is absent:

```
⚠ Jira MCP not found — jira-agent.md will be skipped; Jira phases in SKILL.md
  will be removed.
```

---

## MCP-Missing Warning for Azure DevOps

Show this warning in the Phase 7 completion report when `ADO_AVAILABLE = false`:

```
⚠ ADO_AVAILABLE = false — Azure DevOps MCP server not detected in your MCP
  configuration. ADO-specific phases in the generated skill are stubbed. To
  enable:
    1. Install the Azure DevOps MCP server (e.g., azure-devops-mcp npm package).
    2. Add it to your project .mcp.json or user-level MCP config.
    3. Remove .claude/skills/feature-workflow/ and re-run /claudboard-workflow.
```

Also show a shorter inline note in the confirmation gate (Phase 5):

```
⚠ Azure DevOps MCP not found — ADO-specific phases in SKILL.md will be removed.
  PR creation will fall back to GitHub CLI (gh pr create) if available.
```

---

## "Stub with TODO" General Escape Text

Use this standardised phrasing consistently for every promptable field:

> Type 's' to stub with [TODO: FIELD_KEY] and continue.

Where `FIELD_KEY` is the dotted config.json path in SCREAMING_SNAKE_CASE:
- `jira.cloudId` → `JIRA_CLOUD_ID`
- `jira.projectKey` → `JIRA_PROJECT_KEY`
- `jira.urlBase` → `JIRA_URL_BASE`
- `jira.customFields.sprint` → `JIRA_SPRINT_FIELD`
- `jira.customFields.acceptanceCriteria` → `JIRA_AC_FIELD`
- `jira.transitions.start` → `JIRA_TRANSITION_START`
- `jira.transitions.success` → `JIRA_TRANSITION_SUCCESS`
- `jira.transitions.failure` → `JIRA_TRANSITION_FAILURE`
- `jira.transitions.pause` → `JIRA_TRANSITION_PAUSE`
- `jira.labels.area.backend` → `JIRA_LABELS_AREA_BACKEND`
- `jira.labels.area.frontend` → `JIRA_LABELS_AREA_FRONTEND`
- `jira.labels.area.devops` → `JIRA_LABELS_AREA_DEVOPS`
- `jira.labels.area.docs` → `JIRA_LABELS_AREA_DOCS`
- `azureDevOps.repositoryId` → `ADO_REPOSITORY_ID`

Fields with usable defaults (`git.branchTypes`, `git.branchPattern`,
`git.ticketRegex`, `jira.transitions.*`) should accept Enter as "use default"
rather than offering a stub — the default value is always valid.

For `jira.transitions.pause`: the default is `null`. Accept Enter without offering
a stub since null is the correct production value for v1.

Every stubbed field must be listed in the Phase 7 completion report with a
hint for where to find the correct value.
