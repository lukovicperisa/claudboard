## Context

`/claudboard:claudboard-analyse` is designed to run unattended: discover the topology, fan out to discovery scripts, synthesise a catalog, write artifacts, done. In practice three "wait for user" inserts and a Bash/Read/Write permission firehose stop it dead.

The user explicitly invoked the slash command. Each subsequent prompt re-asks a question the slash command already answered ("yes, I want this") and forces the user to babysit a multi-minute pipeline. On a fresh machine without a populated `.claude/settings.json`, the permission prompts are worse — every `find`, every `bash scripts/discover.sh`, every `mkdir -p`, every `Write` call requires a separate yes/no.

Both pain points are tightly coupled to a single principle the skill is currently violating: **the slash command is the consent**. Removing one source of friction without the other still leaves the user clicking yes every 30 seconds.

The fix is mechanical: delete the prompts and ship a default allowlist. The hard part is choosing how aggressive to be (auto-merge settings.json vs document-and-let-user-copy), how to remember the user's choice across runs, and what to do when the user really did invoke `/analyse` from the wrong level.

## Goals / Non-Goals

**Goals:**
- `/claudboard:claudboard-analyse` runs end-to-end with zero prompts in the happy path (correct level, recommended-permissions already merged).
- New users see exactly one prompt on first run (the recommended-permissions offer). Decline once → no re-asking.
- Misclassifications and wrong-level invocations are surfaced visibly in the report output, never as blocking prompts.
- The dispatcher SKILL.md tells users where to run `/analyse` for each topology before they ever invoke it.

**Non-Goals:**
- Auto-detecting and silently stepping up to a parent workspace. Explicitly rejected — the user said "if users are aware where they should run it, the question isn't needed". Documentation is the contract; we do not second-guess the path.
- Removing the Phase 2 ambiguity prompt entirely. Genuine 40–60% splits on high-impact dimensions are a legitimate ask and the user did not ask to kill them.
- Touching `/generate`, `/refresh`, or `/techdebt`. Same problem class, separate skills, separate proposals.
- A persistent "skip all confirmations forever" flag. Not needed — once the prompts are gone, there is nothing to skip.

## Decisions

### D1. Right-level check is deleted, not silenced

**Decision:** Remove Phase 1a Step 0 from `skills/claudboard-analyse/SKILL.md` entirely. Delete the prompt logic, the sibling-stack detection that feeds it, and the step-up branch. Do not replace it with a print-and-proceed equivalent — there is nothing useful to print.

**Alternatives considered:**
- *Print + proceed* (e.g. "Sibling build files detected at `../`. If you meant to analyse the parent workspace, re-run from there."): rejected because it adds noise to every monorepo-inside-a-folder run, and the user explicitly said they want it gone. The "Where to run /analyse" docs section covers the same advice once, up front.
- *Auto step-up*: rejected — silently changing CWD is worse than asking. The user must consciously pick the level.
- *Add a `--no-step-up` flag*: rejected — defaulting to noisy and asking the user to opt out of noise is the wrong default.

**Rationale:** The user said "if users are aware where they should run it" the prompt is unnecessary. Documentation, not interaction, is the right surface for that awareness.

### D2. Topology and graph reviews print, never wait

**Decision:** Phase 1a Step 3 and Phase 1i Step 4 both change from `Wait for user to confirm...` to `Print the detected topology/graph and proceed immediately`. The printed output keeps the same content (service/library list with detected stacks; graph edges, coupling, warnings) but the workflow does not block.

If the user spots a misclassification or graph error, the recovery path is: edit `.claudboard/catalog.json` (it is plain JSON) or re-run `/analyse`. Both are documented at the end of the printed topology block.

**Alternatives considered:**
- *Print with a 3-second grace window, Ctrl-C to cancel*: rejected. Still blocks unattended runs, still surprises CI, and a 3-second timer is too short to actually read anything useful.
- *Print + always-on `--review` flag for users who want the prompt*: rejected as YAGNI; users who want to review will read the printed output and Ctrl-C if they disagree. Re-running is cheap.
- *Print + write a `.claudboard/topology-review.md` for users to edit before `/generate`*: rejected — adds an artifact that exists only to be deleted; users who want this can edit `catalog.json` directly.

**Rationale:** These reviews almost never produce corrections in practice. They cost a blocking interaction every run for a recovery action that is needed once a year. Re-running `/analyse` is the right escape hatch.

### D3. Phase 2 ambiguity prompt trigger is tightened, not removed

**Decision:** The Phase 2 "ask the user now" path stays, but only fires when:
- A convention is split at 40–60% per variant (near-parity), AND
- The convention is on a high-impact dimension: DI style (constructor vs field), error-handling strategy (exceptions vs Result types), logging framework, test framework.

Lower-impact dimensions (naming variations across modules, formatting choices) MUST NOT trigger it — they are recorded as "predominant: X, also seen: Y, Z" in the catalog.

**Alternatives considered:**
- *Remove entirely and pick the predominant*: rejected because a true 50/50 split has no predominant; picking arbitrarily writes wrong rules.
- *Always pick first-seen*: rejected for the same reason.

**Rationale:** The user said "I don't want those questions under any kind of circumstances" but specifically named the right-level and topology prompts as the offenders. The ambiguity prompt is rare in practice (most repos have clear majorities) and silently picking wrong on a genuine 50/50 split would write incorrect rules into CLAUDE.md, which is harder to fix than a one-time prompt.

### D4. Recommended permissions ship as a bundle + one-shot auto-merge

**Decision:**
- Ship `skills/claudboard/references/recommended-permissions.json` listing all Bash/Read/Write/Skill patterns the claudboard pipeline uses.
- On first invocation of any claudboard sub-skill (`/analyse`, `/generate`, `/refresh`, `/techdebt`, `/claudboard-workflow`), the dispatcher SKILL.md checks whether `.claude/settings.json` already contains the bundle's marker key (`"_claudboard_permissions_version": "1"`).
- If absent, show **one** prompt: `"Add claudboard's recommended permissions to .claude/settings.json? This eliminates ~20 prompts per analysis run. [y/n]"`
- On `y`: merge the allowlist into the `permissions.allow` array (preserve existing entries, dedupe), stamp the marker key, write back. Subsequent runs see the marker and skip the prompt.
- On `n`: stamp `"_claudboard_permissions_version": "1-declined"` so we do not re-ask on every run. Print the copy-paste fallback once. Subsequent runs proceed silently with the per-tool prompts.

**Alternatives considered:**
- *Auto-merge with no prompt*: rejected — writing into `.claude/settings.json` without user consent is the kind of side effect that erodes trust.
- *Document only, no auto-merge offer*: rejected — that is the status quo for users who already know about `/fewer-permission-prompts`. Most new users will never find that path; the dispatcher prompt makes the right thing the easy thing.
- *Use a separate `.claude/settings.json` namespace for plugin-managed entries*: rejected as over-engineering for v1; the marker key approach is sufficient.

**Permissions bundle scope (initial v1):**
```
Bash(find . -maxdepth * -name *:*)
Bash(bash scripts/discover.sh:*)
Bash(jq:*)
Bash(mkdir -p .claudboard:*)
Bash(mkdir -p .claude:*)
Bash(git log:*)
Bash(git branch:*)
Bash(git status:*)
Bash(grep:*)
Bash(rg:*)
Read(./**)
Write(./.claudboard/**)
Write(./.claude/reports/**)
Write(./.claude/memories/**)
Write(./.claude/rules/**)
Write(./.claude/skills/**)
Write(./CLAUDE.md)
```

**Rationale:** One yes/no replaces 20+ prompts and the marker makes the decision sticky. The user explicitly accepted auto-merge in the explore conversation.

### D5. "Where to run /analyse" guidance lives in the dispatcher SKILL.md

**Decision:** Add a short, prominent section (~10 lines) to `skills/claudboard/SKILL.md`:

```
## Where to run /analyse

  single repo  → run inside the repo
  monorepo     → run at the repo root
  workspace    → run at the workspace directory
                 (the parent folder that holds ONLY the related repos
                 — not a generic ~/Projects or ~/code folder)

If you run from the wrong level, re-run from the right one. The catalog
regenerates in seconds.
```

**Alternatives considered:**
- *Separate `references/where-to-run.md`*: rejected — adds a file to load for a 10-line answer that fits inline in the dispatcher.
- *Inline in `analyse/SKILL.md` only*: rejected — the dispatcher is loaded first and is the natural place to set expectations.

**Rationale:** Users read the dispatcher SKILL.md when they invoke any claudboard command (because the dispatcher gets loaded first). This is the highest-traffic surface for setting expectations.

## Risks / Trade-offs

| Risk | Mitigation |
|---|---|
| User runs `/analyse` from the wrong level (e.g. inside `craftsphere.cloud/services/order-service/`) and gets a single-service catalog instead of the workspace catalog | The printed topology header makes the level obvious. The dispatcher docs cover the choice up front. Recovery = re-run, cost < 60s. Acceptable. |
| Misclassification in topology is now silent (service flagged as library or vice versa) | Print the topology with stack + classification per entry. User reads it, edits catalog, or re-runs. Same recovery path as wrong-level. |
| Auto-merging into `.claude/settings.json` overwrites a user's hand-tuned permissions | Merge logic preserves all existing entries, dedupes, never deletes. Marker key version-tags the merge for future cleanups. We MUST NOT touch keys other than `permissions.allow`. |
| `.claude/settings.json` is gitignored on some setups; the marker would not persist across machines | Acceptable — each machine prompts once, then never again. Cross-machine config sharing is out of scope for this change. |
| Decline-once stamping (`1-declined`) prevents re-asking even if the bundle grows in v2 | Future bundle versions bump the version marker (`"_claudboard_permissions_version": "2"`); decline-on-v1 does not silence a v2 prompt. Documented in the design contract. |
| Phase 2 ambiguity prompt still blocks on genuine 50/50 splits | Intentional — see D3. The trigger is narrow enough that it fires rarely. |
| Removing right-level-check requirements may break tests/specs that depend on the existing behaviour | The change includes spec deltas for `right-level-check`, `monorepo-detection`, `cross-service-graph`. Implementation tasks include verifying that no other SKILL.md or reference still references the deleted step. |

## Open Questions

None — the four decisions above resolve every open question raised in explore mode. The user confirmed: (1) right-level check goes, (2) topology + graph print-only, (3) recommended allowlist is fine, (4) auto-merge with single prompt is acceptable. Implementation can proceed.
