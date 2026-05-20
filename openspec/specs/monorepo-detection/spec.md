## Requirements

### Requirement: Auto-detect monorepo structure
The system SHALL detect monorepo structure by finding multiple independent build root directories in the repository. A build root is a directory containing a build file (`build.gradle`, `build.gradle.kts`, `pom.xml`, `package.json`, `go.mod`, `Cargo.toml`, `pyproject.toml`, `*.csproj`/`*.sln`) that is not a nested dependency (e.g., not inside `node_modules/`, `vendor/`, `.venv/`).

#### Scenario: Monorepo with independent build roots
- **WHEN** the repository contains 2+ independent build root directories
- **THEN** the system SHALL identify it as a monorepo and list all detected build roots

#### Scenario: Single-project repository
- **WHEN** the repository contains exactly 1 build root (possibly with nested submodules)
- **THEN** the system SHALL proceed with the existing single-project analysis flow unchanged

#### Scenario: Gradle/Maven multi-module with shared build root
- **WHEN** the repository has a single root build file with submodule declarations (e.g., `settings.gradle` with `include` statements) AND per-module Dockerfiles exist
- **THEN** the system SHALL present findings to the user and ask: "This looks like a multi-module project with per-module deployments. Treat as monorepo with N services?"

### Requirement: Classify build roots as service or library
The system SHALL classify each detected build root as either a service or a library.

A build root is a **service** if ANY of:
- Has a `Dockerfile` in its directory
- Has a main entry point (`@SpringBootApplication`, `public static void main`, `package main`, `func main()`, `"start"` script in package.json, `__main__.py`, `if __name__ == "__main__"`)
- Has runtime configuration (`application.yml`, `application.properties`, `.env`)

A build root is a **library** if ALL of:
- Has publish tasks (`maven-publish` plugin, `"publishConfig"` in package.json, `[build-system]` in pyproject.toml)
- Has NO main entry point
- Has NO Dockerfile

#### Scenario: Java Spring Boot service detection
- **WHEN** a build root contains `@SpringBootApplication` and a `Dockerfile`
- **THEN** it SHALL be classified as a service

#### Scenario: Java library with publish tasks
- **WHEN** a build root has `maven-publish` plugin, no `main` method, and no `Dockerfile`
- **THEN** it SHALL be classified as a library

#### Scenario: Ambiguous classification
- **WHEN** a build root matches neither service nor library signals clearly
- **THEN** the system SHALL classify it as a service (default to more thorough analysis)

### Requirement: Present detected topology before proceeding
The system SHALL present the detected monorepo topology to the user before proceeding with per-service analysis.

#### Scenario: Topology presentation
- **WHEN** monorepo structure is detected
- **THEN** the system SHALL display: "Found N services + M libraries:" followed by a list with names, detected stack, and classification, then proceed with full per-service analysis

#### Scenario: User correction
- **WHEN** the user indicates a misclassification (e.g., "that's not a service, it's an example project")
- **THEN** the system SHALL adjust the classification and exclude it from service analysis
