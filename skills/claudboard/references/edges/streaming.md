# Streaming Edge Detection

Detection entries for real-time / streaming transports: WebSocket, SSE, RSocket. Each entry provides grep commands, extraction rules, and example edge output.

**Applies to:** workspace mode (multi-repo) edge extraction.

---

## Entry template

| Field | Description |
|-------|-------------|
| **Grep** | Command(s) to detect the transport |
| **Extract** | What to pull from matches |
| **Direction** | `inbound` (server/listener) or `outbound` (client/sender) |
| **Edge example** | YAML shape emitted in the report |

---

## Java/Spring

### Spring WebSocket / STOMP (Java/Kotlin)

```bash
grep -rn '@MessageMapping\|@SubscribeMapping' --include='*.java' --include='*.kt' src/
grep -rn 'addEndpoint\|registerStompEndpoints' --include='*.java' --include='*.kt' src/
```

**Inbound:**
- `@MessageMapping("/path")` → extract path as target; direction: inbound (server handles incoming messages on this path)
- `@SubscribeMapping("/path")` → extract path as target; direction: inbound

**Endpoint registration:**
- `registry.addEndpoint("/ws")` → record the WebSocket handshake endpoint; note in report as server-side endpoint

**Edge examples:**
```yaml
- {family: streaming, protocol: stomp, type: stomp, direction: inbound, target: "/app/orders", schema_ref: null}
- {family: streaming, protocol: websocket, type: websocket, direction: inbound, target: "/ws", schema_ref: null}
```

### SseEmitter / WebFlux SSE (Java/Kotlin)

```bash
grep -rn 'SseEmitter' --include='*.java' --include='*.kt' src/
grep -rn 'Flux<ServerSentEvent\|MediaType\.TEXT_EVENT_STREAM' --include='*.java' --include='*.kt' src/
```

- `SseEmitter` in a controller method → extract the `@RequestMapping` / `@GetMapping` path of that method; direction: inbound (server emits, client subscribes)
- `Flux<ServerSentEvent<?>>` return type with `MediaType.TEXT_EVENT_STREAM` → same extraction; direction: inbound

**Edge example:**
```yaml
- {family: streaming, protocol: sse, type: sse, direction: inbound, target: "/api/events/stream", schema_ref: null}
```

### RSocket (Java/Kotlin)

**Server-side (inbound):**
```bash
grep -rn '@MessageMapping' --include='*.java' --include='*.kt' src/
grep -rn 'spring-boot-starter-rsocket' --include='pom.xml' --include='*.gradle' --include='*.gradle.kts' .
```

- When `spring-boot-starter-rsocket` is present AND `@MessageMapping` is used in a `@Controller` class (not a regular HTTP controller): record as RSocket inbound
- Extract path from `@MessageMapping("path")` as target

**Client-side (outbound):**
```bash
grep -rn 'RSocketRequester\.builder\|RSocketRequester\.connect' \
  --include='*.java' --include='*.kt' src/
```

- `RSocketRequester.builder().tcp(host, port)` or `.websocket(URI.create(...))` → extract host/URI as target; direction: outbound

**Edge examples:**
```yaml
- {family: streaming, protocol: rsocket, type: rsocket, direction: inbound, target: "fire-and-forget/orders", schema_ref: null}
- {family: streaming, protocol: rsocket, type: rsocket, direction: outbound, target: "tcp://rsocket-service:7000", schema_ref: null}
```

---

## TypeScript / JavaScript / Node.js

### Native WebSocket (TypeScript / Node.js)

**Client-side (outbound):**
```bash
grep -rn 'new WebSocket(' --include='*.ts' --include='*.tsx' --include='*.js' src/
```

- `new WebSocket(url)` → extract URL string literal as target; direction: outbound

**Server-side (inbound):**
```bash
grep -rn 'new WebSocketServer\|wss\.on(' --include='*.ts' --include='*.js' src/
```

- `new WebSocketServer({ port: N })` → record server-side listener; direction: inbound; target = `:N`
- `wss.on("connection", ...)` → confirms server-side WebSocket handler; direction: inbound

**Edge examples:**
```yaml
- {family: streaming, protocol: websocket, type: websocket, direction: outbound, target: "ws://realtime-service/events", schema_ref: null}
- {family: streaming, protocol: websocket, type: websocket, direction: inbound, target: ":8080", schema_ref: null}
```

### socket.io (TypeScript / Node.js)

**Client-side (outbound):**
```bash
grep -rn "io('" --include='*.ts' --include='*.tsx' --include='*.js' src/
grep -rn 'socket\.connect\|socket\.emit' --include='*.ts' --include='*.js' src/
```

- `io(url)` → extract URL string as target; direction: outbound

**Server-side (inbound):**
```bash
grep -rn 'new Server(\|io\.on(' --include='*.ts' --include='*.js' src/
grep -rn "socket\.on('" --include='*.ts' --include='*.js' src/
```

- `new Server(httpServer)` + `io.on("connection", ...)` → server-side socket.io; direction: inbound
- `socket.on(event, ...)` → extract event name literals for the set of handled events

**Edge examples:**
```yaml
- {family: streaming, protocol: socketio, type: socketio, direction: outbound, target: "http://ws-service:3001", schema_ref: null}
- {family: streaming, protocol: socketio, type: socketio, direction: inbound, target: "connection", schema_ref: null}
```

### EventSource / SSE (TypeScript / Node.js)

**Client-side (outbound):**
```bash
grep -rn 'new EventSource(' --include='*.ts' --include='*.tsx' --include='*.js' src/
```

- `new EventSource(url)` → extract URL string as target; direction: outbound

**Server-side (inbound):**
```bash
grep -rn "text/event-stream\|Content-Type.*event-stream" --include='*.ts' --include='*.js' src/
```

- Express/Fastify route returning `Content-Type: text/event-stream` and writing `res.write("data: ...")` → extract the route path; direction: inbound

**Edge examples:**
```yaml
- {family: streaming, protocol: sse, type: sse, direction: outbound, target: "http://notification-service/events", schema_ref: null}
- {family: streaming, protocol: sse, type: sse, direction: inbound, target: "/api/stream/events", schema_ref: null}
```
