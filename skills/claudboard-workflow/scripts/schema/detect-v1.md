# detect.sh — v1 JSON Output Schema

`skills/claudboard-workflow/scripts/detect.sh` emits a single JSON document to
stdout. The workflow SKILL.md asserts `schema_version == "1"` before consuming
any field. If the version does not match, the SKILL.md stops with an actionable
error rather than silently mis-interpreting the output.

---

## Top-level shape

```json
{
  "schema_version": "1",
  "mcp": { ... },
  "git_remote": { ... },
  "siblings": [ ... ],
  "unresolved": { ... },
  "warnings": [ ... ]
}
```

---

## `mcp` block

Resolved MCP detection state across the tracker and repo dimensions.

```json
{
  "mcp": {
    "tracker_jira": false,
    "tracker_tr": true,
    "repo_ado": true,
    "repo_github": false,
    "sources": {
      "tracker_tr": { "source": "project", "config_path": ".mcp.json", "matched_via": "name" },
      "repo_ado":   { "source": "user",    "matched_via": "args" }
    },
    "ambiguities": [],
    "suppressed": [
      { "dimension": "tracker", "backend": "tracker_jira", "suppressed_by": "project-level tracker_tr" }
    ]
  }
}
```

### Fields

| Field | Type | Semantics |
|---|---|---|
| `tracker_jira` | bool | Atlassian Jira MCP detected and selected for tracker dimension |
| `tracker_tr` | bool | Bosch Track & Release MCP detected and selected |
| `repo_ado` | bool | Azure DevOps MCP detected and selected for repo dimension |
| `repo_github` | bool | GitHub MCP detected and selected |
| `sources` | object | Per-detected-backend map with `source` ("project"/"user"), optional `config_path`, and `matched_via` ("name"/"args") |
| `ambiguities` | array | Non-empty when both backends in a dimension matched at the same precedence level; each entry: `{"dimension":"tracker"|"repo","sources":[path1,path2]}` |
| `suppressed` | array | Backends suppressed by project-level precedence; each entry: `{"dimension","backend","suppressed_by"}` |

### Detection keyword tables (encoded in detect.sh)

| Backend | Flag | Name match (case-insensitive) | Args match (case-insensitive) |
|---|---|---|---|
| Atlassian Jira | `tracker_jira` | contains `atlassian`, `jira`, or `confluence` | contains `@atlassian/` |
| Bosch T&R | `tracker_tr` | contains `bosch-jira-mcp` or `bosch-jira` | contains `bosch-jira-mcp` |
| Azure DevOps | `repo_ado` | contains `azure-devops` or `ado` | contains `azure-devops-mcp` or `@microsoft/azure` |
| GitHub | `repo_github` | contains `github` | contains `github-mcp-server` or `@modelcontextprotocol/server-github` |

### Precedence rules

- Project-level `.mcp.json` takes precedence over user-level configs in the same
  dimension. Project-level match → the conflicting user-level entry is recorded
  in `suppressed`, not in `sources`.
- Ambiguity (populated in `ambiguities`) only occurs when both backends in a
  dimension match at the same precedence level (both project or both user).

---

## `git_remote` block

```json
{
  "git_remote": {
    "provider": "azure-devops",
    "azure_devops": { "org": "bosch-meas", "project": "platform", "repo": "datahandler" },
    "github": null
  }
}
```

| Field | Type | Semantics |
|---|---|---|
| `provider` | `"azure-devops"` \| `"github"` \| `null` | Detected remote provider; `null` if no recognised pattern |
| `azure_devops` | object \| `null` | `{ org, project, repo }` when provider is `azure-devops` |
| `github` | object \| `null` | `{ owner, repo }` when provider is `github` |

### URL patterns (encoded in detect.sh)

| Pattern | Example |
|---|---|
| ADO modern | `https://dev.azure.com/{org}/{project}/_git/{repo}` |
| ADO legacy | `https://{org}.visualstudio.com/{project}/_git/{repo}` |
| GitHub SSH | `git@github.com:{owner}/{repo}[.git]` |
| GitHub HTTPS | `https://github.com/{owner}/{repo}[.git]` |

---

## `siblings` array

Sibling repos found under `../*/` that have a `feature-workflow/config.json`.

```json
{
  "siblings": [
    {
      "path": "../order-service",
      "config_summary": {
        "jira.cloudId":    "a1b2c3d4-...",
        "jira.projectKey": "PLAT",
        "jira.urlBase":    "https://example.atlassian.net"
      }
    }
  ]
}
```

`config_summary` contains only the inheritable fields found in the sibling's
`config.json` (see `references/sibling-inheritance.md` for the allowlist). Fields
absent from the sibling config are omitted from the summary — they remain candidates
for user prompting.

---

## `unresolved` block

Config fields that detection could not satisfy (no MCP value, no git-remote
auto-detect, no sibling value). These are the fields that will require user input
in Phase 2c.

```json
{
  "unresolved": {
    "tracker": ["tr.baseUrl", "tr.projectKey"],
    "repo":    ["azureDevOps.repositoryId"]
  }
}
```

`unresolved.tracker` is empty when `tracker_jira` and `tracker_tr` are both false.
`unresolved.repo` always includes `azureDevOps.repositoryId` when `repo_ado` is
true (the UUID cannot be auto-detected from any source).

The SKILL.md uses these arrays as gating signals for conditional reference loading
(see "Reference Load Gates" in SKILL.md).

---

## `warnings` array

Soft-failure conditions that did not abort the script. The SKILL.md surfaces these
to the user.

```json
{
  "warnings": [
    "Indirect match (args-only) for tracker_jira — verify this is the intended MCP backend",
    "Could not parse mcpServers from /home/dev/.claude.json — skipped"
  ]
}
```

Warning types:
- **Indirect match** — backend matched via command/args, not server name; user should verify
- **Parse failure** — a config file exists but contains malformed JSON or no `mcpServers` key
- **Malformed sibling config** — a sibling's `config.json` could not be parsed

---

## Schema evolution

Increment `schema_version` (as a string) whenever a field is renamed, removed, or
its semantics change in a breaking way. The SKILL.md asserts on the version string
and stops with an actionable error if mismatched. Additive changes (new fields)
that preserve all existing field semantics do not require a version bump.
