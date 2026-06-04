# Tracker Config Prompts — claudboard-workflow

> **Documentation only — no longer loaded at runtime.**
> Since the `claudboard-workflow-non-interactive` change (2026-06-04), the
> orchestrator silently stubs missing fields with `[TODO: …]` instead of
> prompting. This file remains as a reference for users editing `config.json`
> by hand.
>
> After a `/claudboard-workflow` run, the completion report's **"Unfilled config
> values"** section is the canonical channel for discovering which fields need
> to be filled.

Field documentation, default values, inheritance offer wording, and stub-escape
text for every `config.json` tracker field. Use this file as a reference when
editing `config.json` by hand after generation.

---

## Jira (TRACKER_JIRA)

### Environment-Variable Requirements (Jira)

The `/start-feature` skill requires two environment variables to be set at
runtime whenever it writes Jira labels. These are NOT stored in `config.json`
or anywhere in the project tree — each developer manages their own credentials
independently.

| Variable | Description |
|---|---|
| `JIRA_EMAIL` | Your Atlassian account email (e.g., `dev@example.com`) |
| `JIRA_API_TOKEN` | Your Jira API token (NOT your Atlassian password) |

**How to generate a Jira API token:**
Go to [https://id.atlassian.com/manage-profile/security/api-tokens](https://id.atlassian.com/manage-profile/security/api-tokens),
click "Create API token", give it a label, and copy the token value.

**How to export for an interactive shell:**
```bash
export JIRA_EMAIL=dev@example.com
export JIRA_API_TOKEN=your_token_here
```

Add these to your shell profile (`~/.zshrc`, `~/.bashrc`) to persist across
sessions. Never commit them to any file inside the project tree.

---

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
> Type 's' to stub with [TODO: JIRA_CLOUD_ID] and continue.

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
> Type 's' to stub with [TODO: JIRA_PROJECT_KEY] and continue.

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
> Type 's' to stub with [TODO: JIRA_SPRINT_FIELD] and continue.

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
> Type 's' to stub with [TODO: JIRA_AC_FIELD] and continue.

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
> Type 's' to stub with [TODO: JIRA_TRANSITION_START] and continue.

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
> Type 's' to stub with [TODO: JIRA_TRANSITION_SUCCESS] and continue.

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
> Type 's' to stub with [TODO: JIRA_TRANSITION_FAILURE] and continue.

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

---

### jira.labels — area labels

**Top-level y/n prompt:**
```
Does this project use area labels on Jira tickets?
Area labels identify the work area (backend, frontend, DevOps, docs) on each ticket.
Answer "n" to skip area labels entirely (jira.labels.area will be set to null).

Use area labels? [y/n, default: y]: [enter y or n]
```

**Per-area prompts (shown only when answer is "y"):**

```
Area label for backend work [default: BE, blank to skip]:
Area label for frontend work [default: FE, blank to skip]:
Area label for devops work [default: DevOps, blank to skip]:
Area label for docs work [default: Docs, blank to skip]:
```

**Label when shown in inheritance offer:** `Jira area labels`

---

### MCP-Missing Warning for Jira

Show this warning in the Phase 7 completion report when no tracker MCP is
detected (TRACKER_JIRA = false and TRACKER_TR = false):

```
⚠ No tracker MCP detected — ticket integration phases are absent from the
  generated skill. To enable Atlassian Jira integration:
    1. Install the Atlassian MCP server:
       npx @anthropic-ai/create-mcp-server @atlassian/atlassian-mcp
    2. Add it to your project .mcp.json or user-level MCP config.
    3. Remove .claude/skills/feature-workflow/ and re-run /claudboard-workflow.
```

---

### Sibling Inheritance UI (Jira)

When one or more sibling repositories have a valid
`.claude/skills/feature-workflow/config.json` with `tracker: "jira"`:

```
Found feature-workflow Jira config in sibling repo(s):

  • ../order-service/
      Jira project:  PLAT
      Jira URL:      https://mycompany.atlassian.net
      Sprint field:  customfield_10001
      AC field:      customfield_12206

Inherit shared values from this sibling? [y/n]
```

Fields that CAN be inherited from siblings:
- `jira.cloudId`
- `jira.projectKey`
- `jira.urlBase`
- `jira.customFields.sprint`
- `jira.customFields.acceptanceCriteria`

Fields that MUST NOT be inherited (always per-repo):
- None specific to Jira (all Jira fields are shareable)

---

## Bosch Track & Release (TRACKER_TR)

### Authentication (T&R)

The T&R MCP (`bosch-jira-mcp`) handles authentication itself by reading a
bearer token from `~/.config/bosch-jira-mcp/config.json`. No environment
variables are needed in the skill. Do NOT store credentials in `config.json`.

---

### tr.baseUrl

**Prompt text:**
```
What is your Bosch Track & Release base URL?
This is the root URL of your T&R instance, without a trailing slash
(e.g., https://track.example.bosch.com).

T&R base URL: [enter value or 's' to stub]
```

**Default value:** none

**Label when shown in inheritance offer:** `T&R base URL`

**Stub-with-TODO escape:**
> Type 's' to stub with [TODO: TR_BASE_URL] and continue.

---

### tr.projectKey

**Prompt text:**
```
What is your Bosch T&R project key?
This is the uppercase prefix used in ticket IDs (e.g., MEAS, PLAT, IOT).
Look at any ticket in your project — it's the part before the dash (MEAS-123 → MEAS).

T&R project key: [enter value or 's' to stub]
```

**Default value:** none

**Label when shown in inheritance offer:** `T&R project key`

**Stub-with-TODO escape:**
> Type 's' to stub with [TODO: TR_PROJECT_KEY] and continue.

---

### tr.transitions.start

**Prompt text:**
```
What T&R status name does "start work" transition to?
This is the column tickets move to when your team begins active development
(e.g., "In Progress", "Doing").

T&R start transition [default: In Progress]: [enter value, press Enter to accept default]
```

**Default value:** `In Progress`

---

### tr.transitions.success

**Prompt text:**
```
What T&R status name does "work complete, ready for review" transition to?
(e.g., "In Review", "Code Review")

T&R success transition [default: In Review]: [enter value, press Enter to accept default]
```

**Default value:** `In Review`

---

### tr.transitions.failure

**Prompt text:**
```
What T&R status name should a ticket transition to when the workflow fails
non-recoverably? Enter a status name or press Enter to skip.

T&R failure transition [default: Blocked, or Enter to skip]: [enter value or press Enter]
```

**Default value:** `Blocked`

---

### tr.transitions.pause

**Default value:** `null` (reserved for future use — press Enter to accept null)

---

### MCP-Missing Warning for T&R

The generator does not separately warn about T&R absence — it uses the single
"no tracker MCP detected" warning above. The detection keyword for T&R is
`bosch-jira-mcp` in server name/key or command/args.

---

### T&R v1 Limitations Reminder (completion report)

When `TRACKER_TR` is the active tracker, append to the completion report:

```
⚠ T&R v1 limitations (bosch-jira-mcp v1.0.0):
  • No auto-create ticket — use /start-feature TR-XXXXX with an existing key.
  • No sprint assignment — bosch-jira-mcp cannot write custom fields.
  • No worklog — time data is folded into the Phase 7 final summary comment.
  • AC inlined in description body — not in a separate custom field.
  • Labels via read-modify-write — non-atomic; low race risk for single-user use.
  Each limitation lifts when the underlying MCP gains the corresponding tool.
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
- `tr.baseUrl` → `TR_BASE_URL`
- `tr.projectKey` → `TR_PROJECT_KEY`
- `tr.transitions.start` → `TR_TRANSITION_START`
- `tr.transitions.success` → `TR_TRANSITION_SUCCESS`
- `tr.transitions.failure` → `TR_TRANSITION_FAILURE`

Fields with usable defaults should accept Enter as "use default" rather than
offering a stub — the default value is always valid.
