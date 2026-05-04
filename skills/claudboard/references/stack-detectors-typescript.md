# Stack Detectors: TypeScript / JavaScript

## Detection Heuristics

Read these in parallel. Each file is a detection signal — the more that match, the more confident the stack identification.

### JavaScript / TypeScript / Node.js

| File | What to extract |
|------|----------------|
| `package.json` | `name`, `description`, `scripts` (build/test/lint/start/dev), `dependencies`, `devDependencies`, `workspaces` (npm workspace → monorepo), `type` (module vs commonjs) |
| `tsconfig.json` | `compilerOptions.target`, `compilerOptions.strict`, `paths` (aliases), `references` (project references → multi-package) |
| `tsconfig.*.json` | Multiple configs → separate build targets (e.g., src vs tests) |
| `.eslintrc.*` / `eslint.config.*` | Linting rules in use |
| `.prettierrc.*` | Code formatting enforced |
| `jest.config.*` | Test framework config, coverage thresholds |
| `vitest.config.*` | Vitest (modern, faster alternative to Jest) |
| `playwright.config.*` | E2E testing |
| `next.config.*` | Next.js → SSR/SSG framework |
| `vite.config.*` | Vite → modern build tool |
| `webpack.config.*` | Webpack → older build tool or Module Federation |
| `package-lock.json` / `yarn.lock` / `pnpm-lock.yaml` | Package manager in use |

**Framework detection from `dependencies`:**
- `react` → React
- `next` → Next.js (SSR)
- `vue` → Vue.js
- `@angular/core` → Angular
- `svelte` → Svelte
- `express` → Express.js (API)
- `fastify` → Fastify (API)
- `@nestjs/core` → NestJS (structured backend)
- `@modelcontextprotocol/sdk` → MCP server
- `tailwindcss` → Tailwind CSS
- `zustand` → Zustand state management
- `@reduxjs/toolkit` → Redux Toolkit state management
- `@tanstack/react-query` → React Query (data fetching)
- `react-hook-form` → Form management
- `zod` → Schema validation

**Monorepo signals:**
- `workspaces` array in root `package.json` → npm/yarn workspace
- Multiple `package.json` at depth 1-2 → independent packages
- `pnpm-workspace.yaml` → pnpm workspace
- `lerna.json` → Lerna monorepo

---

## Wide Scan Grep Patterns

Run during Phase 1 step 1c. All greps exclude build output dirs. Run in parallel.

### Custom patterns

```bash
# Abstract classes and inheritance
grep -rn 'abstract class\| extends ' --include='*.ts' src/ | grep -v node_modules | grep -v '//'

# Interface declarations
grep -rn '^export interface\|^interface ' --include='*.ts' src/

# Type declarations
grep -rn '^export type ' --include='*.ts' src/
```

### Anti-pattern signals

```bash
# God component/class candidates
find . -name '*.ts' -o -name '*.tsx' | grep -v node_modules | grep -v dist \
  | xargs wc -l 2>/dev/null | sort -rn | head -20

# TypeScript `any` usage
grep -rn '\bany\b\| as any\b\|// @ts-ignore\|// @ts-nocheck' \
  --include='*.ts' --include='*.tsx' src/ | grep -v node_modules

# Console.log in production (not test files)
grep -rn '\bconsole\.log\b' --include='*.ts' --include='*.tsx' src/ \
  --exclude-dir=test --exclude-dir=__tests__ --exclude-dir=spec

# TODO/FIXME/HACK count
grep -rc 'TODO\|FIXME\|HACK' --include='*.ts' --include='*.tsx' src/ | grep -v ':0$'
```

### Convention frequency

```bash
# Naming: PascalCase components vs lowercase files
find src -name '*.tsx' | head -20  # Check naming pattern in output

# Import style: absolute (tsconfig paths) vs relative
grep -rn "from '\.\." --include='*.ts' --include='*.tsx' src/ | wc -l  # relative
grep -rn "from '@/" --include='*.ts' --include='*.tsx' src/ | wc -l    # alias-based
```

### Security posture signals

```bash
# Express.js security middleware
grep -r 'express-rate-limit\|helmet\|cors\|express-session' package.json package-lock.json 2>/dev/null

# NestJS guards and auth decorators
grep -rn '@UseGuards\|implements CanActivate\|@Injectable.*Guard' --include='*.ts' src/ | wc -l

# JWT authentication
grep -r 'jsonwebtoken\|@nestjs/jwt\|express-jwt\|passport-jwt' package.json package-lock.json 2>/dev/null
grep -rn 'jwt\.sign\|jwt\.verify\|JwtService\|JwtStrategy' --include='*.ts' src/ | wc -l

# Passport strategies
grep -rn 'passport\|PassportStrategy\|AuthGuard' --include='*.ts' src/ | wc -l

# CORS configuration
grep -rn 'cors(\|enableCors\|app\.use(cors' --include='*.ts' src/ | wc -l

# Helmet security headers
grep -rn 'helmet(\|app\.use(helmet' --include='*.ts' src/ | wc -l

# Route protection ratio (Express)
TOTAL_ROUTES=$(grep -rc 'app\.get\|app\.post\|app\.put\|app\.delete\|app\.patch\|router\.get\|router\.post' \
  --include='*.ts' --include='*.js' src/ | awk -F: '{s+=$2}END{print s}')
PROTECTED_ROUTES=$(grep -rc 'authenticate\|isAuthenticated\|requireAuth\|@UseGuards' \
  --include='*.ts' src/ | awk -F: '{s+=$2}END{print s}')
# If PROTECTED_ROUTES < TOTAL_ROUTES: flag potential unprotected routes

# Auth middleware detection
grep -rn 'function.*middleware\|const.*middleware.*=.*async\|export.*middleware' \
  --include='*.ts' src/ | grep -i 'auth\|token\|jwt' | wc -l

# Environment variable security
grep -rn 'process\.env\..*SECRET\|process\.env\..*KEY\|process\.env\..*TOKEN' \
  --include='*.ts' src/ | wc -l
```

### API surface signals

```bash
# Endpoint tally by HTTP method (Express)
GET_COUNT=$(grep -rc '\.get(\|router\.get' --include='*.ts' --include='*.js' src/ | awk -F: '{s+=$2}END{print s}')
POST_COUNT=$(grep -rc '\.post(\|router\.post' --include='*.ts' --include='*.js' src/ | awk -F: '{s+=$2}END{print s}')
PUT_COUNT=$(grep -rc '\.put(\|router\.put' --include='*.ts' --include='*.js' src/ | awk -F: '{s+=$2}END{print s}')
DELETE_COUNT=$(grep -rc '\.delete(\|router\.delete' --include='*.ts' --include='*.js' src/ | awk -F: '{s+=$2}END{print s}')
PATCH_COUNT=$(grep -rc '\.patch(\|router\.patch' --include='*.ts' --include='*.js' src/ | awk -F: '{s+=$2}END{print s}')
# Report: "GET:N POST:M PUT:P DELETE:Q PATCH:R  total: N+M+P+Q+R endpoints"

# NestJS controller endpoints
NEST_GET=$(grep -rc '@Get(' --include='*.ts' src/ | awk -F: '{s+=$2}END{print s}')
NEST_POST=$(grep -rc '@Post(' --include='*.ts' src/ | awk -F: '{s+=$2}END{print s}')
NEST_PUT=$(grep -rc '@Put(' --include='*.ts' src/ | awk -F: '{s+=$2}END{print s}')
NEST_DELETE=$(grep -rc '@Delete(' --include='*.ts' src/ | awk -F: '{s+=$2}END{print s}')
NEST_PATCH=$(grep -rc '@Patch(' --include='*.ts' src/ | awk -F: '{s+=$2}END{print s}')
# Report: "NestJS endpoints - GET:N POST:M PUT:P DELETE:Q PATCH:R"

# OpenAPI / Swagger documentation
grep -r 'swagger-ui-express\|@nestjs/swagger\|swagger-jsdoc\|openapi-types' \
  package.json package-lock.json 2>/dev/null
grep -rn '@ApiOperation\|@ApiResponse\|@ApiTags' --include='*.ts' src/ | wc -l

# API versioning (URL-based)
grep -rn "'/v[0-9]\|@Controller('v[0-9]\|/api/v[0-9]" --include='*.ts' src/ \
  | grep -oP '/v\d+/' | sort -u
# If versions found: report "URL-based versioning: v1, v2..." else "No versioning detected"

# GraphQL detection
grep -r '@apollo/server\|graphql\|@nestjs/graphql\|type-graphql' package.json 2>/dev/null
grep -rn '@Resolver\|@Query\|@Mutation\|type Query\|type Mutation' --include='*.ts' src/ | wc -l

# REST vs GraphQL API style
grep -rn '@Controller\|app\.use\|router\.\|fastify\.' --include='*.ts' src/ | wc -l  # REST
grep -rn 'GraphQLModule\|@Resolver' --include='*.ts' src/ | wc -l  # GraphQL
```

### Observability signals

```bash
# Structured logging libraries
grep -r 'pino\|winston\|bunyan\|@nestjs/common.*Logger' package.json package-lock.json 2>/dev/null

# Pino structured logging
grep -rn "import.*pino\|from 'pino'\|pino(" --include='*.ts' src/ | wc -l
grep -rn '\.info(\|\.error(\|\.warn(\|\.debug(' --include='*.ts' src/ \
  | grep -v console | wc -l  # structured log calls

# Winston structured logging
grep -rn "import.*winston\|from 'winston'\|winston\.createLogger" --include='*.ts' src/ | wc -l

# NestJS Logger usage
grep -rn '@nestjs/common.*Logger\|this\.logger\.\|new Logger(' --include='*.ts' src/ | wc -l

# OpenTelemetry instrumentation
grep -r '@opentelemetry/api\|@opentelemetry/sdk\|@opentelemetry/instrumentation' \
  package.json package-lock.json 2>/dev/null
grep -rn 'import.*@opentelemetry\|tracer\.\|span\.\|metric\.' --include='*.ts' src/ | wc -l

# Prometheus metrics
grep -r 'prom-client\|@willsoto/nestjs-prometheus' package.json 2>/dev/null
grep -rn 'new Counter\|new Gauge\|new Histogram\|register\.' --include='*.ts' src/ | wc -l

# Health check endpoints
grep -rn '/health\|/healthz\|/ready\|/readyz\|@nestjs/terminus' --include='*.ts' src/ | wc -l

# Request correlation IDs
grep -rn 'x-request-id\|x-correlation-id\|requestId\|correlationId' \
  --include='*.ts' src/ | wc -l

# Error tracking integrations
grep -r 'sentry\|@sentry/node\|bugsnag\|rollbar\|raygun' package.json 2>/dev/null
```

### Dependency deep-scan signals

```bash
# Lockfile detection (package manager in use)
if [ -f package-lock.json ]; then echo "npm lockfile found"; fi
if [ -f yarn.lock ]; then echo "yarn lockfile found"; fi
if [ -f pnpm-lock.yaml ]; then echo "pnpm lockfile found"; fi
if [ -f bun.lockb ]; then echo "bun lockfile found"; fi

# npm audit for vulnerabilities
npm audit --json 2>/dev/null | jq -r '.metadata | "Vulnerabilities: \(.vulnerabilities.total) (critical:\(.vulnerabilities.critical) high:\(.vulnerabilities.high))"'

# Outdated dependencies
npm outdated --json 2>/dev/null | jq -r 'to_entries | length' | xargs -I {} echo "{} outdated packages"

# Peer dependency conflicts
npm ls --json 2>&1 | jq -r '.problems // [] | length' | xargs -I {} echo "{} peer dependency issues"

# Dependency count and weight
DEP_COUNT=$(jq -r '.dependencies // {} | length' package.json 2>/dev/null)
DEV_DEP_COUNT=$(jq -r '.devDependencies // {} | length' package.json 2>/dev/null)
echo "Dependencies: $DEP_COUNT production, $DEV_DEP_COUNT dev"

# Workspace dependency cross-references (monorepo)
if [ -f package.json ] && jq -e '.workspaces' package.json >/dev/null 2>&1; then
  grep -rn '"@.*":\s*"workspace:' --include='package.json' . | wc -l
  # Report: "N workspace-internal dependencies found"
fi

# Version pinning vs ranges
grep -c '": "\^' package.json 2>/dev/null | xargs -I {} echo "{} caret-range dependencies"
grep -c '": "~' package.json 2>/dev/null | xargs -I {} echo "{} tilde-range dependencies"
grep -c '": "[0-9]' package.json 2>/dev/null | xargs -I {} echo "{} pinned dependencies"

# Deprecated packages detection
npm deprecate --json 2>/dev/null | jq -r 'to_entries[] | select(.value != null) | .key' | wc -l

# Security policy files
if [ -f .npmrc ]; then echo ".npmrc found - check for registry config"; fi
if [ -f .yarnrc.yml ]; then echo ".yarnrc.yml found - Yarn 2+ config"; fi

# License compliance check (if license checker installed)
if command -v license-checker >/dev/null 2>&1; then
  license-checker --summary 2>/dev/null | head -20
fi
```

---

## Notes

- All grep patterns exclude `node_modules/`, `dist/`, `build/`, `.next/`, `.nuxt/`, `out/`, `.turbo/` by default
- Run patterns in parallel for speed
- Security posture: focus on auth middleware coverage gaps
- API surface: distinguish Express/Fastify vs NestJS decorator patterns
- Observability: structured logging (pino/winston) > console.log; OpenTelemetry signals maturity
- Dependency deep-scan: lockfile hygiene, audit results, peer conflicts are strong quality signals
