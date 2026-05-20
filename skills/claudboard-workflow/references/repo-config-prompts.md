# Repo Config Prompts — claudboard-workflow

Exact prompt text, default values, inheritance offer wording, and stub-escape
text for every `config.json` repo field that requires user input. Use this
reference during Phase 2 (Config Gathering) of the orchestrator.

---

## Azure DevOps (REPO_ADO)

### azureDevOps.organization and azureDevOps.project

These values are often auto-detected in Phase 2a from the git remote URL.
If not auto-detected, prompt:

**Prompt text (organization):**
```
What is your Azure DevOps organization name?
This is the organization segment in your ADO URL:
  https://dev.azure.com/{organization}/...

ADO organization: [enter value or 's' to stub]
```

**Prompt text (project):**
```
What is your Azure DevOps project name?
This is the project segment in your ADO URL:
  https://dev.azure.com/{org}/{project}/...

ADO project: [enter value or 's' to stub]
```

**Stub-with-TODO escapes:**
> Type 's' to stub with [TODO: ADO_ORGANIZATION] and continue.
> Type 's' to stub with [TODO: ADO_PROJECT] and continue.

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
*(Note: this field MUST NOT be inherited — always prompt per repo even if
other ADO fields were inherited.)*

**Stub-with-TODO escape:**
> Type 's' to stub with [TODO: ADO_REPOSITORY_ID] and continue. The PR
> creation step in /start-feature will not work until this is set.

---

### MCP-Missing Warning for ADO

Show this in the Phase 7 completion report when no repo MCP is detected:

```
⚠ No repo MCP detected — PR creation phases are absent from the generated
  skill. To enable Azure DevOps integration:
    1. Install the Azure DevOps MCP server (e.g., azure-devops-mcp npm package).
    2. Add it to your project .mcp.json or user-level MCP config.
    3. Remove .claude/skills/feature-workflow/ and re-run /claudboard-workflow.
```

---

### Sibling Inheritance UI (ADO)

When one or more sibling repositories have a valid
`.claude/skills/feature-workflow/config.json` with `repo: "ado"`:

```
Found feature-workflow ADO config in sibling repo(s):

  • ../order-service/
      ADO org:       my-org
      ADO project:   MyProject

Inherit shared ADO values from this sibling? [y/n]
```

Fields that CAN be inherited:
- `azureDevOps.organization`
- `azureDevOps.project`

Fields that MUST NOT be inherited (always per-repo):
- `azureDevOps.repositoryId`

---

## GitHub (REPO_GITHUB)

### github.owner and github.repo

These values are auto-detected in Phase 2a from the git remote URL when
possible. If not auto-detected, prompt:

**Prompt text (owner):**
```
What is your GitHub organization or username (repo owner)?
This is the owner segment in your GitHub repository URL:
  https://github.com/{owner}/{repo}

GitHub owner: [enter value or 's' to stub]
```

**Prompt text (repo):**
```
What is your GitHub repository name?
This is the repository name segment in your GitHub repository URL:
  https://github.com/{owner}/{repo}

GitHub repo name: [enter value or 's' to stub]
```

**Default values:** Auto-detected from git remote (SSH or HTTPS URL).

**Stub-with-TODO escapes:**
> Type 's' to stub with [TODO: GITHUB_OWNER] and continue.
> Type 's' to stub with [TODO: GITHUB_REPO] and continue.

---

### github.linkingKeyword

**Prompt text:**
```
What keyword should the PR agent use to link GitHub Issues?
When a ticket key is a GitHub Issue number, the PR description will include:
  "<keyword> #<N>"
This automatically closes the issue when the PR is merged.
Common values: Closes (default), Fixes, Resolves.

Linking keyword [default: Closes]: [enter value or press Enter to accept default]
```

**Default value:** `Closes`

**Label when shown in inheritance offer:** `GitHub linking keyword`

**Note:** This is never stubbed — the default is always valid.

---

### MCP-Missing Warning for GitHub

Show this in the Phase 7 completion report when no repo MCP is detected:

```
⚠ No repo MCP detected — PR creation phases are absent from the generated
  skill. To enable GitHub integration:
    1. Install the official GitHub MCP server.
    2. Add it to your project .mcp.json or user-level MCP config with a key
       matching "github" (e.g., "github", "github-mcp-server").
    3. Remove .claude/skills/feature-workflow/ and re-run /claudboard-workflow.
```

---

### Sibling Inheritance UI (GitHub)

When one or more sibling repositories have a valid
`.claude/skills/feature-workflow/config.json` with `repo: "github"`:

```
Found feature-workflow GitHub config in sibling repo(s):

  • ../other-service/
      GitHub owner:  my-org
      Linking kw:    Closes

Inherit shared GitHub values from this sibling? [y/n]
```

Fields that CAN be inherited:
- `github.owner` (if not auto-detected)
- `github.linkingKeyword`

Fields that MUST NOT be inherited:
- `github.repo` (always per-repo — each repo has its own slug)

---

## "Stub with TODO" Reference (Repo Fields)

Use this standardised phrasing consistently for every promptable field:

> Type 's' to stub with [TODO: FIELD_KEY] and continue.

Where `FIELD_KEY` is the dotted config.json path in SCREAMING_SNAKE_CASE:
- `azureDevOps.organization` → `ADO_ORGANIZATION`
- `azureDevOps.project` → `ADO_PROJECT`
- `azureDevOps.repositoryId` → `ADO_REPOSITORY_ID`
- `github.owner` → `GITHUB_OWNER`
- `github.repo` → `GITHUB_REPO`
- `github.linkingKeyword` → `GITHUB_LINKING_KEYWORD`

Fields with usable defaults (`github.linkingKeyword`, `git.*`) should accept
Enter as "use default" rather than offering a stub.
