## ADDED Requirements

### Requirement: BOM detection
The scanner SHALL detect Bill of Materials (BOM) usage by checking for `platform()` in Gradle dependencies or `<dependencyManagement>` with `<type>pom</type>` in Maven.

#### Scenario: BOM found in Gradle
- **WHEN** `build.gradle` contains `platform(` or `enforcedPlatform(` calls
- **THEN** report records "BOM: [artifact name]" under dependency health

#### Scenario: BOM found in Maven
- **WHEN** `pom.xml` has `<dependencyManagement>` section with BOM imports
- **THEN** report records BOM artifacts

#### Scenario: No BOM, many dependencies
- **WHEN** project has >20 dependencies and no BOM
- **THEN** report flags "No BOM — version alignment risk" as INFO

### Requirement: Dependency conflict detection
The scanner SHALL detect forced version resolutions by grepping for `force =`, `exclude group:`, `resolutionStrategy` in Gradle or `<exclusions>` in Maven.

#### Scenario: Forced versions found
- **WHEN** `resolutionStrategy` or `force =` found in build files
- **THEN** report records count and flags as INFO: "N forced dependency resolutions — review for compatibility"

### Requirement: SBOM presence check
The scanner SHALL check for SBOM generation by looking for `cyclonedx` or `spdx` plugins in build config or CI pipeline.

#### Scenario: SBOM generation configured
- **WHEN** CycloneDX or SPDX plugin found in build or CI
- **THEN** report records "SBOM: [format] generated in [build/CI]"

#### Scenario: No SBOM
- **WHEN** no SBOM tooling detected
- **THEN** report records "No SBOM generation" as INFO

### Requirement: Version mismatch detection across modules
The scanner SHALL compare dependency versions across modules in multi-module projects to detect mismatches.

#### Scenario: Version mismatch found
- **WHEN** same dependency appears in multiple modules at different versions (e.g., testcontainers 1.18.0 vs 1.21.2)
- **THEN** report flags each mismatch as MEDIUM severity with module locations
