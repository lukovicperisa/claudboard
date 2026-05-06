## ADDED Requirements

### Requirement: Detect workspace directory as analysis entry point
The system SHALL detect workspace mode when the CWD contains no build file but contains subdirectories that each have both a build file AND an independent `.git/` directory.

The `.git/` presence in each subdir is the discriminator between workspace mode (multi-repo) and monorepo mode (shared `.git/` at root).

#### Scenario: Workspace with multiple independent repos
- **WHEN** `/analyse` is run from `/workspace/` AND `/workspace/order-service/` has `build.gradle` + `.git/` AND `/workspace/user-service/` has `pom.xml` + `.git/`
- **THEN** the system SHALL enter workspace mode and treat each subdir as an independent repo

#### Scenario: Monorepo root (no .git/ in subdirs)
- **WHEN** `/analyse` is run from a directory with no build file AND subdirs have build files but NO `.git/`
- **THEN** the system SHALL enter monorepo mode (existing behaviour, unchanged)

#### Scenario: Mixed subdirs (some with .git/, some without)
- **WHEN** some subdirs have `.git/` and some do not
- **THEN** subdirs with `.git/` SHALL be treated as independent repos; subdirs without SHALL be treated as shared libraries or infra directories and excluded from the service list

#### Scenario: No build files found anywhere
- **WHEN** CWD has no build file AND no subdirs have build files
- **THEN** the system SHALL report: "No projects found at [path]. Check the path and try again." and stop.

### Requirement: Classify workspace repos as service or library
Each detected repo in workspace mode SHALL be classified as service or library using the same signals as monorepo service classification (see stack-detectors.md → "Monorepo Detection & Service Classification").

#### Scenario: Workspace repo classified as service
- **WHEN** a repo subdir has a `Dockerfile` or main entry point (`@SpringBootApplication`, `public static void main`, etc.)
- **THEN** it SHALL be classified as a service and included in the per-repo analysis loop

#### Scenario: Workspace repo classified as library
- **WHEN** a repo subdir has publish tasks and no main entry point and no Dockerfile
- **THEN** it SHALL be classified as a library, excluded from per-service analysis, and noted in the ecosystem context of repos that depend on it

### Requirement: Present workspace topology before analysis
After classification, the system SHALL present the detected topology and wait for user confirmation before running per-repo analysis.

#### Scenario: Topology presented
- **WHEN** workspace mode is detected and repos are classified
- **THEN** the system SHALL display: "Found N repos: [list of services with stacks] + [list of libraries]. Running full analysis of each service."

#### Scenario: User corrects misclassification
- **WHEN** the user indicates a directory is misclassified
- **THEN** the system SHALL adjust the classification before proceeding
