## Context

The archived `per-run-cost-reporting` change (2026-05-31) introduced `stop-hook.sh` and `compute-cost.sh` with the explicit non-goal "auto-install the hook for plugin users" (called out as `[Hook installation friction]` in that design's Risks). At the time, Claude Code's plugin hook-registration mechanism (`hooks/hooks.json` at the plugin root, resolved via `${CLAUDE_PLUGIN_ROOT}`) was either undocumented or not yet relied on; the change shipped with a manual settings-edit workflow documented as a comment block in the script.

Six months on, two facts have changed the calculus:
1. The `hooks/hooks.json` plugin-registration mechanism is the canonical, documented path for plugins to ship Stop hooks (confirmed against current Claude Code plugin documentation).
2. The plugin-namespaced slash form (`/claudboard:claudboard-analyse`) is the only form plugin users actually type. The bare form (`/analyse`) only fires inside the source repo where claudboard's own SKILL.md files take precedence — a setup that exists only on the maintainer's machine.

So the hook today is, in effect, dead code for every installed-plugin user. This change makes it live.

## Goals / Non-Goals

**Goals:**
- The cost line appears at the end of every `/claudboard:claudboard-{analyse,generate,refresh,techdebt}` task on a clean plugin install, with no user-side configuration.
- Both the bare and plugin-namespaced slash forms are matched by the trigger regex (no behavior regression for any contributor who continues to invoke the bare form locally).
- Test coverage pins the regex against the actual JSONL string format Claude Code records for plugin invocations — so a future Claude Code update that changes that format fails CI loudly instead of silently breaking the hook.

**Non-Goals:**
- Source-repo invocation parity (the maintainer can run `/analyse` directly, but the plugin is not intended to run from the source repo — explicitly out per user direction).
- Backporting hook auto-registration to already-installed plugin versions (`4.0.0-beta.2` and earlier). The hook arrives in the next published version; older installs stay as-is.
- Any change to cost computation (`compute-cost.sh`), pricing tables, or the per-phase feature-workflow tick path.
- Auto-suggesting hook installation when claudboard runs (the previous change deferred this as a UX concern; with auto-install via `hooks/hooks.json` the question becomes moot).

## Decisions

### D1. Use `hooks/hooks.json` for plugin-level registration, not a `hooks` field in `plugin.json`

**Considered:**
- **(A) `hooks/hooks.json` at plugin root** — canonical, documented plugin-spec mechanism. `${CLAUDE_PLUGIN_ROOT}` resolves to the plugin's installed path at hook-fire time.
- **(B) `hooks` field inside `plugin.json`** — convenient single file, but not part of the plugin manifest spec; Claude Code ignores hook entries here.
- **(C) Ship a one-shot installer script that edits the user's `.claude/settings.json` on first run** — heavy, requires Skill/script invocation discipline at runtime, and inverts the plugin model (plugins should not mutate user-global config).

**Decision: Option A.** Single file, well-known location, zero install friction, survives plugin updates automatically. The `${CLAUDE_PLUGIN_ROOT}` variable handles the version-pinned install path (`~/.claude/plugins/cache/claudboard/claudboard/<version>/…`) so we don't hardcode anything machine-specific.

### D2. Single regex covers both bare and namespaced trigger forms; `$TRIGGER_CMD` normalised to the bare verb

**Considered:**
- **(A) One regex with optional namespace prefix** — `/(?:claudboard:claudboard-)?(?:analyse|generate|refresh|techdebt)\b`. Capture group on the verb only.
- **(B) Two separate regexes evaluated in sequence** — clearer at first read but duplicates the verb alternation and doubles the maintenance surface.
- **(C) Strip the namespace prefix as a pre-processing step before matching** — extra shell pipeline; harder to reason about edge cases.

**Decision: Option A.** Simple, single grep, capture group extracts the bare verb directly via `jq`'s `capture()` — which is already how the existing script captures the cmd name (`stop-hook.sh:52`). Normalising to the bare verb means `compute-cost.sh --task "$TRIGGER_CMD"` receives the same value regardless of how the user typed it, so the downstream cost-emission path is identical for both forms.

### D3. The new JSONL fixture mirrors the real plugin-invocation shape, not a synthesised one

The existing `single-task-opus.jsonl` fixture stores the trigger as a literal `/analyse` user-turn string. The plugin form, as observed in live JSONLs (see `~/.claude/projects/-Users-LUP1BG-…/*.jsonl`), is wrapped:

```
<command-message>claudboard-analyse</command-message>
<command-name>/claudboard:claudboard-analyse</command-name>
<command-args>...</command-args>
```

**Decision:** the new `namespaced-trigger.jsonl` fixture stores this exact wrapped shape — not a hand-cleaned `/claudboard:claudboard-analyse` bare string — so the regex is exercised against what users actually generate. The regex's `^[[:space:]]*/(?:…)\b` anchor is loose enough to match `/claudboard:claudboard-analyse` inside the `<command-name>` tag content because the existing `jq` pipeline extracts `.message.content[0].text` and the text begins with the `<command-message>` wrapper — meaning the anchor must allow the regex to fire on the embedded `<command-name>/…</command-name>` substring, not just at string start.

There's a subtlety here: the existing regex uses `^[[:space:]]*/…` (anchored at line start). Plugin invocations have the `<command-name>` tag on a non-first line of the wrapped content. The fix needs the regex to use `test()` without an anchor — i.e. match anywhere in the text — OR to match the `<command-name>` tag form explicitly. **The implementation will drop the `^[[:space:]]*` anchor and rely on the verb-list specificity to avoid false positives** (a user typing `the /analyse command…` in chat would still match, but that's the same false-positive surface the original change accepted and documented as `[Hook over-emission]`).

### D4. Remove the manual-install comment block from `stop-hook.sh`, not just deprecate it

The block on lines 12-18 documents an install path that, post-change, is unsupported (per scope decision #1 from the explore session: source-repo invocation is dropped). Leaving stale install instructions in the script invites a contributor to "fix" the auto-install path back to the manual one. Cleaner to delete outright and reference the README for any remaining docs.

### D5. README update is additive, not replacing the prior cost-reporting section wholesale

The README block introduced by the archived per-run-cost-reporting change has correct context about *what* the cost line means and *when* it fires. The new content replaces only the "Installation" subsection with "Automatic — plugin installs activate the hook on install/update" and leaves the explanation and example output line intact.

## Risks / Trade-offs

- **[JSONL format drift]** Claude Code's wrapped slash-invocation format (`<command-message>…</command-name>…`) is an internal representation, not a documented public contract. A future release that switches to a different wrapper (or drops the `command-name` tag) would break the regex silently. → **Mitigation:** the new `namespaced-trigger.jsonl` fixture pins the current format. If Claude Code changes it, `tests/run.sh` fails before publish. We can broaden the regex when that happens.
- **[Dropping the `^` anchor widens false-positive surface]** A user typing `then I'll /analyse the diff` in a chat message could trigger a spurious cost line on the next Stop. → **Mitigation:** same posture as the archived design's `[Hook over-emission]` — accepted limitation, documented in README. In practice the verb list is specific enough that this rarely fires.
- **[Out-of-the-box but invisible failure]** If `hooks/hooks.json` is malformed or `${CLAUDE_PLUGIN_ROOT}` substitution silently fails, users see no cost line but no error either. → **Mitigation:** add a one-line "if no cost line appears, run `claude --debug` and check for hook errors" note to the README troubleshooting block. Also: the existing `tests/hook-run.sh` already invokes the script directly with a fixture and asserts non-empty output — that catches the script-side half. The Claude Code-side half (hook registration actually firing) is verified by the post-publish acceptance check listed in `tasks.md`.
- **[No upgrade path for existing installs]** Users on `4.0.0-beta.2` won't see the new behaviour until they update. → **Mitigation:** out-of-scope by design; documented in proposal `Impact` section.
- **[Comment-block removal loses context for source-repo work]** A contributor working directly in the source repo and wanting the cost line locally has to re-derive the manual settings.json wiring. → **Mitigation:** acceptable per scope decision #1. Source-repo maintenance work can use `claude --debug` and `compute-cost.sh` directly; the cost-summary UX is for plugin users.
