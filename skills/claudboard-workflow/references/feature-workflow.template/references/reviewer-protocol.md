## What you receive

INPUT CONTEXT with:

- `changedFiles` — list of files changed in this feature (from `git diff --name-only <main-branch>..HEAD`, where `<main-branch>` is auto-detected by git-agent)
- `area` — BE, FE, DevOps, or Docs
<!-- IF WORKSPACE_MODE -->
- `repo` (workspace mode) — repo directory name under the workspace root
<!-- ENDIF -->

---

<!-- IF WORKSPACE_MODE -->
## Workspace-mode: load per-repo context first

If INPUT CONTEXT includes a `repo` field, load per-repo context before reviewing:

```bash
bash <workspaceRoot>/.claude/skills/feature-workflow/scripts/load-repo-context.sh <repo>
```

This reads `<workspaceRoot>/<repo>/.claude/{CLAUDE.md,rules/*.md,memory/MEMORY.md}`
and lists the skills directory. All paths for `changedFiles` are resolved under
`<workspaceRoot>/<repo>/`. Run git diff scoped to the repo:

```bash
(cd "<workspaceRoot>/<repo>" && git diff "$MAIN_BRANCH..HEAD" -- <file>)
```
<!-- ENDIF -->

## Read the diff first (context loading)

Before evaluating anything, read the diff — it tells you what was **changed**, not just what the code looks like now:

```bash
source .claude/skills/feature-workflow/scripts/lib.sh
MAIN_BRANCH=$(detect_main_branch)
git diff "$MAIN_BRANCH..HEAD" -- <service>
```

**Key rules to avoid false positives:**
- A field removed from a DTO (visible as a deleted line in the diff) satisfies a spec scenario that says "response does not include that field"
- Do NOT conclude "was never implemented" just because current code doesn't contain something — the implementation may be a removal
- When a scenario describes an absence (e.g., "does not include X"), verify via the diff that X was previously present and is now gone, OR that it was never there — either satisfies the spec

## Read all changed source and test files

Read every file in `changedFiles` that is a source or test file:

**Backend (area = BE):**
- Source: files under `src/main/` (e.g., `*.java`, `*.kt`)
- Tests: files under `src/test/` — check the project's actual test framework (JUnit 5, Spock, etc.) by looking at file extensions and build files

**Frontend (area = FE):**
- Source: `*.ts`, `*.tsx` files under `src/`
- Tests: `*.test.ts`, `*.test.tsx`, `*.spec.ts`, `*.spec.tsx` files

**Infrastructure (area = DevOps):**
- Source: `*.yaml`, `Dockerfile*` files
- Tests: not applicable — skip test coverage checks

If `changedFiles` is large (>20 files), prioritize reading files most relevant to the concern under review.

---

## Step 5: Compile findings

For each issue, classify severity:

**Critical** — blocks the PR:
- A check fails completely (missing implementation, implementation contradicts spec or rule, security vulnerability)
- A business-critical behavior has zero test coverage

**Major** — should fix but does not block:
- Partial failure or near-miss
- Test coverage exists but does not fully exercise an important path
- Pattern or convention deviation

**Minor** — nice to have:
- Naming or style suggestion
- Additional test suggestion
- Minor discrepancy or improvement opportunity

---

## Determining passed/failed

- `passed: true` — there are ZERO Critical findings
- `passed: false` — there is at least one Critical finding

Major and Minor findings are reported but do not cause failure.

---

## Output structure

Emit a JSON result block as the final content of your response.
If there are no findings, set `"findings": []` and write a "No findings" summary.
