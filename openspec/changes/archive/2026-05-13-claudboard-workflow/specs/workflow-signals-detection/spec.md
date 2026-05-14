## ADDED Requirements

### Requirement: Workflow Signals subsection in analysis report
The `claudboard-analyse` skill SHALL produce a "Workflow Signals" subsection in the analysis report. The subsection SHALL include the following signals: cross-service edges, shared libraries, auth perimeter classification, and ticket prefix.

#### Scenario: Workflow Signals subsection presence
- **WHEN** `claudboard-analyse` runs on any project
- **THEN** the generated report at `.claude/reports/claudboard-analysis.md` SHALL contain a "## Workflow Signals" section

#### Scenario: Subsection in monorepo per-service report
- **WHEN** `claudboard-analyse` runs in monorepo mode and produces per-service reports
- **THEN** each per-service report SHALL contain its own "## Workflow Signals" section scoped to that service

### Requirement: Cross-service edge inventory
The system SHALL detect outgoing cross-service edges and list each by edge type and (when resolvable) target service name. Detected edge types include: HTTP client (RestTemplate, WebClient, RestClient, axios, fetch, requests), Feign client, Kafka producer, gRPC client.

#### Scenario: Feign client detected
- **WHEN** the codebase contains a class annotated with `@FeignClient`
- **THEN** the cross-service edges list SHALL include `{ "type": "feign", "target": "<value of @FeignClient name attribute>" }`

#### Scenario: Spring RestClient call detected
- **WHEN** the codebase contains a `RestClient.builder()` or `RestTemplate` invocation with a base URL referencing another service
- **THEN** the cross-service edges list SHALL include `{ "type": "http", "target": "<extracted URL or 'unknown'>" }`

#### Scenario: Kafka producer detected
- **WHEN** the codebase contains a `KafkaTemplate` send call or `@SendTo` producer pattern
- **THEN** the cross-service edges list SHALL include `{ "type": "kafka", "target": "<topic name or 'unknown'>" }`

#### Scenario: No edges detected
- **WHEN** the project contains no detectable outgoing cross-service edges
- **THEN** the cross-service edges list SHALL be empty (`[]`) and the subsection SHALL still be present

### Requirement: Shared-library detection
The system SHALL detect shared libraries used by 2+ services and list each as `{ name, consumer_count }`. A shared library is identified by being a workspace-level dependency referenced from multiple service projects.

#### Scenario: Maven shared library
- **WHEN** workspace-mode analysis identifies a Maven artifact referenced as a dependency in 2+ service `pom.xml` files
- **THEN** the shared libraries list SHALL include `{ "name": "<artifactId>", "consumer_count": <count> }`

#### Scenario: NPM workspace shared package
- **WHEN** workspace-mode analysis identifies an internal package referenced in 2+ services' `package.json` `dependencies`
- **THEN** the shared libraries list SHALL include `{ "name": "<package name>", "consumer_count": <count> }`

#### Scenario: No shared libraries
- **WHEN** the project is single-repo or no shared libraries are detected
- **THEN** the shared libraries list SHALL be empty (`[]`)

### Requirement: Auth perimeter classification
The system SHALL classify the project's authentication perimeter style as one of: `gateway`, `in-service-jwt`, `none`, `unknown`.

#### Scenario: API gateway pattern
- **WHEN** the project (or workspace) contains a service classified as a gateway (e.g., a `controller`-named service with `@EnableGateway`, Spring Cloud Gateway routes, or Kong/Traefik configuration)
- **THEN** auth perimeter SHALL be `gateway`

#### Scenario: In-service JWT validation
- **WHEN** services contain JWT validation logic (e.g., `JwtDecoder` bean, `oauth2ResourceServer` configuration in Spring, FastAPI `OAuth2PasswordBearer`, Express JWT middleware) without an apparent gateway
- **THEN** auth perimeter SHALL be `in-service-jwt`

#### Scenario: No auth signals
- **WHEN** no auth-related code is detected
- **THEN** auth perimeter SHALL be `none`

#### Scenario: Ambiguous auth signals
- **WHEN** auth signals are present but cannot be confidently classified into one of the above
- **THEN** auth perimeter SHALL be `unknown`

### Requirement: Ticket prefix heuristic
The system SHALL inspect recent commit messages and branch names to detect a consistent ticket-prefix pattern. The result SHALL be a regex-extracted prefix string (e.g., `MEAS`, `PLAT`) or `null` if no consistent pattern is found.

#### Scenario: Consistent prefix in commits
- **WHEN** at least 50% of the last 50 commits have subject lines matching `^[A-Z]+-[0-9]+` and 80% of those use the same alphabetic prefix
- **THEN** ticket prefix SHALL be that alphabetic prefix string

#### Scenario: Consistent prefix in branch names
- **WHEN** commit messages do not yield a clear pattern but recent branch names (last 20) match `[a-z]+/([A-Z]+-[0-9]+)/.*` with consistent alphabetic prefix
- **THEN** ticket prefix SHALL be that alphabetic prefix string

#### Scenario: No clear pattern
- **WHEN** neither commit messages nor branch names yield a consistent prefix
- **THEN** ticket prefix SHALL be `null` and `claudboard-workflow` will prompt the user

### Requirement: Backward-compatible report schema
The "Workflow Signals" subsection SHALL be additive only. Reports generated before this change (without the subsection) SHALL still be valid input to `claudboard-generate` and other downstream skills. Consumers (notably `claudboard-workflow`) SHALL treat a missing subsection as "all signals unknown".

#### Scenario: Pre-existing analysis report
- **WHEN** `claudboard-workflow` reads an analysis report that lacks the "Workflow Signals" subsection
- **THEN** the system SHALL warn the user "Limited workflow signals available — capability blocks may default off; consider re-running /analyse to refresh." and continue with all signals defaulted to unknown / empty

#### Scenario: Existing consumer skills unaffected
- **WHEN** `claudboard-generate`, `claudboard-refresh`, or `claudboard-techdebt` reads a report with the new subsection
- **THEN** those skills SHALL ignore the subsection and behave as before
