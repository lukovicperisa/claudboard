# Stack Detectors: Go

## Detection Heuristics

| File | What to extract |
|------|----------------|
| `go.mod` | Module name, Go version, `require` block (key dependencies) |
| `go.sum` | Lockfile present |
| `Makefile` | Build/test/lint commands |

**Framework detection from `go.mod`:**
- `github.com/gin-gonic/gin` → Gin HTTP framework
- `github.com/labstack/echo` → Echo HTTP framework
- `google.golang.org/grpc` → gRPC
- `github.com/stretchr/testify` → Testify (testing)

**Architecture detection:**
- `cmd/` → Multi-binary project (Clean Architecture signal)
- `internal/` → Private packages (idiomatic Go)
- `pkg/` → Shared packages

---

## Wide Scan Grep Patterns

### Custom patterns

**Interface detection:**
```bash
# Interface declarations
grep -rn '^type .* interface {' --include='*.go' . | grep -v vendor | grep -v _test.go

# Interface satisfaction (implicit implementation)
grep -rn '// .*implements ' --include='*.go' . | grep -v vendor
grep -rn 'var _ .* = ' --include='*.go' . | grep -v vendor | grep -v _test.go  # compile-time interface checks
```

**Struct embedding:**
```bash
# Embedded structs (composition over inheritance)
grep -rn '^type .* struct {' -A 10 --include='*.go' . \
  | grep -v vendor | grep '^\s*[A-Z]' | grep -v '\s*[A-Z][a-z]* ' | head -20

# Embedded interfaces
grep -rn 'type .* struct {' -A 5 --include='*.go' . \
  | grep -v vendor | grep '^\s*[A-Z].*\s*$' | head -10
```

**Method definitions:**
```bash
# Receiver methods
grep -rn '^func ([a-z]' --include='*.go' . | grep -v vendor | grep -v _test.go | wc -l

# Pointer vs value receivers (design signal)
POINTER_RECV=$(grep -rc '^func (\*' --include='*.go' . | grep -v vendor | awk -F: '{s+=$2}END{print s}')
VALUE_RECV=$(grep -rc '^func ([a-z][a-z]* [A-Z]' --include='*.go' . | grep -v vendor | awk -F: '{s+=$2}END{print s}')
# Report: "Pointer receivers: N, Value receivers: M"
```

---

### Anti-pattern signals

**God struct (files >500 lines):**
```bash
# Large source files (exclude tests)
find . -name '*.go' ! -name '*_test.go' ! -path '*/vendor/*' \
  | xargs wc -l 2>/dev/null | sort -rn | head -20

# Structs with many fields (>15 fields)
grep -rn '^type .* struct {' -A 20 --include='*.go' . \
  | grep -v vendor | grep -v _test.go | grep -B 1 -c '^\s*[A-Z]' | grep -v ':0$' | head -10
```

**Broad error swallowing:**
```bash
# Ignored errors (_ = err)
grep -rn '_ = err\|_ := .*\..*(' --include='*.go' . | grep -v vendor | grep -v _test.go | wc -l

# Error.Error() string comparison (anti-pattern)
grep -rn 'err\.Error() ==' --include='*.go' . | grep -v vendor

# Panic in production code (non-main)
grep -rn '\bpanic(' --include='*.go' . | grep -v vendor | grep -v _test.go | grep -v '/main.go'
```

**Global state:**
```bash
# Package-level vars (mutable global state)
grep -rn '^var [a-z]' --include='*.go' . | grep -v vendor | grep -v _test.go | wc -l

# Global var declarations with assignment
grep -rn '^var .* = ' --include='*.go' . | grep -v vendor | grep -v _test.go | head -10

# Global sync.Mutex / sync.RWMutex (potential concurrency smell)
grep -rn '^var .* sync\.\(RW\)\?Mutex' --include='*.go' . | grep -v vendor
```

**init() abuse:**
```bash
# init() function count (complex init is a smell)
grep -rc '^func init()' --include='*.go' . | grep -v vendor | grep -v ':0$'

# init() with side effects (network/file I/O)
grep -rn '^func init()' -A 10 --include='*.go' . \
  | grep -v vendor | grep -E 'http\.|os\.Open\|ioutil\.|filepath\.'
```

**Other anti-patterns:**
```bash
# TODO/FIXME/HACK count
grep -rc 'TODO\|FIXME\|HACK' --include='*.go' . | grep -v vendor | grep -v ':0$'

# Context.Background() in handlers (should accept context from caller)
grep -rn 'context\.Background()' --include='*.go' . | grep -v vendor | grep -v _test.go | wc -l

# time.Sleep in production (tight loop anti-pattern)
grep -rn 'time\.Sleep' --include='*.go' . | grep -v vendor | grep -v _test.go
```

---

### Convention frequency

**gofmt usage:**
```bash
# Check if code is gofmt'd (no output = clean)
gofmt -l . 2>/dev/null | grep -v vendor | wc -l
# 0 = all files formatted, >0 = unformatted files exist
```

**golangci-lint config:**
```bash
# golangci-lint configuration
ls -la .golangci.yml .golangci.yaml 2>/dev/null

# Enabled linters (if config exists)
grep -A 50 'linters:' .golangci.y*ml 2>/dev/null | grep 'enable:\|disable:' | head -20
```

**Naming conventions:**
```bash
# Exported vs unexported capitalization adherence
# Exported functions (capital first letter)
grep -rc '^func [A-Z]' --include='*.go' . | grep -v vendor | awk -F: '{s+=$2}END{print s}'

# Unexported functions (lowercase first letter)
grep -rc '^func [a-z]' --include='*.go' . | grep -v vendor | grep -v _test.go | awk -F: '{s+=$2}END{print s}'

# CamelCase vs snake_case identifiers (snake_case is non-idiomatic)
grep -rn '\b[a-z]*_[a-z]*\b' --include='*.go' . | grep -v vendor | grep -v _test.go | wc -l
```

**Error handling style:**
```bash
# errors.Is / errors.As usage (modern error handling)
grep -rc 'errors\.Is\|errors\.As' --include='*.go' . | grep -v vendor | awk -F: '{s+=$2}END{print s}'

# fmt.Errorf with %w (wrapped errors)
grep -rc 'fmt\.Errorf.*%w' --include='*.go' . | grep -v vendor | awk -F: '{s+=$2}END{print s}'

# Custom error types
grep -rn '^type .* struct.*error\|^type .*Error struct' --include='*.go' . | grep -v vendor | wc -l

# errors.New usage
grep -rc 'errors\.New' --include='*.go' . | grep -v vendor | awk -F: '{s+=$2}END{print s}'
```

**Test naming:**
```bash
# Test file naming (_test.go convention)
find . -name '*_test.go' ! -path '*/vendor/*' | wc -l

# Table-driven tests (t.Run pattern)
grep -rc 't\.Run(' --include='*_test.go' . | grep -v vendor | awk -F: '{s+=$2}END{print s}'

# Testify suite usage
grep -rc 'suite\.Suite' --include='*_test.go' . | grep -v vendor | awk -F: '{s+=$2}END{print s}'
```

---

### Security posture signals

**Auth middleware:**
```bash
# Gin middleware
grep -rn 'gin\.HandlerFunc\|c\.Next()\|c\.Abort' --include='*.go' . \
  | grep -v vendor | grep -i 'auth\|token\|jwt' | wc -l

# Echo middleware
grep -rn 'echo\.MiddlewareFunc\|next(c)\|echo\.NewHTTPError' --include='*.go' . \
  | grep -v vendor | grep -i 'auth\|token\|jwt' | wc -l

# Chi middleware
grep -rn 'func.*http\.Handler.*http\.Handler\|r\.Use(' --include='*.go' . \
  | grep -v vendor | grep -i 'auth\|jwt' | wc -l

# Custom auth middleware detection
grep -rn 'Authorization.*header\|Bearer.*token' --include='*.go' . | grep -v vendor | wc -l
```

**JWT handling:**
```bash
# JWT library usage (go.mod check)
grep 'jwt' go.mod 2>/dev/null

# JWT token validation in code
grep -rn 'jwt\.Parse\|jwt\.Verify\|ValidateToken' --include='*.go' . | grep -v vendor | wc -l

# JWT signing
grep -rn 'jwt\.Sign\|jwt\.New\|NewWithClaims' --include='*.go' . | grep -v vendor | wc -l
```

**CORS middleware:**
```bash
# CORS configuration
grep -rn 'CORS\|AllowOrigins\|AllowMethods\|AllowHeaders' --include='*.go' . | grep -v vendor

# Gin CORS
grep -rn 'gin\.CORS\|cors\.Default\|cors\.New' --include='*.go' . | grep -v vendor

# Echo CORS
grep -rn 'middleware\.CORS' --include='*.go' . | grep -v vendor
```

**TLS config:**
```bash
# TLS configuration
grep -rn 'tls\.Config\|TLSConfig\|InsecureSkipVerify' --include='*.go' . | grep -v vendor

# Certificate handling
grep -rn 'x509\.Certificate\|tls\.LoadX509KeyPair\|CertFile\|KeyFile' --include='*.go' . \
  | grep -v vendor | wc -l

# Insecure TLS (anti-pattern)
grep -rn 'InsecureSkipVerify.*true' --include='*.go' . | grep -v vendor
```

---

### API surface signals

**Handler count:**
```bash
# Gin handlers
GIN_GET=$(grep -rc '\.GET(\|router\.GET' --include='*.go' . | grep -v vendor | awk -F: '{s+=$2}END{print s}')
GIN_POST=$(grep -rc '\.POST(\|router\.POST' --include='*.go' . | grep -v vendor | awk -F: '{s+=$2}END{print s}')
GIN_PUT=$(grep -rc '\.PUT(\|router\.PUT' --include='*.go' . | grep -v vendor | awk -F: '{s+=$2}END{print s}')
GIN_DELETE=$(grep -rc '\.DELETE(\|router\.DELETE' --include='*.go' . | grep -v vendor | awk -F: '{s+=$2}END{print s}')
# Report: "Gin endpoints: GET:N POST:M PUT:P DELETE:Q"

# http.HandleFunc (stdlib)
grep -rc 'http\.HandleFunc\|http\.Handle' --include='*.go' . | grep -v vendor | awk -F: '{s+=$2}END{print s}'

# Echo handlers
grep -rc 'e\.GET\|e\.POST\|e\.PUT\|e\.DELETE' --include='*.go' . | grep -v vendor | awk -F: '{s+=$2}END{print s}'

# Chi routes
grep -rc 'r\.Get\|r\.Post\|r\.Put\|r\.Delete' --include='*.go' . | grep -v vendor | awk -F: '{s+=$2}END{print s}'
```

**Router groups:**
```bash
# Gin groups
grep -rn '\.Group(' --include='*.go' . | grep -v vendor | wc -l

# Echo groups
grep -rn 'e\.Group\|Group(' --include='*.go' . | grep -v vendor | wc -l

# Chi sub-routers
grep -rn 'r\.Route\|chi\.NewRouter' --include='*.go' . | grep -v vendor | wc -l
```

**Middleware chain:**
```bash
# Middleware registration
grep -rn '\.Use(\|Use(middleware\|router\.Use' --include='*.go' . | grep -v vendor | wc -l

# Recovery middleware (panic recovery)
grep -rn 'gin\.Recovery\|middleware\.Recover\|Recovery()' --include='*.go' . | grep -v vendor

# Logger middleware
grep -rn 'gin\.Logger\|middleware\.Logger\|Logger()' --include='*.go' . | grep -v vendor
```

**OpenAPI (swaggo):**
```bash
# Swag annotations
grep -rc '// @' --include='*.go' . | grep -v vendor | awk -F: '{s+=$2}END{print s}'

# swaggo dependency
grep 'swaggo\|swagger' go.mod 2>/dev/null

# Generated swagger docs
ls -la docs/swagger.json docs/swagger.yaml 2>/dev/null
```

---

### Observability signals

**Go kit metrics:**
```bash
# go-kit dependency
grep 'go-kit' go.mod 2>/dev/null

# go-kit metrics usage
grep -rn 'metrics\.\(Counter\|Gauge\|Histogram\)\|kitprometheus' --include='*.go' . \
  | grep -v vendor | wc -l
```

**Prometheus client_golang:**
```bash
# Prometheus dependency
grep 'prometheus/client_golang' go.mod 2>/dev/null

# Prometheus metrics registration
grep -rn 'prometheus\.NewCounter\|prometheus\.NewGauge\|prometheus\.NewHistogram\|prometheus\.NewSummary' \
  --include='*.go' . | grep -v vendor | wc -l

# Prometheus HTTP handler
grep -rn 'promhttp\.Handler\|prometheus\.Handler' --include='*.go' . | grep -v vendor

# Custom metrics
grep -rn 'promauto\.New\|prometheus\.Register\|MustRegister' --include='*.go' . | grep -v vendor | wc -l
```

**OpenTelemetry:**
```bash
# OpenTelemetry dependency
grep 'go.opentelemetry.io' go.mod 2>/dev/null

# Tracer initialization
grep -rn 'otel\.Tracer\|trace\.NewTracerProvider\|sdktrace' --include='*.go' . \
  | grep -v vendor | wc -l

# Span creation
grep -rn 'StartSpan\|ctx, span :=\|defer span\.End()' --include='*.go' . | grep -v vendor | wc -l

# Metrics provider
grep -rn 'metric\.NewMeterProvider\|otel\.GetMeterProvider' --include='*.go' . | grep -v vendor
```

**zap/zerolog structured logging:**
```bash
# zap dependency
grep 'go.uber.org/zap' go.mod 2>/dev/null

# zap logger usage
grep -rn 'zap\.New\|zap\.Logger\|logger\.Info\|logger\.Error\|logger\.Warn' --include='*.go' . \
  | grep -v vendor | wc -l

# zerolog dependency
grep 'github.com/rs/zerolog' go.mod 2>/dev/null

# zerolog usage
grep -rn 'zerolog\.New\|log\.Info()\|log\.Error()\|log\.Warn()' --include='*.go' . \
  | grep -v vendor | wc -l

# Structured fields
grep -rn 'zap\.String\|zap\.Int\|zap\.Any\|\.Str(\|\.Int(\|\.Bool(' --include='*.go' . \
  | grep -v vendor | wc -l
```

---

### Dependency deep-scan signals

**go.sum presence:**
```bash
# go.sum exists (lockfile for reproducible builds)
ls -la go.sum 2>/dev/null && echo "Lockfile present" || echo "WARNING: No go.sum lockfile"

# go.sum entry count
wc -l go.sum 2>/dev/null
```

**govulncheck:**
```bash
# govulncheck in CI
grep -r 'govulncheck\|go run golang.org/x/vuln' .github/workflows/*.yml azure-pipelines.yml Makefile 2>/dev/null

# Vulnerability database usage
grep -r 'GOVULNDB\|vuln/cmd/govulncheck' . 2>/dev/null
```

**go mod tidy:**
```bash
# Check for unused dependencies (run go mod tidy in dry-run mode)
go mod tidy -v 2>&1 | grep -i 'unused\|removed' | wc -l

# Indirect dependencies count (possible bloat signal)
grep '// indirect' go.mod 2>/dev/null | wc -l
```

**replace directives:**
```bash
# replace directives (local dev vs production)
grep '^replace ' go.mod 2>/dev/null

# Local filesystem replace (dev-only pattern)
grep 'replace .* => \.\.' go.mod 2>/dev/null | wc -l

# Remote replace (fork or patched dependency)
grep 'replace .* => .*github\.com' go.mod 2>/dev/null | wc -l

# Report if >0 local replaces: "WARNING: N local replace directives — ensure production build removes these"
```
