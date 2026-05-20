# GraphQL Edge Detection

Detection entries for GraphQL transports: servers (inbound), clients (outbound). Each entry provides grep commands, extraction rules, and example edge output.

**Applies to:** workspace mode (multi-repo) edge extraction.

---

## Entry template

| Field | Description |
|-------|-------------|
| **Grep** | Command(s) to detect the transport |
| **Extract** | What to pull from matches |
| **Direction** | `inbound` (server/schema) or `outbound` (client) |
| **Edge example** | YAML shape emitted in the report |

---

## Java/Spring

### spring-graphql (Java/Kotlin)

**Server-side (inbound):**
```bash
grep -rn '@QueryMapping\|@MutationMapping\|@SubscriptionMapping' \
  --include='*.java' --include='*.kt' src/
```

- `@QueryMapping` → extract method name as target (query operation name); direction: inbound
- `@MutationMapping` → extract method name as target (mutation operation name); direction: inbound
- `@SubscriptionMapping` → extract method name as target (subscription operation name); direction: inbound
- Annotate with `protocol: graphql`

**Client-side (outbound):**
```bash
grep -rn 'HttpGraphQlClient\.builder\|WebGraphQlClient\.builder' \
  --include='*.java' --include='*.kt' src/
```

- `HttpGraphQlClient.builder(url)` → extract URL as target; direction: outbound

**Edge examples:**
```yaml
- {family: graphql, protocol: graphql, type: graphql, direction: inbound, target: "getOrder", schema_ref: "src/main/resources/graphql/schema.graphqls"}
- {family: graphql, protocol: graphql, type: graphql, direction: outbound, target: "http://product-service/graphql", schema_ref: null}
```

### Netflix DGS (Java/Kotlin)

```bash
grep -rn '@DgsQuery\|@DgsMutation\|@DgsSubscription\|@DgsComponent' \
  --include='*.java' --include='*.kt' src/
```

- `@DgsQuery(field = "...")` → extract `field` value as target (defaults to method name if absent); direction: inbound
- `@DgsMutation(field = "...")` → same; direction: inbound
- `@DgsSubscription(field = "...")` → same; direction: inbound
- When `@DgsComponent` is present, check if it also contains `@DgsQuery`/`@DgsMutation`/`@DgsSubscription` to confirm it is a data fetcher

**Edge example:**
```yaml
- {family: graphql, protocol: graphql, type: graphql, direction: inbound, target: "orders", schema_ref: "src/main/resources/schema/schema.graphqls"}
```

---

## TypeScript / JavaScript / Node.js

### Apollo Client (TypeScript)

```bash
grep -rn 'new ApolloClient(\|ApolloClient({' --include='*.ts' --include='*.tsx' src/
grep -rn 'useQuery(\|useLazyQuery(\|useMutation(' --include='*.ts' --include='*.tsx' src/
```

- `new ApolloClient({ uri: "..." })` → extract `uri` as target; direction: outbound
- `useQuery(QUERY)` / `useMutation(MUTATION)` → confirms GraphQL client usage; no additional target needed beyond the URI

**Edge example:**
```yaml
- {family: graphql, protocol: graphql, type: graphql, direction: outbound, target: "http://api-service/graphql", schema_ref: null}
```

### urql (TypeScript)

```bash
grep -rn 'createClient({' --include='*.ts' --include='*.tsx' src/
grep -rn 'useQuery({' --include='*.ts' --include='*.tsx' src/
```

- `createClient({ url: "..." })` → extract `url` as target; direction: outbound
- `useQuery({ query })` → confirms GraphQL client usage

**Edge example:**
```yaml
- {family: graphql, protocol: graphql, type: graphql, direction: outbound, target: "http://catalog-service/graphql", schema_ref: null}
```

### graphql-request (TypeScript)

```bash
grep -rn 'new GraphQLClient(\|request(' --include='*.ts' src/
```

- `new GraphQLClient(endpoint)` → extract `endpoint` as target; direction: outbound
- `request(endpoint, query)` bare function call → extract `endpoint` as target; direction: outbound

**Edge example:**
```yaml
- {family: graphql, protocol: graphql, type: graphql, direction: outbound, target: "http://data-service/graphql", schema_ref: null}
```

### Relay (TypeScript)

```bash
grep -rn 'Environment\|fetchQuery\|createEnvironment\|RelayEnvironmentProvider' \
  --include='*.ts' --include='*.tsx' src/
```

- `new Environment({ network: Network.create(fetchFn), ... })` → look inside `fetchFn` body for the URL literal; direction: outbound
- `fetchQuery({url})` or a custom network layer function containing `fetch(url)` → extract URL

**Edge example:**
```yaml
- {family: graphql, protocol: graphql, type: graphql, direction: outbound, target: "http://api-gateway/graphql", schema_ref: null}
```

### Apollo Server — Inbound (TypeScript / Node.js)

```bash
grep -rn 'new ApolloServer(\|typeDefs\|resolvers' --include='*.ts' --include='*.js' src/
```

- `new ApolloServer({ typeDefs, resolvers })` → confirms GraphQL server presence; direction: inbound
- Extract top-level query/mutation/subscription names from `typeDefs` (grep for `type Query {`, `type Mutation {`, `type Subscription {`)
- Target = list of operation root names (e.g., `"Query: getOrder, createOrder"`)

**Edge example:**
```yaml
- {family: graphql, protocol: graphql, type: graphql, direction: inbound, target: "Query: orders, createOrder", schema_ref: "src/schema.graphql"}
```

---

## Schema ref note

When a `.graphqls`, `schema.graphql`, or `*.graphql` file is detected alongside GraphQL annotations, capture the relative path as `schema_ref`. This applies to both server-side and client-side entries.
