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

### D6. Stop-hook input is read from stdin first, with env-var fallbacks for SDK and manual invocation (2026-06-04)

**Discovered by:** acceptance tasks 7.2–7.4 failing on craftsphere.cloud at plugin version `4.0.0-beta.9`. The hook was registered, the regex was correct, `compute-cost.sh` produced the right output on manual replay — but the marker dir `.claudboard-cost-emitted/` never existed for the workspace, proving the hook itself never ran to completion in any real session.

**Root cause:** `stop-hook.sh` resolves the session JSONL path from `$CLAUDE_SESSION_JSONL` and `$CLAUDE_CODE_SESSION_ID` env vars only, and silently `exit 0`s if both are empty. The official Claude Code Stop-hook contract (code.claude.com/docs/en/hooks.md#common-input-fields) specifies that **all hook input is delivered as a JSON object on stdin**, including a `transcript_path` field with the absolute path to the session JSONL. **No environment variables are documented.** The env-var path that the original change was tested against does not exist in production — it works for SDK invocations (where the SDK pre-populates env vars) and for manual replay (where the maintainer sets them explicitly), but Claude Code's own plugin hook runner uses stdin exclusively.

**Considered:**
- **(A) Stdin first, env-var fallbacks after** — read stdin, parse `.transcript_path`, use it if present; otherwise fall through to `$CLAUDE_SESSION_JSONL`, then to `$CLAUDE_CODE_SESSION_ID` + constructed path. Preserves backward compat with both manual-test invocation and any SDK harness that sets env vars.
- **(B) Stdin only, drop env-var paths** — cleaner one-input-channel model, but breaks the existing `tests/run.sh` fixtures that invoke the script with `CLAUDE_SESSION_JSONL=…` and would also break any downstream caller relying on the SDK-style env-var injection.
- **(C) Detect Claude-Code-vs-other-caller and branch** — over-engineered; the input-source precedence in option (A) achieves the same outcome without a brittle detector.

**Decision: Option A.** Single new line at the top of the script reads stdin into `HOOK_INPUT`; one `jq` invocation extracts `.transcript_path`. If present, it wins. If absent (manual or SDK), the existing env-var resolution runs unchanged. Backward compatibility with all existing fixtures is preserved; the production Stop-hook contract is now honoured.

**Test-suite consequence:** The existing `tests/run.sh` exercises only the env-var path, which is exactly why this bug shipped twice. Section 10 of `tasks.md` adds **stdin-mode** assertions that explicitly unset `CLAUDE_SESSION_JSONL` and `CLAUDE_CODE_SESSION_ID` (via `env -u`) and pipe `{"transcript_path":"…","hook_event_name":"Stop"}` to the script. Any future regression of the stdin path now fails CI.

### D7. The `workflow` verb joins the trigger regex (2026-06-04)

**Discovered by:** user-reported observation that `/claudboard:claudboard-workflow` produces no cost line. Investigation confirmed: the verb `workflow` was never in the regex alternation, so the hook intentionally skipped workflow invocations — but the workflow orchestrator (the skill that *generates* a `feature-workflow/`) has no other cost-emission path. The per-phase cost ticks live in the *generated* `feature-workflow`, not in the generator.

**Considered:**
- **(A) Add `workflow` to the trigger alternation** — one-word change; symmetric with the other four verbs; same Stop-hook UX for all five claudboard task commands.
- **(B) Leave workflow out and add per-phase ticks to the workflow orchestrator** — would duplicate the `cost-tick.md` machinery in two places; the workflow orchestrator is a single mostly-linear pass, not a multi-phase loop, so per-phase ticks are over-modelling.
- **(C) Treat the workflow orchestrator as an outlier and document the gap in README** — accepts the inconsistency permanently; user can't tell from the outside why analyse/generate/refresh/techdebt have cost lines and workflow doesn't.

**Decision: Option A.** The regex change is `(?:analyse|generate|refresh|techdebt|workflow)` at both call sites in `stop-hook.sh`. `compute-cost.sh --task workflow` is exercised by the new `namespaced-workflow.jsonl` fixture; if the script's `--task` arg has a fixed verb list, `workflow` is added to it.

**Consistency note:** With workflow in scope, the trigger covers every user-facing claudboard slash command. Any future `/claudboard:claudboard-<verb>` added to the dispatcher must be added to the regex in the same PR — this is now an enforced invariant via the per-verb assertions in section 10 of `tasks.md`.

## Risks / Trade-offs

- **[JSONL format drift]** Claude Code's wrapped slash-invocation format (`<command-message>…</command-name>…`) is an internal representation, not a documented public contract. A future release that switches to a different wrapper (or drops the `command-name` tag) would break the regex silently. → **Mitigation:** the new `namespaced-trigger.jsonl` fixture pins the current format. If Claude Code changes it, `tests/run.sh` fails before publish. We can broaden the regex when that happens.
- **[Dropping the `^` anchor widens false-positive surface]** A user typing `then I'll /analyse the diff` in a chat message could trigger a spurious cost line on the next Stop. → **Mitigation:** same posture as the archived design's `[Hook over-emission]` — accepted limitation, documented in README. In practice the verb list is specific enough that this rarely fires.
- **[Out-of-the-box but invisible failure]** If `hooks/hooks.json` is malformed or `${CLAUDE_PLUGIN_ROOT}` substitution silently fails, users see no cost line but no error either. → **Mitigation:** add a one-line "if no cost line appears, run `claude --debug` and check for hook errors" note to the README troubleshooting block. Also: the existing `tests/hook-run.sh` already invokes the script directly with a fixture and asserts non-empty output — that catches the script-side half. The Claude Code-side half (hook registration actually firing) is verified by the post-publish acceptance check listed in `tasks.md`.
- **[No upgrade path for existing installs]** Users on `4.0.0-beta.2` won't see the new behaviour until they update. → **Mitigation:** out-of-scope by design; documented in proposal `Impact` section.
- **[Comment-block removal loses context for source-repo work]** A contributor working directly in the source repo and wanting the cost line locally has to re-derive the manual settings.json wiring. → **Mitigation:** acceptable per scope decision #1. Source-repo maintenance work can use `claude --debug` and `compute-cost.sh` directly; the cost-summary UX is for plugin users.
- **[stdin contract drift]** (added 2026-06-04 with D6) Claude Code's documented Stop-hook input is `{transcript_path, session_id, cwd, hook_event_name, …}` as JSON on stdin. A future release that renames `transcript_path`, changes the field semantics, or moves input to a different channel would silently break the script — the `jq -r '.transcript_path // empty'` extraction would return empty and the script would fall through to the env-var path that no one populates in production. → **Mitigation:** the section 10 stdin-mode test fixtures pin the field name. If Claude Code renames it, CI fails before publish. Also: the env-var fallback chain remains intact, so any future env-var injection (e.g. by a successor SDK or harness) keeps working.
- **[Bug 3 was undetectable by the original test suite by design]** (added 2026-06-04 with D6) The original `tests/run.sh` only invoked the script with env vars set, which is exactly the path that works under manual replay but never fires in production. Two prior changes (`per-run-cost-reporting`, then this proposal as originally scoped) both passed CI and shipped broken. → **Mitigation:** section 10's `env -u` stdin-mode assertions explicitly remove the env vars before invoking the script — the *only* way to surface a stdin-path regression. A general feedback memo ("plugin hook scripts must be E2E-tested through Claude Code, not via env-var replay") has been added to memory to keep this lesson sticky across future hook work.
- **[Acceptance tasks 7.2–7.4 were unchecked when the plugin shipped]** (added 2026-06-04 with D6) The change was archived implicitly (version-bumped and merged) before the manual end-to-end verification was performed. Both bugs 3 and 4 would have surfaced in 7.2 on any real Claude Code session. → **Mitigation:** section 11 re-runs the same acceptance after sections 8–10 land. Sections 8–10 are themselves the only meaningful release gate; CI green ≠ shipped-working until 11.2 produces a marker file under `.claudboard-cost-emitted/`.
