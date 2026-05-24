## REMOVED Requirements

### Requirement: Phase 7 — single-ticket worklog aggregation

**Reason**: The aggregated worklog body (per-repo PR URLs + merge-order summary folded into the Jira worklog comment) produced bloated, noisy entries in Jira's worklog log view, and duplicated information that already lives in the PR descriptions. The new policy is that Jira worklog comments are a fixed terse one-line label only (enforced by the `tracker-backends` capability's MODIFIED "Jira backend full-flow capability set" requirement) regardless of single-repo vs multi-repo mode.

**Migration**: The single-ticket-per-feature invariant is preserved (the orchestrator still creates exactly one Jira ticket per feature, and that ticket still receives the worklog entries from Phase 1 and Phase 6/7). What changes is the worklog comment body: it is now `"Requirement refinement work"` (Phase 1) or `"Implementation work"` (Phase 6/7) in both single-repo and multi-repo runs. Per-repo PR URLs are accessible via the PR descriptions on the host (Azure DevOps / GitHub). The "Recommended merge order" remains in the orchestrator's final report to the user (see the existing "Phase 6 — parallel PR creation with merge-order recommendation" requirement) and SHALL NOT be re-posted into Jira. No data is lost; it simply lives in the appropriate surface.
