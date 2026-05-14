# Validation Notes — feature-workflow template review

Generated: 2026-05-13  
Template version: v1  
Reviewer: Claude (automated validation against hand-edited craftsphere and MEAS copies)

---

## 1. Craftsphere comparison findings

### What matched well

- **Phase structure is identical**: all 7 phases (1-pre through 7) render correctly with JIRA_AVAILABLE=true and ADO_AVAILABLE=true; the ASCII diagram, phase headings, agent spawn calls, and JSON result shapes all match the hand-edited craftsphere version
- **config.json renders exactly**: the rendered output is byte-for-byte identical to craftsphere's hand-written config (after the `customFields` fix described below)
- **Agent architecture table in SKILL.md**: agent bullet list and the quick-reference table at the bottom match craftsphere perfectly
- **All JIRA-specific sections present**: 1-pre Path A/B, 1d worklog, Phase 7 (7a/7b/7c) are all rendered correctly
- **All ADO-specific sections present**: Phase 6 PR creation rendered correctly
- **No orphaned template variables**: all `{{VAR}}` placeholders resolved; no `[TODO: VAR]` markers remain
- **architect-agent Phase A "read context first" section**: renders identically to craftsphere (the research-before-coding mandate)

### Divergences found and fixed

**1. Broken `<!-- IF JIRA_AVAILABLE -->` blocks in SKILL.md intro** (FIXED)

The template had the condition wrapping individual sentence fragments:

```
...this workflow is for work that deserves a
<!-- IF JIRA_AVAILABLE -->
JIRA ticket, a clean branch, and a PR.
<!-- ENDIF -->
<!-- IF JIRA_AVAILABLE -->

**There is exactly one human gate...**
<!-- ENDIF -->
```

This caused garbled output when rendered — the sentence fragment was only kept if JIRA is available, making the sentence incomplete for non-JIRA projects. Similarly, the Project configuration section had three separate `<!-- IF JIRA_AVAILABLE -->` blocks for what should have been a single block.

Fix applied: merged all fragmented opening blocks into clean single blocks. The "JIRA ticket, a clean branch, and a PR." sentence and the "There is exactly one human gate" paragraph were wrapped together in one `<!-- IF JIRA_AVAILABLE -->` block.

**2. `customFields` in config.json.template used `{{JIRA_CUSTOM_FIELD_SPRINT}}` and `{{JIRA_CUSTOM_FIELD_AC}}`** (FIXED)

These vars were not in the provided signal set, and both hand-edited configs (craftsphere and MEAS) use identical values:
- `sprint`: `customfield_10001`
- `acceptanceCriteria`: `customfield_12206`

Fix applied: hardcoded these values in the template (they are consistent across both Bosch Jira instances seen so far).

**3. SKILL.md 1a clarify questions use `{{REPO_OR_SERVICE_LABEL}}` correctly but `{{STACK_REMINDERS}}` is empty for craftsphere**

The template renders `{{STACK_REMINDERS}}` as the last bullet in the 1a clarify section. For craftsphere, this was left as derived hints about Feign/cross-service calls. The hand-edited craftsphere SKILL.md has "Which service/MFE is this for?" instead of the generic "Which {{REPO_OR_SERVICE_LABEL}} is this for?" — a minor cosmetic difference that does not affect runtime behavior. No template change needed; this is an acceptable improvement in the hand-edited version.

**4. architect-agent phase labeling**

The template uses phases A–E. Craftsphere's hand-edited architect-agent uses phases A–D (with "Phase A: Research the codebase" not prefixed as "Read context first"). The template has split this into "Phase A: Read context first" + "Phase B: Research the codebase" — an improvement over the hand-edited version that gives better framing to the context-read-first discipline. No fix needed.

### Remaining minor differences (acceptable)

- Craftsphere's SKILL.md quick-reference table uses `<NNN>-PLAT-X-slug/` (hardcoded PLAT); the template uses `<NNN>-{{TICKET_PREFIX}}-XXXXX-slug/` — correct and more generic
- Craftsphere's architect-agent uses MongoDB-specific patterns (DB entities) throughout because it was originally authored against MongoDB. The template uses the JPA=false/JPA=true conditional blocks, which is the correct generic approach. For craftsphere (JPA=true, MONGODB=false), the golden file correctly includes JPA blocks and excludes MongoDB blocks.

---

## 2. MEAS comparison findings

### What matched well

- **SKILL.md structure**: identical to craftsphere except for the 1a clarify section, which has MEAS-specific service names and questions about `common-dto` and Feign edges
- **config.json**: renders correctly — MEAS uses `pt-iot` org and `ptmt-mm2.0` project, which would be substituted from ADO_ORGANIZATION and ADO_PROJECT vars
- **Phase 4 spec dir note**: `specs/<NNN>-MEAS-XXXXX-slug/` correctly uses TICKET_PREFIX=MEAS

### Divergences found

**1. SKILL.md 1a clarify questions are heavily MEAS-customized**

MEAS's hand-written 1a section includes:
- "Which MEAS repo is this for? (controller / datahandler / subscription / user-account / exportprovider / profile-mapper / web-ui / common-dto)"
- "Does this require an authenticated user (gateway perimeter or user-account JWT validation)?"
- "Does this add a new cross-service Feign/RestClient edge? (check `.claude/memories/ecosystem.md` and workspace `ecosystem-coupling.md`)"
- "Does this touch the shared `common-dto` artifact? (triggers the multi-consumer bump workflow)"

The template renders a generic list + `{{STACK_REMINDERS}}`. These MEAS-specific questions would be carried in `STACK_REMINDERS` when generating for MEAS. This is the correct design — `STACK_REMINDERS` is the injection point for project-specific reminders.

**Status**: no template fix needed. The `STACK_REMINDERS` variable must be populated with MEAS-specific content during the generate step.

**2. Kafka blocks in architect-agent and implementation-agent**

MEAS has KAFKA=true. The template correctly has `<!-- IF KAFKA -->` blocks in:
- `architect-agent.md.template` — Kafka contract section in Phase C
- `implementation-agent.md.template` — Kafka-specific implementation guidance in Step 3
- `sdd-expert-agent.md.template` — Kafka event/messaging research checklist and scenario checklist

The MEAS hand-edited architect-agent has a "Messaging contract (subscription only)" section and the baseline facts section mentions "Kafka and Solace exist as **inbound** consumers in `subscription` only". This detail is MEAS-specific and belongs in `STACK_REMINDERS` or the workspace rule files — not in the generic template.

**Status**: no template fix needed. Kafka blocks render correctly when KAFKA=true.

**3. MEAS architect-agent has extra "Phase B: Workspace-baseline facts"**

The MEAS hand-edited agent has a detailed workspace-baseline section listing Java versions per service, Gradle module patterns, test framework differences, Kafka/Solace presence, etc. This is a MEAS-specific section that would not be generated by the template — it was hand-authored.

**Status**: this is expected and acceptable. The `STACK_REMINDERS` variable and the workspace `.claude/rules/` files are the mechanism for surfacing workspace-baseline facts in the template-generated output.

**4. MEAS ADO org is `pt-iot`, project is `ptmt-mm2.0`**

The template would substitute these correctly from ADO_ORGANIZATION and ADO_PROJECT — confirmed by comparing the MEAS config.json (organization: "pt-iot", project: "ptmt-mm2.0") with the template placeholders.

---

## 3. Stranger project findings

### Rendering with all flags OFF, FastAPI/Python signals

**SKILL.md renders coherently** even with JIRA_AVAILABLE=false and ADO_AVAILABLE=false:
- The intro sentence becomes "...this workflow is for work that deserves a" (sentence incomplete — see issue fixed above; after the fix, the intro simply ends without the JIRA-specific sentence, which is fine for a no-Jira project)
- Phases 1-pre, 7a–7c (JIRA blocks) and Phase 6 (ADO block) are removed
- Phases 1a–1d, 2, 3, 4, 5 remain — the workflow still has: clarify → spec → plan → gate → branch → develop → test → commit → spec-review → design-review → finalize (without PR creation)
- The quick-reference table still makes sense: 12 rows for the non-JIRA/non-ADO phases

**Known gap**: without ADO and JIRA, the "finalize" step disappears entirely and there is no Phase 7. The workflow ends after Phase 5 (design review). The rendered SKILL.md has no "final report to user" section. This is structurally correct for a no-Jira/no-ADO project but the user gets no explicit "done" announcement. The implementation-agent loop still completes — it just doesn't log anything or create a PR. A future improvement would be a simple "Final report" section for the no-JIRA/no-ADO case.

**config.json renders as valid JSON** with only the `git` section:
```json
{
  "git": {
    "branchTypes": ["feature", "bugfix", "hotfix"],
    "branchPattern": "{type}/{ticket}/{slug}",
    "ticketRegex": "[A-Z]+-[0-9]+"
  }
}
```
This is structurally valid. The SKILL.md still reads the config file (the config Read is outside any IF block) and only extracts git values — no JIRA or ADO values are referenced.

**architect-agent renders usefully** without any capability blocks (MONGODB=false, JPA=false, KAFKA=false, CROSS_SERVICE_EDGES=false, SHARED_LIB=false, AUTH_PERIMETER=false, WORKSPACE_MODE=false, MEMORIES_PRESENT=false). The remaining content covers:
- REST API contract
- Domain model contract
- Persistence entity contract (generic, not JPA or MongoDB-specific)
- Repository port contract
- Command contract
- Frontend contracts

For a FastAPI project, "REST API contract" and "Command contract" are directly applicable. The persistence contract is generic enough. The output is coherent though not Python-aware — it would benefit from `STACK_REMINDERS` with FastAPI/Pydantic v2 guidance.

**jira-agent.md is skipped** (JIRA_AVAILABLE=false → the file is not copied during generation)
**pr-agent.md is skipped** (ADO_AVAILABLE=false → the file is not copied during generation)

**Completion report note**: the current template does not include a "MCP unavailable" warning section in SKILL.md. When both JIRA and ADO are unavailable, there is no warning to the user that ticket creation and PR creation are not automated. This is a minor gap but not a blocking issue — the user is already aware of what the project supports when they ran `/analyse`.

---

## 4. E2E run prerequisites

A real end-to-end validation on MEAS (or any project) requires:

### Step 1: Run `/analyse` on the target repo

```
cd /path/to/meas.cloud.datahandler
/analyse
```

This produces `.claude/reports/claudboard-analysis.md` with detected flags:
- Stack detection → KAFKA flag, JPA/MongoDB, WORKSPACE_MODE
- MCP tool detection → JIRA_AVAILABLE, ADO_AVAILABLE
- Workspace detection → CROSS_SERVICE_EDGES, SHARED_LIB

### Step 2: Run `/generate` (in a fresh session)

```
/generate
```

This reads the analysis report and generates `.claude/` artifacts: CLAUDE.md,
rules, skills including `feature-workflow`.

### Step 3: Run `/claudboard-workflow` (or the generate step for this skill)

The claudboard-workflow generate step reads the analysis report, resolves all
template variables and capability flags, renders each `.template` file, copies
portable files verbatim, and writes the output to
`.claude/skills/feature-workflow/`.

### Step 4: Validate the generated output

Compare the generated files against:
1. The golden files in `tests/golden/feature-workflow-craftsphere/` (for craftsphere)
2. The hand-edited MEAS files in `meas.cloud.datahandler/.claude/skills/feature-workflow/`

Structural diff should show:
- Same phases and sections
- Kafka-specific blocks present for MEAS (KAFKA=true)
- JPA blocks absent for MEAS datahandler (uses MongoDB, not JPA — MEAS has MongoDB=true)
- Correct ADO org (`pt-iot`) and project (`ptmt-mm2.0`) in config.json

### Step 5: Live test the generated skill

Run `start feature: <something>` in the target project and walk through Phase 1.
Verify:
- JIRA ticket is created with correct `MEAS` project key
- BDD spec is written to `specs/001-MEAS-XXXXX-<slug>/`
- architect-agent reads CLAUDE.md and .claude/rules/ before planning
- Branch follows `feature/MEAS-<num>/<slug>` pattern
- PR is created in the `pt-iot/ptmt-mm2.0` ADO project

---

## 5. Known limitations

### Template limitations that require a real E2E run to fix

**1. STACK_REMINDERS content is not validated**

The `STACK_REMINDERS` variable is the primary injection point for
project-specific guidance in 1a (clarify), architect-agent, implementation-agent,
and sdd-expert-agent. The template correctly renders the variable, but the
quality of the output depends entirely on what claudboard-workflow puts into it.
This cannot be validated without running `/analyse` on a real project.

**2. The "no Jira/no ADO" completion path has no explicit final report**

When JIRA_AVAILABLE=false and ADO_AVAILABLE=false, the workflow ends after Phase 5
with no explicit "done" message to the user. The implementation is correct but
the UX is abrupt. A `<!-- IF JIRA_AVAILABLE -->...<!-- ELSE -->...<!-- ENDIF -->`
construct (if the templating engine supported it) would allow a generic "you're
done" message. Without it, the generator must add a brief final-report paragraph
outside any flag block.

**3. MEAS SKILL.md 1a clarify questions require `STACK_REMINDERS` to be rich**

The generated MEAS SKILL.md will have a generic 1a list + whatever `STACK_REMINDERS`
contains. The hand-edited MEAS version has specific service-names and workspace
topology questions embedded in 1a. This means the generated version is less
MEAS-specific than the hand-edited one. Acceptable for v1 — a future improvement
could add workspace-topology-specific questions as additional IF blocks
(e.g., `<!-- IF WORKSPACE_MODE -->`).

**4. architect-agent plan structure does not include a "Repo context referenced" section header in the template**

The template uses "Context referenced" while the MEAS hand-edited version uses
"Repo context referenced". Minor wording difference — no functional impact.

**5. customFields Jira sprint/AC field IDs are hardcoded**

Fixed by hardcoding `customfield_10001` and `customfield_12206` in the template.
This works for Bosch Jira instances seen so far, but a different organization might
use different field IDs. If the template is used outside Bosch, these values need
to be made configurable (added to the signal set).
