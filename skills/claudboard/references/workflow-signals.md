# Workflow Signals Detection

Used by `claudboard-analyse` to populate the "### Workflow Signals" subsection of the analysis report. Consumed by `claudboard-workflow` for capability-flag resolution. Backward-compatible additive — a missing subsection defaults all signals to unknown/empty.

---

## Output Schema

```yaml
workflow_signals:
  cross_service_edges:
    - {type: feign, target: "<service-name>"}
    - {type: http, target: "<url-or-unknown>"}
    - {type: kafka, target: "<topic-name>"}
    - {type: grpc, target: "<service-name-or-unknown>"}
  shared_libraries:
    - {name: "<artifactId-or-package>", consumer_count: <N>}
  auth_perimeter: "gateway|in-service-jwt|none|unknown"
  ticket_prefix: "PROJ|null"
```

Rules:
- `cross_service_edges`: list of detected outbound communication edges; empty list `[]` if none
- `shared_libraries`: list of libraries used by 2+ services; empty list `[]` for single-repo projects or if none detected
- `auth_perimeter`: exactly one of `gateway`, `in-service-jwt`, `none`, or `unknown`
- `ticket_prefix`: string (e.g. `"PLAT"`) or `null`
- **Always emit this block** even when all signals are empty/unknown — the subsection must always be present in the report

---

## Detection: Cross-Service Edges

Run after Wide Scan (Phase 1c). Piggybacks on data already collected — no additional file reads needed unless a target is unresolved.

Edge types and grep commands:

### Feign (Java/Kotlin)

```bash
grep -rn '@FeignClient' --include='*.java' --include='*.kt' src/
```

- Extract the `name` attribute value as the target service name
- Example match: `@FeignClient(name = "order-service")` → `{type: feign, target: "order-service"}`
- If `name` attribute is absent, fall back to `value` attribute; if both absent → target = `unknown`

### HTTP — RestTemplate / WebClient / RestClient (Java/Kotlin)

```bash
grep -rn 'RestTemplate\|new RestTemplate()\|RestClient\.builder()\|WebClient\.builder()' \
  --include='*.java' --include='*.kt' src/
```

- Look for `.getForObject(`, `.postForEntity(`, `.exchange(` calls chained after the grep hits
- Extract the URL string literal as target, or `unknown` if the URL is a variable/constant
- Example: `restTemplate.getForObject("http://user-service/api/users", ...)` → `{type: http, target: "http://user-service/api/users"}`

### HTTP — axios / fetch (TypeScript)

```bash
grep -rn 'axios\.create({.*baseURL\|fetch(' --include='*.ts' --include='*.tsx' src/
```

- Extract `baseURL` value from `axios.create({ baseURL: "..." })` as target
- For bare `fetch(` calls: extract the URL string if it references a service name; skip relative paths (e.g., `/api/...` without a hostname)
- Example: `axios.create({ baseURL: "http://order-service" })` → `{type: http, target: "http://order-service"}`

### HTTP — requests (Python)

```bash
grep -rn 'requests\.get(\|requests\.post(\|requests\.put(\|requests\.delete(\|requests\.patch(' \
  --include='*.py' src/
```

- Extract the URL string literal as target
- Skip intra-service calls (localhost, 127.0.0.1, relative paths)
- Example: `requests.get("http://inventory-service/stock")` → `{type: http, target: "http://inventory-service/stock"}`

### Kafka Producer (Java/Kotlin)

```bash
grep -rn 'KafkaTemplate' --include='*.java' --include='*.kt' src/
grep -rn '\.send(' --include='*.java' --include='*.kt' src/
grep -rn '@SendTo' --include='*.java' --include='*.kt' src/
```

- For `KafkaTemplate.send("topic-name", ...)` → extract topic literal as target
- For `@SendTo("topic-name")` → extract topic value as target
- If topic is a constant reference (e.g., `KafkaTemplate.send(TOPIC_ORDERS, ...)`) → grep for the constant definition to resolve the string value; if unresolvable → target = `unknown`
- Example: `kafkaTemplate.send("order-created", event)` → `{type: kafka, target: "order-created"}`

### gRPC (Java / any language)

```bash
grep -rn 'ManagedChannelBuilder\.forAddress(' --include='*.java' --include='*.kt' src/
find . -name '*.proto' ! -path '*/vendor/*' ! -path '*/node_modules/*'
```

- Any `ManagedChannelBuilder.forAddress(host, port)` → `{type: grpc, target: "<host-value-or-unknown>"}`
- Any `.proto` file imports detected → `{type: grpc, target: "<service-name-from-proto-package-or-unknown>"}`
- Extract host string literal from `forAddress`; if variable → `unknown`

---

## Detection: Shared Libraries

Only meaningful in **workspace or monorepo mode**. In single-repo mode, emit `shared_libraries: []`.

### Maven (Java/Kotlin)

```bash
# Find all pom.xml files in the workspace (excluding vendor/build dirs)
find . -name 'pom.xml' \
  ! -path '*/node_modules/*' ! -path '*/target/*' ! -path '*/.gradle/*'
```

For each `pom.xml` found, extract all `<artifactId>` values within `<dependency>` sections.

Count how many distinct `pom.xml` files reference each `<artifactId>`. Report those with count ≥ 2:

```bash
# Count per artifactId across all pom.xml files
grep -rh '<artifactId>' --include='pom.xml' . \
  | sed 's/.*<artifactId>\(.*\)<\/artifactId>.*/\1/' \
  | sort | uniq -c | sort -rn | awk '$1 >= 2 {print $1, $2}'
```

- Each result line → `{name: "<artifactId>", consumer_count: <N>}`
- Filter out known external/third-party artifacts if they appear in root BOM only; focus on internal group IDs matching the project's `groupId` prefix

### NPM Workspace (TypeScript/JavaScript)

```bash
# Find all package.json files
find . -name 'package.json' \
  ! -path '*/node_modules/*' ! -path '*/dist/*' ! -path '*/build/*'
```

1. From the root `package.json`, identify workspace globs (e.g., `"workspaces": ["packages/*", "apps/*"]`)
2. Collect all internal package names (packages listed in workspace globs or packages with names starting with `@<scope>/`)
3. Count how many other `package.json` files list each internal package in `dependencies` or `devDependencies`
4. Report those with count ≥ 2: `{name: "<package-name>", consumer_count: <N>}`

---

## Detection: Auth Perimeter

Classify into exactly one of: `gateway`, `in-service-jwt`, `none`, `unknown`.

Apply in order — first match wins.

### gateway

Detect any of the following:

```bash
# Service named gateway/api-gateway/proxy in workspace
# (check directory names and spring.application.name)
find . -maxdepth 3 -type d \( \
  -name '*gateway*' -o -name '*api-gateway*' -o -name '*proxy*' \
\)

# Spring Cloud Gateway dependency
grep -rn 'spring-cloud-starter-gateway' --include='pom.xml' --include='*.gradle' --include='*.gradle.kts' .

# Kong config
find . -name 'kong.yml' -o -name 'kong.yaml'

# Traefik config
find . -name 'traefik.yml' -o -name 'traefik.yaml'
```

If any of these match → `auth_perimeter: "gateway"`

### in-service-jwt

Detect any of the following (in source files, not config):

```bash
# Spring Security JWT / OAuth2 Resource Server (Java/Kotlin)
grep -rn 'JwtDecoder\|oauth2ResourceServer()' \
  --include='*.java' --include='*.kt' src/

# FastAPI OAuth2 (Python)
grep -rn 'OAuth2PasswordBearer' --include='*.py' src/

# Express JWT middleware (TypeScript/JavaScript)
grep -rn 'expressjwt\|jsonwebtoken' \
  --include='*.ts' --include='*.js' --include='*.tsx' src/
```

If any of these match (and no gateway detected) → `auth_perimeter: "in-service-jwt"`

### none

No auth signals detected in any of the above checks → `auth_perimeter: "none"`

### unknown

Auth-related code found but does not match gateway or in-service-jwt patterns (e.g., custom session management, SAML, proprietary auth filter) → `auth_perimeter: "unknown"`

---

## Detection: Ticket Prefix

Run both commands; apply threshold rules to determine the prefix.

### Step 1: Scan commit messages

```bash
git log --oneline -50 | grep -oP '^[a-f0-9]+ [A-Z]+-[0-9]+' | grep -oP '[A-Z]+' \
  | sort | uniq -c | sort -rn | head -5
```

- Count how many of the last 50 commits have a `^[A-Z]+-[0-9]+` prefix (e.g., `PLAT-1234`)
- If ≥50% of the last 50 commits match AND ≥80% of those share the same alphabetic prefix → **use that prefix**

Example: 30 out of 50 commits match (`≥50%`), 26 of those 30 have prefix `PLAT` (`≥87%`) → `ticket_prefix: "PLAT"`

### Step 2: Scan branch names (fallback)

If Step 1 does not yield a prefix, try branch names:

```bash
git branch -a | grep -oP '[a-z]+/([A-Z]+-[0-9]+)/' | grep -oP '[A-Z]+' \
  | sort | uniq -c | sort -rn | head -5
```

- Apply the same threshold: ≥50% of last 20 branch names contain a `[A-Z]+-[0-9]+` segment AND ≥80% of those share the same alphabetic prefix → use that prefix

### Step 3: Null fallback

If neither Step 1 nor Step 2 yields a confident prefix → `ticket_prefix: null`

---

## Backward Compatibility

Consumers (`claudboard-generate`, `claudboard-refresh`, `claudboard-techdebt`) treat a missing "### Workflow Signals" section as normal — they do not parse or use it. Only `claudboard-workflow` reads this subsection.

When the subsection is missing, `claudboard-workflow` warns:

> "Limited workflow signals available — capability blocks may default off; consider re-running `/analyse` to refresh."

and continues with all signals defaulted:
- `cross_service_edges: []`
- `shared_libraries: []`
- `auth_perimeter: "unknown"`
- `ticket_prefix: null`
