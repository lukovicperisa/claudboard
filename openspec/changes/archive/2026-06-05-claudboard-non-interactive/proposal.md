## Why

`/claudboard:claudboard-analyse` blocks mid-run with three sequential confirmation prompts (right-level step-up, topology review, cross-service graph review) even when the user explicitly invoked the slash command. New users without a pre-populated permission allowlist also hit 20+ Bash/Read/Write permission prompts in a single run. Both behaviours make a workflow that is meant to run unattended unbearable to use — confirmed by user feedback on 2026-06-04 after a repeat run against `craftsphere.cloud`.

## What Changes

- **BREAKING — Phase 1a Step 0 removed.** The "right-level check" prompt (`Analyse at ecosystem level for cross-service dependency mapping? [y/n]`) is deleted entirely. No prompt, no auto step-up. The user is responsible for invoking `/analyse` at the correct level.
- **NEW** — `skills/claudboard/SKILL.md` (dispatcher) gains a "Where to run /analyse" section that documents the three modes: single repo → run inside the repo; monorepo → run at repo root; workspace → run at the workspace directory (the parent that holds only related repos).
- **MODIFIED** — Phase 1a Step 3 (topology confirmation) changes from "wait for confirmation" to "print and proceed". The detected topology is reported to the console; no input is requested.
- **MODIFIED** — Phase 1i Step 4 (cross-service graph review) changes from "wait for confirmation" to "print and proceed". The graph, coupling classifications, and warnings are reported; no input is requested.
- **MODIFIED** — Phase 2 ambiguity prompt (line 515 of `claudboard-analyse/SKILL.md`) is retained but its trigger is tightened: it MUST only fire when a convention split is at near-parity (40–60% per variant) on a high-impact dimension (DI style, error handling, logging framework). Routine per-module variation MUST NOT trigger it.
- **NEW** — `skills/claudboard/references/recommended-permissions.json` ships a curated allowlist of Bash/Read/Write patterns that claudboard's read-only analysis pipeline needs.
- **NEW** — Dispatcher (`skills/claudboard/SKILL.md`) detects on first invocation whether the recommended permissions are already present in `.claude/settings.json`; if not, it offers a single auto-merge prompt ("I'll add these to .claude/settings.json so you don't get 20 prompts per run — ok?"). One yes/no replaces the firehose. If declined, a copy-paste fallback is printed once and the decision is remembered (no re-asking on subsequent runs).

## Capabilities

### New Capabilities
- `recommended-permissions`: Curated allowlist of Bash/Read/Write patterns required by claudboard's read-only pipeline, plus the one-shot auto-merge offer that installs them into `.claude/settings.json`.
- `invocation-guidance`: Documentation contract in the dispatcher SKILL.md that tells users where to run `/analyse` for each topology (single repo / monorepo / workspace) — replaces the removed right-level prompt.

### Modified Capabilities
- `right-level-check`: The interactive step-up prompt is removed. The capability becomes a documentation-only contract: detect the situation, surface it once in the topology report header (e.g. "sibling build files detected — if you meant to analyse the parent workspace, re-run from there"), but never block.
- `monorepo-detection`: The "wait for user to confirm or correct misclassifications" step is replaced with "print topology, proceed". Service/library classifications are still printed but no confirmation is required.
- `cross-service-graph`: The "wait for user confirmation (or corrections)" step on the graph review is replaced with "print graph + warnings, proceed". Coupling warnings remain prominent in the printed output.

## Impact

**Affected files:**
- `skills/claudboard-analyse/SKILL.md` — Phase 1a Step 0 removed; Step 3 and Phase 1i Step 4 reworded from "wait" to "print and proceed"; Phase 2 ambiguity trigger tightened.
- `skills/claudboard/SKILL.md` — adds "Where to run /analyse" guidance section and the recommended-permissions auto-merge flow on first invocation.
- `skills/claudboard/references/recommended-permissions.json` — new file.
- `skills/claudboard/references/where-to-run.md` — new file (optional; could be inlined in dispatcher SKILL.md — design.md decides).
- `openspec/specs/right-level-check/spec.md`, `openspec/specs/monorepo-detection/spec.md`, `openspec/specs/cross-service-graph/spec.md` — delta updates per the spec rewrites above.

**User-facing behaviour changes:**
- Users running `/analyse` from a "wrong" level (e.g. inside one of many sibling service repos when they meant the workspace) no longer get a step-up prompt; they get a one-line hint in the topology report and must re-run from the right level if needed.
- Catalog regeneration becomes the recovery mechanism for "I ran it at the wrong level" — acceptable because the catalog write is fast (<2s) and idempotent.

**Backwards compatibility:**
- The removed prompts are interactive only; no on-disk artifact format changes. Existing catalogs and reports remain valid.
- The recommended-permissions auto-merge is opt-in via the one prompt; users who decline keep the existing 20-prompt-per-run experience and can copy-paste later.

**Out of scope (deferred to future changes):**
- `/generate`, `/refresh`, `/techdebt` non-interactivity — same problem class but separate skills with their own prompt sites; addressed individually.
- Removing the Phase 2 ambiguity prompt entirely — still legitimately needed for genuine 50/50 splits.
- Auto-detection of the "right level" with auto-stepup — explicitly rejected; documentation is the contract.
