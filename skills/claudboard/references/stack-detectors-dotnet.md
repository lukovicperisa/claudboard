# Stack Detectors: .NET / C#

This file provides .NET/C# specific detection heuristics and grep patterns for claudboard analysis.

---

## Detection Heuristics

| File | What to extract |
|------|----------------|
| `*.csproj` | `<TargetFramework>`, `<PackageReference>` items |
| `*.sln` | Solution file → multi-project |
| `global.json` | SDK version pinned |
| `NuGet.config` | Private feeds |

**Framework detection from `PackageReference`:**
- `Microsoft.AspNetCore.*` → ASP.NET Core (Web API / MVC)
- `Microsoft.EntityFrameworkCore.*` → EF Core (ORM)
- `Dapper` → Dapper (micro-ORM)
- `MediatR` → MediatR (CQRS mediator pattern)
- `AutoMapper` → AutoMapper (object mapping)
- `Swashbuckle.AspNetCore` → Swagger/OpenAPI docs
- `NSwag.*` → NSwag (OpenAPI tooling)
- `Serilog.*` → Serilog (structured logging)
- `Microsoft.Extensions.Logging` → Microsoft logging abstractions
- `xunit` → xUnit test framework
- `NUnit` → NUnit test framework
- `Moq` → Moq (mocking)
- `FluentAssertions` → FluentAssertions (assertion library)
- `FluentValidation` → FluentValidation (validation rules)
- `Polly` → Polly (resilience/retry policies)
- `MassTransit` / `NServiceBus` → Message bus frameworks
- `StackExchange.Redis` → Redis client
- `Microsoft.ApplicationInsights` → Application Insights (Azure)
- `OpenTelemetry.*` → OpenTelemetry

**Architecture detection from directory names** (look inside `src/**`):
- `Domain/`, `Application/`, `Infrastructure/`, `Presentation/` → Clean Architecture
- `Controllers/`, `Services/`, `Repositories/` → Classic Layered
- `Aggregates/`, `Commands/`, `Queries/` → DDD / CQRS
- `Core/`, `Features/` → Vertical Slice Architecture
- `Api/`, `Contracts/`, `Persistence/` → Explicit separation of concerns

**Multi-project signals:**
- `*.sln` with multiple `Project()` entries → Solution with multiple projects
- Multiple `*.csproj` at different depths → Multi-project solution
- Shared library in `Common/` or `Shared/` or `Core/` dir

---

## Wide Scan Grep Patterns

Run during Phase 1 step 1c. All greps exclude build output dirs (`bin/`, `obj/`, `packages/`). Run in parallel.

### Custom patterns (inheritance & attributes)

```powershell
# Interface declarations
grep -rn '^public interface\|^interface ' --include='*.cs' src/

# Abstract base classes
grep -rn '^public abstract class\|^abstract class' --include='*.cs' src/

# Inheritance usage (exclude comments and tests)
grep -rn ' : ' --include='*.cs' src/ | grep -v '//' | grep -v 'class.*object'

# Generic constraints
grep -rn 'where T :' --include='*.cs' src/

# Custom attribute declarations
grep -rn '\[AttributeUsage\|class.*Attribute' --include='*.cs' src/

# Attribute usage on classes/methods
grep -rn '^\s*\[' --include='*.cs' src/ | head -50
```

### Anti-pattern signals

```bash
# God class candidates (files >500 LOC in main source)
find . -name '*.cs' -path '*/src/*' ! -path '*/bin/*' ! -path '*/obj/*' ! -path '*Test*' \
  | xargs wc -l 2>/dev/null | sort -rn | head -20

# Property injection count (anti-pattern, should use constructor)
grep -rc '\[Inject\]\|public.*{ get; set; }.*= null!' --include='*.cs' src/ | awk -F: '{s+=$2}END{print s}'

# Constructor injection indicator (good practice)
grep -rc 'private readonly' --include='*.cs' src/ | awk -F: '{s+=$2}END{print s}'

# Broad exception catching
grep -rn 'catch (Exception\|catch (System.Exception' --include='*.cs' src/ | grep -v '//'

# Null returns (pre-nullable reference types era)
grep -rn 'return null;' --include='*.cs' src/

# async void (should be async Task)
grep -rn 'async void ' --include='*.cs' src/ | grep -v 'EventHandler'

# ServiceLocator anti-pattern
grep -rn 'ServiceLocator\|IServiceProvider.*GetService\|container.Resolve' --include='*.cs' src/

# Reflection in business logic
grep -rn 'GetType()\|typeof(.*).GetMethods\|Activator.CreateInstance\|MethodInfo\.Invoke' \
  --include='*.cs' src/ | grep -v '//'

# Console logging (production code only)
grep -rn 'Console\.WriteLine\|Console\.Write[^L]' --include='*.cs' src/ \
  --exclude-dir=Test --exclude-dir=Tests

# Magic strings/numbers
grep -rn 'throw new.*Exception("' --include='*.cs' src/ | wc -l

# ConfigureAwait(false) missing (library context signal)
grep -rn '\.Result\|\.Wait(' --include='*.cs' src/ | grep -v 'Test'

# TODO/FIXME/HACK count
grep -rc 'TODO\|FIXME\|HACK' --include='*.cs' src/ | grep -v ':0$'
```

### Convention frequency

```bash
# Naming: PascalCase for public members (count violations)
grep -rn 'public.*[a-z][a-zA-Z]*(' --include='*.cs' src/ | grep -v ' I[A-Z]' | head -10

# .editorconfig presence
test -f .editorconfig && echo ".editorconfig present" || echo "No .editorconfig"

# StyleCop / FxCop / Roslyn analyzers configured
grep -rn 'StyleCop\|FxCop\|Microsoft\.CodeAnalysis\|AnalysisMode' --include='*.csproj' src/

# Global usings (C# 10+)
find . -name 'GlobalUsings.cs' -o -name 'Usings.cs' 2>/dev/null

# File-scoped namespaces (C# 10+) vs block-scoped
FILE_SCOPED=$(grep -rc '^namespace ' --include='*.cs' src/ | grep -v ':0$' | wc -l)
BLOCK_SCOPED=$(grep -rc '^namespace.*{' --include='*.cs' src/ | grep -v ':0$' | wc -l)
# Report: "File-scoped: N files, Block-scoped: M files"

# Dependency injection pattern (constructor-based)
grep -rn 'public.*Constructor.*(' --include='*.cs' src/ | wc -l
```

### Security posture signals

```bash
# ASP.NET Core authentication/authorization
grep -rl '\[Authorize\]\|AddAuthentication\|AddJwtBearer\|AddIdentity' \
  --include='*.cs' src/

# Identity framework
grep -rl 'UserManager\|SignInManager\|IdentityUser\|IdentityDbContext' \
  --include='*.cs' src/

# Custom authorization attributes
grep -rn 'class.*Attribute.*IAuthorizationFilter\|\[AttributeUsage.*Authorization' \
  --include='*.cs' src/

# CORS configuration
grep -rl 'AddCors\|UseCors\|WithOrigins' --include='*.cs' src/

# Authentication schemes detection
grep -rn 'AddJwtBearer\|AddCookie\|AddOAuth\|AddOpenIdConnect' \
  --include='*.cs' src/

# Endpoint count vs auth-annotated endpoint count (coverage gap detection)
TOTAL_ENDPOINTS=$(grep -rc '\[HttpGet\]\|\[HttpPost\]\|\[HttpPut\]\|\[HttpDelete\]\|\[HttpPatch\]' \
  --include='*.cs' src/ | awk -F: '{s+=$2}END{print s}')
AUTH_ENDPOINTS=$(grep -rc '\[Authorize\]' --include='*.cs' src/ | awk -F: '{s+=$2}END{print s}')
# If AUTH_ENDPOINTS < TOTAL_ENDPOINTS: flag potential unprotected routes

# Data protection / encryption
grep -rl 'IDataProtector\|AddDataProtection\|Protect\|Unprotect' \
  --include='*.cs' src/

# Secrets management
grep -rn 'AddAzureKeyVault\|ISecretClient\|AddUserSecrets' \
  --include='*.cs' src/
```

### API surface signals

```bash
# Endpoint tally by HTTP method
GET_COUNT=$(grep -rc '\[HttpGet' --include='*.cs' src/ | awk -F: '{s+=$2}END{print s}')
POST_COUNT=$(grep -rc '\[HttpPost' --include='*.cs' src/ | awk -F: '{s+=$2}END{print s}')
PUT_COUNT=$(grep -rc '\[HttpPut' --include='*.cs' src/ | awk -F: '{s+=$2}END{print s}')
DELETE_COUNT=$(grep -rc '\[HttpDelete' --include='*.cs' src/ | awk -F: '{s+=$2}END{print s}')
PATCH_COUNT=$(grep -rc '\[HttpPatch' --include='*.cs' src/ | awk -F: '{s+=$2}END{print s}')
# Report: "GET:N POST:M PUT:P DELETE:Q PATCH:R  total: N+M+P+Q+R endpoints"

# Controller count
find . -name '*Controller.cs' ! -path '*/bin/*' ! -path '*/obj/*' | wc -l

# API versioning detection
grep -rn 'ApiVersion\|\[MapToApiVersion\]\|api/v[0-9]' --include='*.cs' src/ | head -10

# Minimal API detection (ASP.NET Core 6+)
grep -rn 'MapGet\|MapPost\|MapPut\|MapDelete' --include='*.cs' src/ | wc -l

# Swagger/OpenAPI configuration
grep -rl 'AddSwaggerGen\|SwaggerDoc\|EnableAnnotations' --include='*.cs' src/

# GraphQL detection
grep -rl 'HotChocolate\|GraphQL\|AddGraphQLServer' --include='*.cs' src/

# gRPC detection
grep -rl 'Grpc\|\.proto\|AddGrpc' --include='*.cs' --include='*.proto' src/
```

### Observability signals

```bash
# ILogger usage
grep -rc 'ILogger<\|ILoggerFactory' --include='*.cs' src/ | awk -F: '{s+=$2}END{print s}'

# Serilog structured logging
grep -r 'Serilog\|UseSerilog\|WriteTo\.' --include='*.cs' --include='*.csproj' src/ | wc -l

# Application Insights
grep -r 'ApplicationInsights\|TelemetryClient\|AddApplicationInsightsTelemetry' \
  --include='*.cs' --include='*.csproj' src/ | head -5

# OpenTelemetry
grep -r 'OpenTelemetry\|AddOpenTelemetry\|TracerProvider' \
  --include='*.cs' --include='*.csproj' src/ | head -5

# Health checks
grep -rl 'AddHealthChecks\|IHealthCheck\|HealthCheckResult' --include='*.cs' src/

# Metrics / diagnostics
grep -rn 'DiagnosticSource\|ActivitySource\|Meter\|Counter<\|Histogram<' \
  --include='*.cs' src/ | wc -l

# Exception handling middleware
grep -rn 'UseExceptionHandler\|IExceptionHandler\|ExceptionHandlerMiddleware' \
  --include='*.cs' src/
```

### Dependency deep-scan signals

```bash
# NuGet package restore check
test -f packages.config && echo "Legacy packages.config detected" || echo "PackageReference style"

# Central Package Management (CPM)
test -f Directory.Packages.props && echo "Central Package Management enabled" || echo "No CPM"

# Package version analysis (requires NuGet CLI or dotnet list package)
# Check for outdated packages
dotnet list package --outdated 2>/dev/null | head -20

# Vulnerable packages
dotnet list package --vulnerable 2>/dev/null | head -20

# Deprecated packages
dotnet list package --deprecated 2>/dev/null | head -20

# Cross-project version mismatch (multi-project solution)
grep -rn '<PackageReference' --include='*.csproj' . | grep -v '/bin/\|/obj/' \
  | awk -F'Include="' '{print $2}' | awk -F'"' '{print $1}' | sort | uniq -c | sort -rn | head -20

# Target framework mismatch
grep -rn '<TargetFramework>' --include='*.csproj' . | grep -v '/bin/\|/obj/'

# Implicit usings enabled
grep -rn '<ImplicitUsings>enable' --include='*.csproj' . | wc -l

# Nullable reference types enabled
grep -rn '<Nullable>enable' --include='*.csproj' . | wc -l

# SDK style vs legacy project format
grep -rc '<Project Sdk=' --include='*.csproj' . | grep -v ':0$' | wc -l  # SDK-style
grep -rc '<Project ToolsVersion=' --include='*.csproj' . | grep -v ':0$' | wc -l  # Legacy

# Global.json SDK pinning
test -f global.json && cat global.json | grep -oP '"version"\s*:\s*"\K[^"]+' || echo "No global.json"
```

---

## Notes

- **PowerShell compatibility**: All grep patterns work in bash. For PowerShell-native alternatives, use `Select-String` cmdlet.
- **Directory exclusions**: Always exclude `bin/`, `obj/`, `packages/`, `.vs/` for performance.
- **Modern C# features**: Detection of file-scoped namespaces, global usings, nullable reference types, minimal APIs signals modern codebase (C# 10+).
- **Architecture patterns**: Strong interface + implementation separation → clean architecture or hexagonal. `MediatR` + `Commands/Queries/` → CQRS. `Features/` → vertical slice.
