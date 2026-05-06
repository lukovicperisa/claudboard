## ADDED Requirements

### Requirement: Guard against microservice-level analysis
Before any analysis begins, the system SHALL check whether the CWD is a microservice within a larger system by detecting sibling service directories at the parent level.

A sibling service is a directory at `../` that contains a build file (`build.gradle`, `pom.xml`, `package.json`, `go.mod`, `pyproject.toml`, `Cargo.toml`, `*.csproj`).

If N≥2 sibling service directories are found, the system SHALL present the step-up prompt before proceeding.

#### Scenario: Microservice with siblings detected
- **WHEN** `/analyse` is run from `order-service/` AND `../user-service/` and `../frontend/` contain build files
- **THEN** the system SHALL display: "This looks like a microservice within a larger system. Found sibling services at [parent/]: [user-service (Java/Spring Boot), frontend (React/TS)]. Analyse at ecosystem level for cross-service dependency mapping? [y/n]"

#### Scenario: User steps up to ecosystem level
- **WHEN** the step-up prompt is shown AND the user answers "y"
- **THEN** the system SHALL re-run analysis from the parent directory as workspace mode

#### Scenario: User declines step-up
- **WHEN** the step-up prompt is shown AND the user answers "n"
- **THEN** the system SHALL proceed with analysis at the current directory without further checks

#### Scenario: No siblings detected
- **WHEN** `/analyse` is run from a directory with a build file AND the parent directory has no other build-file directories
- **THEN** the system SHALL skip the step-up check and proceed with single-project analysis

#### Scenario: Already at workspace or monorepo root
- **WHEN** `/analyse` is run from a directory with no build file
- **THEN** the system SHALL skip the step-up check entirely and proceed with workspace or monorepo detection

### Requirement: Show sibling details in step-up prompt
The step-up prompt SHALL include the detected stack for each sibling to help the user make an informed decision.

#### Scenario: Sibling stack shown
- **WHEN** siblings are detected and the step-up prompt is displayed
- **THEN** each sibling SHALL be listed with its detected stack (e.g., "user-service (Java/Spring Boot)", "frontend (React/TypeScript)")

#### Scenario: Unknown sibling stack
- **WHEN** a sibling's stack cannot be determined from its build file
- **THEN** it SHALL be listed as "sibling-dir (unknown stack)"
