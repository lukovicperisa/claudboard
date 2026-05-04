# Stack Detectors: Rust

## Detection Heuristics

| File | What to extract |
|------|----------------|
| `Cargo.toml` | `[package]`, `[dependencies]`, `[workspace]` (workspace members) |
| `Cargo.lock` | Lockfile |

---

## Wide Scan Grep Patterns

Run during Phase 1 step 1c. All greps exclude build output dirs (target/, dist/). Run in parallel.

### Custom patterns (traits, macros, generics)

```bash
# Trait implementations
grep -rn '^impl.*for ' --include='*.rs' src/

# Trait declarations
grep -rn '^pub trait\|^trait ' --include='*.rs' src/

# Derive macros usage
grep -rn '#\[derive(' --include='*.rs' src/ | wc -l

# Generic constraints (where clauses)
grep -rn '^\s*where ' --include='*.rs' src/ | wc -l

# Associated types
grep -rn 'type.*=.*;' --include='*.rs' src/ | grep -v '//' | head -20

# Lifetimes usage
grep -rn "<'[a-z]" --include='*.rs' src/ | wc -l
```

### Anti-pattern signals

```bash
# unwrap() in production code (panic risk)
grep -rn '\.unwrap()' --include='*.rs' src/main.rs src/lib.rs src/bin/ \
  | grep -v 'test\|#\[cfg(test)\]' | wc -l

# expect() without meaningful message
grep -rn '\.expect("")\|\.expect("TODO")\|\.expect("fix")' --include='*.rs' src/

# clone() overuse (potential performance debt)
CLONE_COUNT=$(grep -rc '\.clone()' --include='*.rs' src/ | awk -F: '{s+=$2}END{print s}')
# Flag if >50 per 1000 LOC

# unsafe blocks
grep -rn '^unsafe \|unsafe {' --include='*.rs' src/ | wc -l

# Box<dyn Any> type erasure (loses compile-time guarantees)
grep -rn 'Box<dyn Any>' --include='*.rs' src/

# Broad pattern matching (wildcard in critical paths)
grep -rn '_ =>' --include='*.rs' src/main.rs src/lib.rs | head -10

# Global mutable state
grep -rn 'static mut\|lazy_static!\|once_cell.*Lazy<Mutex' --include='*.rs' src/ | wc -l

# String allocations in hot paths (detect via .to_string() in loops)
grep -rn 'for .* in.*{' --include='*.rs' src/ -A 3 | grep '\.to_string()' | wc -l

# TODO/FIXME/HACK count
grep -rc 'TODO\|FIXME\|HACK' --include='*.rs' src/ | grep -v ':0$'
```

### Convention frequency

```bash
# Error handling style: thiserror vs anyhow
THISERROR_COUNT=$(grep -rl '#\[derive(.*Error.*)\]\|thiserror::Error' --include='*.rs' src/ | wc -l)
ANYHOW_COUNT=$(grep -rl 'anyhow::Result\|anyhow::Error' --include='*.rs' src/ | wc -l)
# Report: "thiserror (N files) vs anyhow (M files)"

# Clippy lint config presence
test -f clippy.toml && echo "clippy.toml found" || echo "No clippy.toml"
grep -c '\[lints\.clippy\]' Cargo.toml 2>/dev/null

# rustfmt config
test -f rustfmt.toml && echo "rustfmt.toml found" || echo "No rustfmt config"

# Module organization style (mod.rs vs module_name.rs)
MOD_RS_COUNT=$(find src/ -name 'mod.rs' | wc -l)
# If >5: "Classic mod.rs style", else "Modern module-name style"

# Naming conventions (snake_case enforcement)
grep -rn '[A-Z][a-z]*_[a-z]' --include='*.rs' src/ | grep 'fn \|let ' | wc -l
# If >0: flag naming violations

# Public API surface (pub items count)
grep -rc '^pub fn\|^pub struct\|^pub enum\|^pub trait' --include='*.rs' src/lib.rs src/*.rs \
  | awk -F: '{s+=$2}END{print s}'
```

### Security posture signals

```bash
# Web framework auth middleware detection
# Actix-web
grep -rn 'HttpAuthentication\|actix_web::middleware::.*auth\|from_fn.*auth' \
  --include='*.rs' src/

# Axum
grep -rn 'axum::middleware::from_fn.*auth\|tower::middleware.*auth' --include='*.rs' src/

# Rocket
grep -rn '#\[rocket::.*guard\]\|FromRequest' --include='*.rs' src/

# tower middleware usage (cross-framework)
grep -r 'tower-http\|tower::middleware' Cargo.toml 2>/dev/null
grep -rn 'ServiceBuilder.*layer' --include='*.rs' src/ | wc -l

# CORS configuration
grep -rn 'CorsLayer\|cors()\|AllowOrigin\|tower_http::cors' --include='*.rs' src/

# JWT/auth token handling
grep -r 'jsonwebtoken\|jwt' Cargo.toml 2>/dev/null
grep -rn 'decode::<.*Claims>\|TokenData' --include='*.rs' src/ | wc -l

# TLS/HTTPS enforcement
grep -rn 'rustls\|native-tls\|openssl' Cargo.toml 2>/dev/null
grep -rn 'TlsAcceptor\|rustls::ServerConfig' --include='*.rs' src/
```

### API surface signals

```bash
# Route count by HTTP method (framework-agnostic patterns)
# Actix-web
ACTIX_GET=$(grep -rc '#\[get(' --include='*.rs' src/ | awk -F: '{s+=$2}END{print s}')
ACTIX_POST=$(grep -rc '#\[post(' --include='*.rs' src/ | awk -F: '{s+=$2}END{print s}')

# Axum
AXUM_ROUTES=$(grep -rn '\.route(.*get\|\.route(.*post' --include='*.rs' src/ | wc -l)

# Rocket
ROCKET_ROUTES=$(grep -rc '#\[get\|#\[post\|#\[put\|#\[delete' --include='*.rs' src/ \
  | awk -F: '{s+=$2}END{print s}')

# Total endpoint estimate
# Report: "Actix: N+M, Axum: P, Rocket: Q → Total: N+M+P+Q endpoints"

# API versioning (path-based)
grep -rn '"/v[0-9]' --include='*.rs' src/ | grep -oP '/v\d+' | sort -u
# If versions found: "URL-based versioning detected: v1, v2..."

# OpenAPI documentation (utoipa crate)
grep -r 'utoipa' Cargo.toml 2>/dev/null
grep -rn '#\[utoipa::path\]\|OpenApi::new\|ToSchema' --include='*.rs' src/ | wc -l

# REST resource modeling (struct → JSON mapping)
grep -rn '#\[derive(.*Serialize.*)\]\|#\[serde(' --include='*.rs' src/ | wc -l
```

### Observability signals

```bash
# tracing crate instrumentation
grep -r 'tracing\|tracing-subscriber' Cargo.toml 2>/dev/null
grep -rn '#\[instrument\]\|tracing::info\|tracing::error\|tracing::span' \
  --include='*.rs' src/ | wc -l

# Structured logging with context
grep -rn 'info!(.*=.*,\|error!(.*=.*,' --include='*.rs' src/ | wc -l
# If >10: "Structured logging with key-value pairs"

# metrics crate
grep -r 'metrics\|metrics-exporter' Cargo.toml 2>/dev/null
grep -rn 'counter!\|histogram!\|gauge!' --include='*.rs' src/ | wc -l

# OpenTelemetry integration
grep -r 'opentelemetry\|tracing-opentelemetry' Cargo.toml 2>/dev/null
grep -rn 'global::set_tracer_provider\|opentelemetry::sdk' --include='*.rs' src/

# Prometheus metrics export
grep -r 'prometheus\|metrics-exporter-prometheus' Cargo.toml 2>/dev/null

# Health check endpoints
grep -rn '/health\|/ready\|/live' --include='*.rs' src/ | wc -l
```

### Dependency deep-scan signals

```bash
# Cargo.lock presence (production builds should have this)
test -f Cargo.lock && echo "Cargo.lock present" || echo "WARNING: No Cargo.lock"

# cargo-audit for vulnerability scanning
grep -rn 'cargo-audit\|cargo deny' .github/workflows/*.yml Cargo.toml 2>/dev/null

# Feature flags usage
grep -c '^\[features\]' Cargo.toml 2>/dev/null
grep -rn 'default-features = false' Cargo.toml | wc -l
# High usage of default-features=false → signals tight dependency control

# Workspace dependency management
grep -c '^\[workspace\.dependencies\]' Cargo.toml 2>/dev/null
# If >0: "Centralized workspace dependency management"

# Dependency version pinning
grep -c '= ".*"' Cargo.toml 2>/dev/null
# Compare vs caret versions (^) to gauge pinning strictness

# Build script complexity (build.rs presence)
find . -name 'build.rs' | wc -l
# If >0: flag for review — build scripts can introduce hidden deps/complexity

# Cross-compilation targets
grep -rn '\[target\.' Cargo.toml | wc -l
```

---
