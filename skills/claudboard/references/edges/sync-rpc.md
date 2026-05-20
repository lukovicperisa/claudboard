# Sync-RPC Edge Detection

Detection entries for synchronous request-response transports. Each entry provides grep commands, extraction rules, and example edge output.

**Applies to:** workspace mode (multi-repo) edge extraction.

---

## Entry template

| Field | Description |
|-------|-------------|
| **Grep** | Command(s) to detect the transport |
| **Extract** | What to pull from matches |
| **Direction** | `inbound` or `outbound` |
| **Edge example** | YAML shape emitted in the report |

---

## Java/Spring

### Feign (Java/Kotlin)

```bash
grep -rn '@FeignClient' --include='*.java' --include='*.kt' src/
```

- Extract the `name` attribute value as the target service name
- If `name` attribute is absent, fall back to `value` attribute; if both absent → target = `unknown`
- Direction: outbound

**Edge example:**
```yaml
- {family: sync-rpc, protocol: feign, type: feign, direction: outbound, target: "order-service", schema_ref: null}
```

### HTTP — RestTemplate / WebClient / RestClient (Java/Kotlin)

```bash
grep -rn 'RestTemplate\|new RestTemplate()\|RestClient\.builder()\|WebClient\.builder()' \
  --include='*.java' --include='*.kt' src/
```

- Look for `.getForObject(`, `.postForEntity(`, `.exchange(`, `.baseUrl("...")` calls chained after the grep hits
- Extract the URL string literal as target, or `unknown` if the URL is a variable/constant
- Direction: outbound

**Edge example:**
```yaml
- {family: sync-rpc, protocol: http, type: http, direction: outbound, target: "http://user-service/api/users", schema_ref: null}
```

### OkHttp (Java/Kotlin)

```bash
grep -rn 'OkHttpClient' --include='*.java' --include='*.kt' src/
grep -rn 'Request\.Builder()\.url(' --include='*.java' --include='*.kt' src/
```

- Look for `new Request.Builder().url("...")` and extract the URL literal as target
- If URL uses a constant, grep for the constant definition; if unresolvable → target = `unknown`
- Direction: outbound

**Edge example:**
```yaml
- {family: sync-rpc, protocol: http, type: http, direction: outbound, target: "http://inventory-service/stock", schema_ref: null}
```

### Apache HttpClient (Java/Kotlin)

```bash
grep -rn 'HttpClients\.createDefault\|CloseableHttpClient' --include='*.java' --include='*.kt' src/
```

- Look for `new HttpGet("...")`, `new HttpPost("...")`, or `URI.create("...")` chained after `CloseableHttpClient`
- Extract the URI string literal as target, or `unknown` if variable
- Direction: outbound

**Edge example:**
```yaml
- {family: sync-rpc, protocol: http, type: http, direction: outbound, target: "http://payment-service/pay", schema_ref: null}
```

### gRPC — Java outbound

```bash
grep -rn 'ManagedChannelBuilder\.forAddress(' --include='*.java' --include='*.kt' src/
find . -name '*.proto' ! -path '*/vendor/*' ! -path '*/node_modules/*'
```

- Any `ManagedChannelBuilder.forAddress(host, port)` → extract host string literal; if variable → `unknown`
- Any `.proto` file imports detected → extract service name from proto package declaration
- Direction: outbound

**Edge example:**
```yaml
- {family: sync-rpc, protocol: grpc, type: grpc, direction: outbound, target: "user-service", schema_ref: "src/main/proto/user.proto"}
```

### Spring MVC — Inbound REST (Java/Kotlin)

```bash
grep -rn '@RestController' --include='*.java' --include='*.kt' src/
grep -rn '@RequestMapping\|@GetMapping\|@PostMapping\|@PutMapping\|@DeleteMapping\|@PatchMapping' \
  --include='*.java' --include='*.kt' src/
```

- Extract endpoint paths from `@RequestMapping`, `@GetMapping`, etc.
- Direction: inbound

**Edge example:**
```yaml
- {family: sync-rpc, protocol: http, type: http, direction: inbound, target: "/api/users", schema_ref: null}
```

---

## TypeScript / JavaScript / Node.js

### axios / fetch (TypeScript)

```bash
grep -rn 'axios\.create({.*baseURL\|fetch(' --include='*.ts' --include='*.tsx' src/
```

- Extract `baseURL` value from `axios.create({ baseURL: "..." })` as target
- For bare `fetch(` calls: extract the URL string if it references a service name; skip relative paths (e.g., `/api/...` without a hostname)
- Direction: outbound

**Edge example:**
```yaml
- {family: sync-rpc, protocol: http, type: http, direction: outbound, target: "http://order-service", schema_ref: null}
```

### ky (TypeScript)

```bash
grep -rn 'ky\.extend\|ky\.get\|ky\.post\|ky\.put\|ky\.delete' \
  --include='*.ts' --include='*.tsx' src/
```

- Look for `ky.extend({ prefixUrl: "..." })` and extract `prefixUrl` as target
- For per-call `ky.get(url)` / `ky.post(url)`: extract URL literal if it contains a hostname
- Direction: outbound

**Edge example:**
```yaml
- {family: sync-rpc, protocol: http, type: http, direction: outbound, target: "http://api-service", schema_ref: null}
```

### undici (TypeScript / Node.js)

```bash
grep -rn 'new Pool\|undici\.request' --include='*.ts' --include='*.js' src/
```

- `new Pool(url)` → extract URL as target
- `request(url, ...)` → extract URL literal as target
- Direction: outbound

**Edge example:**
```yaml
- {family: sync-rpc, protocol: http, type: http, direction: outbound, target: "http://catalog-service", schema_ref: null}
```

### React Query (TypeScript)

```bash
grep -rn 'useQuery\|useMutation\|useInfiniteQuery' --include='*.ts' --include='*.tsx' src/
```

- Inside the matching block, look for a `queryFn` or `mutationFn` that contains a URL literal
- Extract the URL literal from `fetch(url)` or `axios.get(url)` inside `queryFn`
- Skip relative URLs without hostname

**Edge example:**
```yaml
- {family: sync-rpc, protocol: http, type: http, direction: outbound, target: "http://order-service/orders", schema_ref: null}
```

### SWR (TypeScript)

```bash
grep -rn 'useSWR(' --include='*.ts' --include='*.tsx' src/
```

- Extract the first argument of `useSWR(url, ...)` if it is a string literal with a hostname
- Skip relative URL strings

**Edge example:**
```yaml
- {family: sync-rpc, protocol: http, type: http, direction: outbound, target: "http://user-service/profile", schema_ref: null}
```

### RTK Query (TypeScript)

```bash
grep -rn 'createApi\|fetchBaseQuery\|baseQuery' --include='*.ts' src/
```

- Extract `baseUrl` from `fetchBaseQuery({ baseUrl: "..." })` as target
- Also scan per-endpoint `query: ({...}) => '/path'` for endpoint paths appended to base URL

**Edge example:**
```yaml
- {family: sync-rpc, protocol: http, type: http, direction: outbound, target: "http://inventory-service", schema_ref: null}
```

### tRPC (TypeScript)

```bash
grep -rn 'createTRPCClient\|createTRPCProxyClient\|httpBatchLink' --include='*.ts' src/
```

- Extract `url` from `httpBatchLink({ url: "..." })` as target
- Direction: outbound

**Edge example:**
```yaml
- {family: sync-rpc, protocol: trpc, type: trpc, direction: outbound, target: "http://trpc-service/trpc", schema_ref: null}
```

### grpc-web (TypeScript)

```bash
grep -rn 'new.*ServiceClient\|createGrpcWebTransport' --include='*.ts' src/
```

- `new <Name>ServiceClient(host)` → extract `host` string literal as target
- `createGrpcWebTransport({ baseUrl: "..." })` → extract `baseUrl` as target
- Direction: outbound

**Edge example:**
```yaml
- {family: sync-rpc, protocol: grpc, type: grpc, direction: outbound, target: "http://grpc-service:8080", schema_ref: null}
```

### Connect-RPC (TypeScript)

```bash
grep -rn 'createPromiseClient\|createConnectTransport' --include='*.ts' src/
```

- Extract `baseUrl` from `createConnectTransport({ baseUrl: "..." })` as target
- Direction: outbound

**Edge example:**
```yaml
- {family: sync-rpc, protocol: grpc, type: grpc, direction: outbound, target: "http://connect-service:8080", schema_ref: null}
```

### ts-proto generated clients (TypeScript)

```bash
grep -rn 'ServiceClientImpl\|.*ServiceClient' --include='*.ts' src/
```

- ts-proto generates `<Name>ServiceClientImpl` classes. Look for the constructor call where host/channel config is passed.
- Extract the host string literal or baseUrl from the transport configuration object
- Direction: outbound

**Edge example:**
```yaml
- {family: sync-rpc, protocol: grpc, type: grpc, direction: outbound, target: "http://ts-proto-service:8080", schema_ref: null}
```

### Express — Inbound REST (TypeScript/JavaScript)

```bash
grep -rn 'app\.\(get\|post\|put\|delete\|patch\)\|router\.\(get\|post\|put\|delete\|patch\)' \
  --include='*.ts' --include='*.js' src/
```

- Extract the route path string literal (first argument to `app.get(path, ...)` or `router.get(path, ...)`)
- Accept partial coverage — dynamically constructed paths may not be grep-able
- Direction: inbound

**Edge example:**
```yaml
- {family: sync-rpc, protocol: http, type: http, direction: inbound, target: "/api/products", schema_ref: null}
```

### Fastify — Inbound REST (TypeScript/JavaScript)

```bash
grep -rn 'fastify\.\(get\|post\|put\|delete\|patch\)\|fastify\.route({' \
  --include='*.ts' --include='*.js' src/
```

- Extract the `url` field from `fastify.route({ method, url, ... })` or the first argument to `fastify.get(url, ...)`
- Direction: inbound

**Edge example:**
```yaml
- {family: sync-rpc, protocol: http, type: http, direction: inbound, target: "/api/orders", schema_ref: null}
```

### NestJS — Inbound REST (TypeScript)

```bash
grep -rn '@Controller\|@Get\|@Post\|@Put\|@Delete\|@Patch' --include='*.ts' src/
```

- Extract path from `@Controller('path')` + method decorator `@Get('sub-path')` — concatenate for full route
- Direction: inbound

**Edge example:**
```yaml
- {family: sync-rpc, protocol: http, type: http, direction: inbound, target: "/api/notifications", schema_ref: null}
```

---

## Python

### requests (Python)

```bash
grep -rn 'requests\.get(\|requests\.post(\|requests\.put(\|requests\.delete(\|requests\.patch(' \
  --include='*.py' src/
```

- Extract the URL string literal as target
- Skip intra-service calls (localhost, 127.0.0.1, relative paths)
- Direction: outbound

**Edge example:**
```yaml
- {family: sync-rpc, protocol: http, type: http, direction: outbound, target: "http://inventory-service/stock", schema_ref: null}
```

---

## Limitation note

Inbound TypeScript/Node.js route extraction (Express, Fastify, NestJS) is statically grep-able only for literal route strings. Dynamically constructed routes (string concatenation, variables) are not captured. Coverage is partial; document in the report when routes appear dynamic.
