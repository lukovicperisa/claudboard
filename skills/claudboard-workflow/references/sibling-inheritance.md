# Sibling-repo Inheritance

**Load gate:** Used during Phase 2b of the workflow generator. Load this file
only when the post-filter `siblings` array (emitted by detect.sh) is
non-empty. detect.sh has already dropped siblings whose only inheritable
values were `[TODO: …]` stubs or exact matches of the documented defaults
(`customfield_10001`, `customfield_12206`, `Closes`); offering them would be
vacuous. Phase 2b must NOT load this file when the array is empty.

---

## Inheritance offer wording

When siblings are detected, present:

```
Found feature-workflow config in sibling repo(s):
  • ../order-service/ — jira.projectKey: PLAT, jira.urlBase: https://example.atlassian.net

Inherit shared values from a sibling? [y/n]
```

If multiple siblings: list each one with its `config_summary` fields, then ask
which to inherit from.

After the user accepts, mark all inherited fields as resolved in the config-
gathering state. Continue to Phase 2c for any remaining unresolved fields.

---

## Fields that CAN be inherited (present in sibling `config_summary`)

- `jira.cloudId`
- `jira.projectKey`
- `jira.urlBase`
- `jira.customFields.sprint`
- `jira.customFields.acceptanceCriteria`
- `azureDevOps.org` (when not auto-detected from git remote)
- `azureDevOps.project` (when not auto-detected from git remote)
- `tr.baseUrl`
- `tr.projectKey`
- `github.owner` (when not auto-detected from git remote)
- `github.repo` (when not auto-detected from git remote)

## Fields that MUST NOT be inherited (always per-repo)

- `azureDevOps.repositoryId` — UUID unique per repo; always prompt, never inherit
- `azureDevOps.repositoryName` — display name sourced from git remote or prompted
