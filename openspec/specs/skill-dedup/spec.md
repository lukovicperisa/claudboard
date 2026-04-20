## ADDED Requirements

### Requirement: Pairwise skill overlap detection
After collecting all skill triggers in Phase 2, the scanner SHALL compare each pair of proposed skills for overlap by checking: (1) target file glob intersection >50%, (2) same trigger annotation appearing in both skill scopes.

#### Scenario: Overlapping skills detected
- **WHEN** two proposed skills have >50% file glob overlap (e.g., `mongodb-entity` targets `**/model/*.java` and `leaf-entity` targets the same models)
- **THEN** report flags the overlap and suggests merge or disambiguation to user in Phase 2 proposal

#### Scenario: Same trigger in multiple skills
- **WHEN** annotation like `@Document` triggers both `mongodb-entity` and `leaf-entity` skills
- **THEN** report groups them and asks user: "These skills overlap — merge into one or keep separate with distinct scopes?"

#### Scenario: No overlap
- **WHEN** all proposed skills have distinct file globs and trigger patterns
- **THEN** no dedup warning shown

### Requirement: Dedup is advisory only
The scanner SHALL NOT auto-merge skills. Overlap detection MUST present findings to user in Phase 2 report and wait for user decision before Phase 3 generation.

#### Scenario: User chooses merge
- **WHEN** user confirms merge of overlapping skills
- **THEN** Phase 3 generates single merged skill covering both scopes

#### Scenario: User keeps separate
- **WHEN** user says keep skills separate
- **THEN** Phase 3 generates both skills with explicit scope distinction noted in each SKILL.md description
