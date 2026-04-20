# Spec: Multi-Path Trace (Step 1f)

## Overview

Expands call-path tracing from 1 path to 3-5 paths, selected based on Wide Scan results. Each path type reveals different architectural aspects.

## Requirements

### MUST

1. Trace 3 paths minimum, 5 maximum
2. Always include: simple CRUD path + complex business path
3. Select paths based on Wide Scan signals (not random)
4. For each path, read 3-4 files in the chain
5. Record per path: DI pattern, exception handling, logging, validation, reflection usage

### SHOULD

6. Include async/event path if @Async or @EventListener detected
7. Include auth path if custom auth annotations detected
8. Include external integration path if Feign/HTTP clients detected

## Path Selection Matrix

| Path Type | When to Include | Entry Point | What It Reveals |
|-----------|----------------|-------------|-----------------|
| Simple CRUD | Always | Smallest controller | Base patterns, happy path |
| Complex business | Always | Largest service method | Real complexity, edge cases |
| Async/event | @Async or @EventListener found | Async method | Error handling in async, threading |
| Auth/security | Custom auth annotations found | @Authorize controller | Security patterns, AOP usage |
| External call | @FeignClient or HTTP client found | Client interface | Resilience, error mapping, retries |

## Acceptance Criteria

- On meas.cloud.datahandler: traces (1) NoteController→NoteService→LeafCrudService→repo, (2) CanvasService complex method, (3) UserResourceUsageAsyncRecalculator, (4) @Authorize→AuthAspect flow
- Detects dual cascade path (listener + callback) as anti-pattern
- Detects reflection in CRUD hot path
