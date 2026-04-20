# Deep Discovery: Two-Layer Detection for Claudboard

## Problem

Claudboard's discovery phase samples 3-5 source files per language and traces 1 call path. For large repos (500+ files), this means <1% code coverage. Result: missed patterns, missed anti-patterns, too few skills and rules generated. Real-world test on a 138-file Spring Boot service produced only 2 skills and 3 rules when 5+ skills and 7+ rules were warranted.

## Root Causes

1. **Sampling is random, not strategic** — no guidance on *which* files to read deeply
2. **Skill triggers require exact annotation matches** — only 13 hardcoded triggers, all from well-known frameworks. Project-specific patterns (custom annotations, base class hierarchies) invisible
3. **Anti-pattern detection bound to sampled files** — God classes, field injection, broad catches are all grep-able across entire repo but only checked in 3-5 files
4. **Single call-path trace** — picks one CRUD flow, misses async/event/error paths

## Solution: Two-Layer Discovery

**Layer 1 — Wide Scan (grep-based, reads NO full files)**
- Grep entire repo for skill triggers, anti-pattern signals, custom annotations, base class hierarchies, file size distribution
- Result: complete inventory of what exists and where

**Layer 2 — Deep Sample (targeted full file reads)**
- From Layer 1 inventory, strategically pick 15-20 files: largest files, base classes, custom annotations, best examples per detected trigger
- Trace 3-5 call paths instead of 1

## Non-Goals

- Dynamic/runtime analysis
- Full AST parsing
- Supporting languages beyond current catalog (Java, TS, Python, Go, Rust, .NET)
- Changing Phase 2 (analysis report) or Phase 3 (artifact generation) structure

## Success Criteria

- meas.cloud.datahandler produces 5+ skills, 6+ rules (vs current 2 skills, 3 rules)
- Custom CRUD hierarchy pattern detected and codified as skill
- Custom annotations (@Cascade, @Authorize) detected and documented in rules
- God class (CanvasService 609 LOC) flagged as anti-pattern
- No regression on existing eval targets (craftsphere, azure-devops-mcp, worca-cc)
