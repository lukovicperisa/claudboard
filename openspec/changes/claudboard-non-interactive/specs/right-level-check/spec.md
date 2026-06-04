## REMOVED Requirements

### Requirement: Guard against microservice-level analysis
**Reason:** Replaced by documentation-only guidance in `invocation-guidance` capability. Mid-run prompts violate the principle that the slash command IS the user's consent. Users running `/analyse` at the wrong level re-run from the correct level — the catalog regenerates in seconds.

**Migration:** Users who previously relied on the interactive step-up prompt MUST instead consult the "Where to run /analyse" section in `skills/claudboard/SKILL.md` (the dispatcher) before invocation. If they invoke from a service directory and intended workspace-level analysis, they re-run from the parent directory.

### Requirement: Show sibling details in step-up prompt
**Reason:** The step-up prompt itself is removed (see requirement above); this presentation requirement is no longer applicable.

**Migration:** None — no user-facing behaviour replaces this. The decision of where to run `/analyse` is documentation-driven.
