## Tasks

### Prerequisite

- [x] Confirm landing order with `slim-feature-workflow-orchestrator` change (this change depends on `references/ticket-description-template.md` existing in the template tree)

### Generator infrastructure

- [x] Decide implementation: introduce `{{INCLUDE <path>}}` directive in the generator's render loop OR hard-code per-agent concat in `claudboard-workflow/SKILL.md`
- [x] If using `{{INCLUDE}}`: implement the pre-pass in the generator's file-rendering phase; resolve `<path>` relative to template tree root; substitute file contents before the normal `{{VAR}}` substitution
- [x] Document the chosen approach in `skills/claudboard-workflow/SKILL.md`
- [x] Add a smoke test: render a small agent file with one INCLUDE directive and verify the output contains the included content

### Bucket E — Shared agent preamble

- [x] Create `skills/claudboard-workflow/references/feature-workflow.template/references/agent-preamble.md` (~5 lines: scoped tool access, action-from-INPUT-CONTEXT, JSON result block as final emission)
- [x] Update `architect-agent.md.template`: remove verbose preamble, replace with `{{INCLUDE references/agent-preamble.md}}` + agent-specific job statement
- [x] Update `implementation-agent.md.template`: same
- [x] Update `sdd-expert-agent.md.template`: same
- [x] Update `spec-reviewer.md.template`: same
- [x] Update `design-reviewer.md.template`: same
- [x] Update `git-agent.md.template`: same
- [x] Update `jira-agent.md`: same
- [x] Update `tr-agent.md`: same
- [x] Update `pr-agent-ado.md`: same
- [x] Update `pr-agent-github.md`: same

### Bucket F — Shared context-loading snippet

- [x] Create `references/agent-context-loading.md` (8-12 lines: CLAUDE.md, rules/, memories/, skills/ in priority order)
- [x] Update `sdd-expert-agent.md.template`: replace "Research the service first" verbose section with `{{INCLUDE references/agent-context-loading.md}}` + a 3-line "what to extract" override for vocabulary
- [x] Update `architect-agent.md.template`: replace "Phase A: Read this service's context FIRST" with the include + override for conventions
- [x] Update `implementation-agent.md.template`: replace "Coding standards — read context first" with the include + override for the rule-to-area mapping table (which is agent-specific signal)
- [x] Update `spec-reviewer.md.template`: add the include if context-loading is needed
- [x] Update `design-reviewer.md.template`: add the include + override emphasising rule files specifically

### Bucket G — Architect Plan structure tightening

- [x] Replace `architect-agent.md.template` "Plan structure" section (lines ~509-650) with skeleton-headings-only list (~60-80 lines)
- [x] Verify Phase C contract templates remain authoritative for body content
- [x] Verify the IF-gated tracker AC placement note now references `references/ticket-description-template.md` instead of inlining

### Bucket H — AC template consolidation

- [x] Update `jira-agent.md` `create` action: reference `references/ticket-description-template.md` instead of inlining the Goal/AC/Context template
- [x] Update `jira-agent.md` `updateDescription` action: same
- [x] Update `architect-agent.md.template` Plan structure AC placement: reference the same file
- [x] Verify no other place inlines the AC template (grep for `## Goal\n.*## Acceptance Criteria\n.*## Context` patterns)

### Bucket I — Shared reviewer protocol

- [x] Create `references/reviewer-protocol.md` (~90 lines: shared "What you receive", workspace-mode loading, Step 1 load context, Step 2 read changed files, Step 5 compile findings, Determining passed/failed, Output JSON shape)
- [x] Update `spec-reviewer.md.template`: shrink to frontmatter + agent description + preamble include + INCLUDE reviewer-protocol + spec-specific Step 3 (verify each scenario) + Step 4 (check for scope drift)
- [x] Update `design-reviewer.md.template`: shrink to frontmatter + description + preamble + INCLUDE reviewer-protocol + design-specific Step 3 (apply rule checks) + Step 4 (general quality review)
- [x] Verify both reviewers' rubric-specific content (their actual "what to check" sections) is preserved unchanged

### Bucket J — Per-action output JSON shape consolidation

- [x] In each multi-action agent (jira-agent, tr-agent, git-agent, implementation-agent, architect-agent, pr-agent-github), add a "Standard error output" section near the top after Configuration
- [x] Replace per-action "Output (failure)" blocks with one-liners: *"On failure: emit the standard error shape with `action: '<this action>'`."*
- [x] Verify per-action "Output (success)" blocks remain inline (they vary by action)

### Verification

- [x] Generator dry-run on craftsphere-style config — verify each generated agent file is 15-30% smaller than before AND contains the inlined preamble, context-loading, and (for reviewers) protocol content
- [x] Generator dry-run on MEAS workspace config (workspace + T&R + ADO) — verify workspace-mode IF blocks still render correctly inside each agent
- [x] Full feature-workflow eval against a craftsphere repo — run a complete `/start-feature` for a simple BE feature; verify every agent action completes successfully and emits parseable JSON
- [x] Specific check on architect-agent: produced `execution-plan.md` contains all required headings and the contract bodies follow the Phase C templates
- [x] Specific check on implementation-agent: it still reads CLAUDE.md and rules before implementing, and respects conventions (constructor injection, log-or-throw, naming) — verifiable by inspecting the produced code
- [x] Specific check on spec-reviewer and design-reviewer: each produces a parseable findings JSON and applies its rubric correctly
- [x] Specific check: jira-agent's `create` action produces a ticket with the right description structure (referencing the shared template)

### Documentation

- [x] Update `CLAUDE.md` "Skill Anatomy" section to mention `references/agent-preamble.md`, `references/agent-context-loading.md`, `references/reviewer-protocol.md`, `references/ticket-description-template.md` as shared snippet files inlined at generation time
- [x] Note in change-archive entry: the generator now supports source-tree dedup via inlining (mechanism: `{{INCLUDE}}` directive or hard-coded concat); future agent additions can reuse the shared snippets
