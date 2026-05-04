## ADDED Requirements

### Requirement: Workspace-level refresh updates all ecosystem files
When `/refresh` is run from the workspace root directory (workspace mode detected), the system SHALL re-run the cross-service graph construction and update all service repos' `ecosystem.md` files.

#### Scenario: Workspace refresh updates all ecosystem files
- **WHEN** `/refresh` is run from the workspace root AND workspace mode is detected
- **THEN** the system SHALL re-run Phase 1c (graph construction) and overwrite `ecosystem.md` in all service repos

#### Scenario: New service added since last workspace analysis
- **WHEN** a new repo directory appears at workspace level that was not in the prior analysis
- **THEN** workspace refresh SHALL flag: "New repo detected: {dir-name}. Run `/analyse` from workspace root to include it in the ecosystem graph."

### Requirement: Service-level refresh warns about stale sibling ecosystem files
When `/refresh` is run from within a single service repo (not workspace root), the system SHALL update only that service's `ecosystem.md` from its own perspective and warn that sibling files may be stale.

#### Scenario: Service-level refresh with stale warning
- **WHEN** `/refresh` is run from `order-service/` AND an `ecosystem.md` exists in the repo
- **THEN** the system SHALL update `order-service/.claude/memories/ecosystem.md` for that service's outbound changes AND display: "Ecosystem files in sibling services (user-service, notification-service) may be stale — run `/refresh` from workspace root to sync all."

#### Scenario: Service-level refresh with no workspace context
- **WHEN** `/refresh` is run from a service repo AND no sibling repos are detectable at parent level
- **THEN** the system SHALL proceed with normal service-level refresh without any ecosystem file updates or warnings
