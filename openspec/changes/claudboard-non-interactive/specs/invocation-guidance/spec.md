## ADDED Requirements

### Requirement: Dispatcher SKILL.md documents where to run /analyse
The dispatcher (`skills/claudboard/SKILL.md`) SHALL include a prominent "Where to run /analyse" section that documents the correct invocation directory for each topology mode.

The section MUST cover all three modes:
- **Single repo:** run inside the repo (CWD is the repo root with `.git/`).
- **Monorepo:** run at the repo root (CWD contains `.git/` and multiple build roots beneath it).
- **Workspace:** run at the workspace directory — the parent folder that holds ONLY the related repos. The section MUST explicitly warn that a generic developer folder (e.g., `~/Projects`, `~/code`, `~/dev`) is NOT a workspace.

The section MUST include a one-line recovery instruction: "If you run from the wrong level, re-run from the right one. The catalog regenerates in seconds."

The section MUST be positioned near the top of the dispatcher SKILL.md so users encounter it before invoking any sub-skill.

#### Scenario: Section is present in dispatcher
- **WHEN** `skills/claudboard/SKILL.md` is loaded
- **THEN** it SHALL contain a section titled "Where to run /analyse" or equivalent, with sub-content covering single-repo, monorepo, and workspace modes

#### Scenario: Workspace warning is explicit
- **WHEN** the "Where to run /analyse" section describes workspace mode
- **THEN** the description SHALL explicitly warn against running at a generic developer folder, naming at least one anti-example (e.g., `~/Projects`)

#### Scenario: Recovery instruction is included
- **WHEN** the "Where to run /analyse" section is rendered
- **THEN** it SHALL state that re-running from a different directory is the recovery path for wrong-level invocations

### Requirement: No interactive level selection
The dispatcher and `claudboard-analyse` SKILL.md MUST NOT include any prompt, interactive question, or grace window that asks the user to confirm or change the invocation level.

This requirement makes the "Where to run /analyse" documentation the SOLE mechanism for level selection — there is no fallback interactive path.

#### Scenario: Dispatcher does not prompt for level
- **WHEN** any claudboard sub-skill is invoked
- **THEN** the dispatcher SHALL NOT display any prompt asking the user to confirm the invocation directory or step up to a parent directory

#### Scenario: Analyse skill does not prompt for level
- **WHEN** `/claudboard:claudboard-analyse` is invoked
- **THEN** the analyse skill SHALL NOT display any prompt asking the user to confirm the invocation directory or step up to a parent directory
