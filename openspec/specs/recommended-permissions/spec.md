## ADDED Requirements

### Requirement: Ship recommended-permissions bundle
The system SHALL ship a curated permission allowlist as `skills/claudboard/references/recommended-permissions.json` covering every Bash command, Read pattern, and Write pattern the claudboard read-only analysis pipeline invokes.

The bundle MUST include at minimum:
- `Bash(find . -maxdepth * -name *:*)` for topology discovery
- `Bash(bash scripts/discover.sh:*)` for the discovery script
- `Bash(jq:*)` for JSON parsing
- `Bash(mkdir -p .claudboard:*)` and `Bash(mkdir -p .claude:*)` for output directory creation
- `Bash(git log:*)`, `Bash(git branch:*)`, `Bash(git status:*)` for git history analysis
- `Bash(grep:*)`, `Bash(rg:*)` for pattern searches
- `Read(./**)` for source file inspection
- `Write(./.claudboard/**)` for catalog and audit outputs
- `Write(./.claude/reports/**)`, `Write(./.claude/memories/**)`, `Write(./.claude/rules/**)`, `Write(./.claude/skills/**)` for generated artifacts
- `Write(./CLAUDE.md)` for the main project documentation file

The bundle MUST be valid JSON that can be merged into the `permissions.allow` array of `.claude/settings.json` without transformation.

The bundle MUST include a version marker: `"_claudboard_permissions_version": "1"` as a top-level key, separate from the allow patterns.

#### Scenario: Bundle file exists at canonical path
- **WHEN** the claudboard plugin is installed
- **THEN** `skills/claudboard/references/recommended-permissions.json` SHALL exist and parse as valid JSON

#### Scenario: Bundle covers the analyse pipeline
- **WHEN** `/analyse` is run end-to-end on a sample repo with the bundle merged into `.claude/settings.json`
- **THEN** no Bash, Read, or Write tool call SHALL trigger a permission prompt

### Requirement: One-shot auto-merge offer on first invocation
On the first invocation of any claudboard sub-skill (`/analyse`, `/generate`, `/refresh`, `/techdebt`, or `/claudboard-workflow`) in a repository, the dispatcher (`skills/claudboard/SKILL.md`) SHALL check whether `.claude/settings.json` contains the marker key `"_claudboard_permissions_version"`.

If the marker is absent, the dispatcher SHALL display exactly one prompt: "Add claudboard's recommended permissions to .claude/settings.json? This eliminates ~20 prompts per analysis run. [y/n]".

On user response `y` (or any case-insensitive variant of "yes"):
- The dispatcher SHALL merge the bundle's allow patterns into the existing `permissions.allow` array, preserving all existing entries, deduplicating by exact string match.
- The dispatcher SHALL write the marker key `"_claudboard_permissions_version": "1"` into `.claude/settings.json`.
- The dispatcher SHALL print one confirmation line: "Recommended permissions added — future runs will not prompt."

On user response `n` (or any case-insensitive variant of "no"):
- The dispatcher SHALL write the marker key `"_claudboard_permissions_version": "1-declined"` into `.claude/settings.json`.
- The dispatcher SHALL print the copy-paste fallback (the contents of the bundle JSON) so the user can manually merge it later.
- The dispatcher MUST NOT re-prompt on subsequent runs.

The dispatcher MUST NOT modify any key in `.claude/settings.json` other than `permissions.allow` and the marker.

#### Scenario: First invocation with no marker
- **WHEN** any claudboard sub-skill is invoked AND `.claude/settings.json` does not contain `_claudboard_permissions_version`
- **THEN** the dispatcher SHALL display the one-shot offer prompt before proceeding to the sub-skill

#### Scenario: User accepts the offer
- **WHEN** the user responds "y" to the offer
- **THEN** the dispatcher SHALL merge the bundle into `permissions.allow`, write the marker as "1", print confirmation, and continue to the sub-skill

#### Scenario: User declines the offer
- **WHEN** the user responds "n" to the offer
- **THEN** the dispatcher SHALL write the marker as "1-declined", print the copy-paste fallback, and continue to the sub-skill

#### Scenario: Subsequent invocation with marker present
- **WHEN** any claudboard sub-skill is invoked AND `.claude/settings.json` contains `_claudboard_permissions_version: "1"` or `_claudboard_permissions_version: "1-declined"`
- **THEN** the dispatcher SHALL NOT display the offer prompt and SHALL proceed directly to the sub-skill

#### Scenario: Existing user permissions are preserved
- **WHEN** the user accepts the offer AND `.claude/settings.json` already contains user-specific entries in `permissions.allow`
- **THEN** all existing entries SHALL remain in the array after the merge, and only new patterns from the bundle SHALL be appended

#### Scenario: Settings file is not modified outside scope
- **WHEN** the dispatcher merges the bundle
- **THEN** no key in `.claude/settings.json` other than `permissions.allow` and `_claudboard_permissions_version` SHALL be modified

### Requirement: Future bundle versions reset the decline flag
When a future bundle version increments the marker (e.g., `"_claudboard_permissions_version": "2"`), the dispatcher SHALL treat a stored `"1-declined"` marker as "decision made for v1 only" and SHALL re-prompt for the v2 bundle.

#### Scenario: V2 bundle ships, v1 was declined
- **WHEN** the dispatcher loads a bundle with `_claudboard_permissions_version: "2"` AND `.claude/settings.json` contains `_claudboard_permissions_version: "1-declined"`
- **THEN** the dispatcher SHALL display the offer prompt for the v2 bundle and update the marker based on the user's new response
