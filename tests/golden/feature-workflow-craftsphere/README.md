# Golden File Set: feature-workflow on craftsphere

## What this is

This directory contains the **expected rendered output** when
`claudboard-workflow` generates a `feature-workflow` skill for the
`craftsphere.cloud` monorepo with all capability flags turned on.

It serves as a regression baseline: if a template change causes structural
divergence from these files, it is a signal to review the change carefully.

## Capability flags used for rendering

| Flag | Value |
|------|-------|
| JIRA_AVAILABLE | true |
| ADO_AVAILABLE | true |
| WORKSPACE_MODE | true |
| CROSS_SERVICE_EDGES | true |
| SHARED_LIB | true |
| AUTH_PERIMETER | true |
| MEMORIES_PRESENT | true |
| MONGODB | false |
| JPA | true |
| KAFKA | false |

## Substitution values used

| Variable | Value |
|----------|-------|
| PROJECT_NAME | craftsphere |
| REPO_NAME | craftsphere.cloud |
| STACK_NAME | Spring Boot / Java 21 / Gradle / React / TypeScript |
| TEST_FRAMEWORK | JUnit 5 / Spock |
| BASE_PACKAGE | com.bosch.pt.csm |
| BUILD_CMD | ./gradlew build |
| TEST_CMD | ./gradlew test |
| LINT_CMD | ./gradlew spotlessCheck |
| TICKET_PREFIX | PLAT |
| WORKSPACE_NAME | Craftsphere |
| REPO_OR_SERVICE_LABEL | monorepo |
| JIRA_CLOUD_ID | 87892ce5-31f3-4c45-9869-c15f395daa14 |
| JIRA_URL_BASE | https://bosch-pt.atlassian.net |
| ADO_ORGANIZATION | bosch-pt |
| ADO_PROJECT | Craftsphere |
| ADO_REPOSITORY_ID | eb1f3b5e-9461-4fe7-9ca2-3dfc1a2b0aa6 |
| GIT_BRANCH_PATTERN | {type}/{ticket}/{slug} |

## Contents

| File | Source template | Notes |
|------|----------------|-------|
| `SKILL.md` | `SKILL.md.template` | All JIRA + ADO phases included |
| `config.json` | `config.json.template` | Full jira + azureDevOps + git sections |
| `agents/git-agent.md` | `git-agent.md.template` | No template variables — output is identical to template |
| `agents/pr-agent.md` | `pr-agent.md.template` | TICKET_PREFIX rendered to PLAT |
| `agents/spec-reviewer.md` | `spec-reviewer.md.template` | BASE_PACKAGE and REPO_OR_SERVICE_LABEL substituted |
| `agents/design-reviewer.md` | `design-reviewer.md.template` | PROJECT_NAME and REPO_OR_SERVICE_LABEL substituted |
| `agents/architect-agent.md` | `architect-agent.md.template` | All flags rendered; JPA block included; MongoDB/Kafka blocks removed |
| `agents/implementation-agent.md` | `implementation-agent.md.template` | All build/test/lint commands substituted; JPA block included |
| `agents/sdd-expert-agent.md` | `sdd-expert-agent.md.template` | WORKSPACE_MODE, AUTH_PERIMETER, CROSS_SERVICE_EDGES, SHARED_LIB blocks included; KAFKA block removed |

## Files NOT included (verbatim copies from craftsphere)

These files are copied verbatim during generation — no rendering needed:

- `agents/jira-agent.md` — portable, no template variables
- `scripts/lib.sh`, `scripts/prepare-commit.sh`, `scripts/prepare-pr.sh`, `scripts/prepare-squash.sh`
- `references/claude-pricing.md`

## How to update

When templates change, re-render by applying the same flags and substitution
values listed above to each `.template` file:

1. Apply `<!-- IF FLAG -->...<!-- ENDIF -->` logic: keep inner content when flag is true (removing the comment lines), remove entire block when false
2. Replace `{{VAR}}` placeholders with the values from the substitution table above
3. Write the result to the corresponding file in this directory

## Template version

Rendered from template version **v1** on **2026-05-13**.
