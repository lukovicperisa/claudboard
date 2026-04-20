## ADDED Requirements

### Requirement: Security grep patterns in wide scan
The scanner SHALL grep for security-related annotations and configurations during Phase 1c wide scan: `SecurityFilterChain`, `@PreAuthorize`, `@Secured`, `@EnableMethodSecurity`, `OncePerRequestFilter`, `CorsConfigurationSource`, `@CrossOrigin`, `@Authorize` (custom annotations detected in 1c).

#### Scenario: Spring Security detected
- **WHEN** scanner finds `SecurityFilterChain` or `@EnableMethodSecurity` in production source
- **THEN** report records security framework as "Spring Security" with file locations

#### Scenario: Custom auth annotation detected
- **WHEN** scanner finds custom `@interface` annotations used on controller methods that contain "auth" or "authorize" in the name
- **THEN** report records custom auth pattern with annotation name, usage count, and aspect class if `@Aspect` is co-located

#### Scenario: No security framework detected
- **WHEN** scanner finds zero security-related patterns in production source
- **THEN** report flags "No security framework detected" as HIGH severity in Watch section

### Requirement: Security quality dimension in scoring
The scanner SHALL add a "Security" dimension to the quality scoring table with levels: Enforced (framework + method-level auth), Basic (framework present, no method-level), Missing (no security framework).

#### Scenario: Enforced security scoring
- **WHEN** both `SecurityFilterChain` and `@PreAuthorize`/`@Secured`/custom auth annotations are found
- **THEN** Security dimension scores "Enforced"

#### Scenario: Basic security scoring
- **WHEN** `SecurityFilterChain` found but no method-level auth annotations
- **THEN** Security dimension scores "Basic"

### Requirement: Auth coverage gap detection
The scanner SHALL compare controller endpoints against auth-annotated endpoints to detect unprotected routes.

#### Scenario: Unprotected endpoints found
- **WHEN** scanner finds `@RestController` endpoints without corresponding `@PreAuthorize`, `@Secured`, or custom auth annotation
- **THEN** report lists unprotected endpoint count and sample file locations in Watch section as MEDIUM severity

### Requirement: CORS configuration detection
The scanner SHALL detect CORS configuration via `CorsConfigurationSource`, `@CrossOrigin`, or `WebMvcConfigurer` cors methods.

#### Scenario: CORS configured
- **WHEN** CORS configuration class or annotation found
- **THEN** report records CORS as "configured" in security section

#### Scenario: No CORS and REST endpoints exist
- **WHEN** no CORS config found AND `@RestController` endpoints exist
- **THEN** report flags "No CORS configuration — verify if needed" as INFO
