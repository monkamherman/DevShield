# Security pipeline

Phase 03 introduced Semgrep and Gitleaks, Phase 04 added Trivy SCA, Phase 05 added the container build/image scan, Phase 06 added Syft SBOM generation and artifact inventory, Phase 07 added optional Harbor publication, and Phase 08 added Cosign signing and verification after digest resolution. The container job builds one local image, scans it, generates its SBOM and correlates all evidence with the BuildKit-provided image digest.

```text
                 ┌── SAST (Semgrep) ───────┐
Pull request ────┼── Secret detection ──────┤
                 ├── SCA (Trivy) ───────────┤── Security gate
                 └── Container + SBOM ──────┘
```

The workflow runs on pull requests and pushes to `main`, uses `contents: read`, and uploads machine-readable evidence for 14 days. The container job performs `make security-container` followed by `make security-sbom`, avoiding a separate independent image build. Build, Trivy or Syft failures block the pipeline. Harbor publication is optional, requires a self-hosted runner and project-scoped credentials, and never rebuilds the gated image. Cosign signing is additionally optional, restricted to trusted pushes on `main`, and verified against the expected GitHub OIDC identity. The OPA policy job evaluates normalized evidence after the security gate and records an `ALLOW` or `DENY`; the Phase 10 authorization contract re-evaluates that policy for an exact immutable digest. The authorization job is opt-in through `DEVSHIELD_DEPLOYMENT_ENABLED` and push-only because no deployment executor exists yet. The Phase 11 ZAP baseline job is separately opt-in through `DEVSHIELD_DAST_ENABLED`, requires an explicitly allowlisted target and runs only after authorization. A future deploy job must precede DAST and use the exact authorized reference.
