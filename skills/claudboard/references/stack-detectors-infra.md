# Stack Detectors: Infrastructure

Cross-language infrastructure markers detected during Phase 1c Wide Scan. These signals live here (not in any language pack) because they are relevant regardless of the application language.

## Trigger Signals

```bash
# Database migrations
find . -name 'V*__*.sql' ! -path '*/node_modules/*' 2>/dev/null | head -5    # Flyway
find . -name '*.migration.ts' ! -path '*/node_modules/*' 2>/dev/null | head -5  # TypeORM/Prisma
find . -name '*.migration.js' ! -path '*/node_modules/*' 2>/dev/null | head -5
find . -path '*/migrations/*.py' ! -path '*/.venv/*' 2>/dev/null | head -5   # Alembic / Django

# Kubernetes / Helm
find . -name 'Chart.yaml' ! -path '*/node_modules/*' 2>/dev/null | head -5
find . -maxdepth 4 -type d -name 'helm' -o -name 'charts' 2>/dev/null | head -5
find . -name 'kustomization.yaml' 2>/dev/null | head -5

# Pulumi (Infrastructure as Code)
find . -name 'Pulumi.yaml' 2>/dev/null | head -5
find . -maxdepth 3 -path '*/env/index.ts' 2>/dev/null | head -5   # Pulumi TS convention

# Terraform
find . -name '*.tf' ! -path '*/.terraform/*' 2>/dev/null | wc -l

# Docker Compose (multi-service local setup)
find . -maxdepth 3 -name 'docker-compose*.yml' 2>/dev/null | head -5
```

## What Each Signal Implies

| Signal | Implication |
|--------|-------------|
| `V*__*.sql` (Flyway) | Database schema versioned in repo; rule opportunity: migration naming convention |
| `Chart.yaml` / `helm/` | Helm-based Kubernetes deployment; rule opportunity: values.yaml conventions |
| `kustomization.yaml` | Kustomize-based Kubernetes config; note base/overlay structure |
| `Pulumi.yaml` | Pulumi IaC — note the language stack (`typescript`, `python`, `go`) from `Pulumi.yaml` |
| `*.tf` | Terraform IaC; look for backend config and workspace conventions |
| `docker-compose*.yml` | Local dev/test orchestration; note port mappings and service names for ecosystem context |

## Notes

- Infrastructure markers often cross service boundaries — find them at the repo root and in `infra/`, `deploy/`, `helm/`, `terraform/`, `env/` directories.
- If Pulumi is used, check `Pulumi.yaml` for the runtime language (it may differ from the application language).
- Helm charts expose the service's configurable surface (resources, replicas, env vars) — relevant for the quality assessment "Deploy" dimension.
- Run `discover.sh`'s `_common.sh` handles these detections via the `build_files.common` field; this file provides interpretation context for what those detections mean.
