## ADDED Requirements

### Requirement: Endpoint counting in wide scan
The scanner SHALL count all REST endpoints by grepping `@GetMapping`, `@PostMapping`, `@PutMapping`, `@DeleteMapping`, `@PatchMapping`, `@RequestMapping` in production source during Phase 1c.

#### Scenario: Endpoints tallied
- **WHEN** scanner runs wide scan on a Spring Boot project
- **THEN** report includes total endpoint count and breakdown by HTTP method

### Requirement: API versioning detection
The scanner SHALL detect API versioning strategy by checking URL patterns in `@RequestMapping` values.

#### Scenario: URL-based versioning found
- **WHEN** `@RequestMapping` values contain `/v1/`, `/v2/`, or similar version segments
- **THEN** report records "URL-based API versioning" with version numbers found

#### Scenario: No versioning detected
- **WHEN** no version patterns found in endpoint URLs
- **THEN** report records "No API versioning detected" as INFO

### Requirement: OpenAPI/Swagger detection
The scanner SHALL check dependencies for `springdoc-openapi`, `springfox`, or `swagger` to detect API documentation tooling.

#### Scenario: OpenAPI dependency found
- **WHEN** `springdoc-openapi` or `springfox` appears in build dependencies
- **THEN** report records "OpenAPI documentation: present" and checks for `openapi.yaml`/`swagger.json` in resources

#### Scenario: No API documentation tooling
- **WHEN** REST endpoints exist but no OpenAPI/Swagger dependency found
- **THEN** report flags "No API documentation tooling" as INFO

### Requirement: API surface in report
The scanner SHALL include an "API Surface" subsection in Phase 2 report showing: controller count, total endpoints, versioning strategy, documentation tooling.

#### Scenario: Report includes API surface
- **WHEN** Phase 2 report is generated for a project with REST controllers
- **THEN** report contains API Surface section with all detected metrics
