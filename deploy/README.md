# Deployment

Environment boundaries are reserved under `dev/`, `staging/` and `production/`. The repository currently has no deployment runtime or manifests. Phase 10 provides the generic `security/deployment/authorize.sh` contract: future deployment adapters must require `AUTHORIZED` for the exact `repository@sha256:<digest>` and must not fall back to a tag. Production uses the strict OPA trust policy; Kubernetes, GitOps and other runtime adapters remain future work.
