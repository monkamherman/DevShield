# Security pipeline

Phase 03 introduced Semgrep and Gitleaks, Phase 04 added Trivy SCA, Phase 05 added the container build/image scan, and Phase 06 adds Syft SBOM generation and artifact inventory. The container job builds one local image, scans it, generates its SBOM and correlates all evidence with the BuildKit-provided image digest.

```text
                 ┌── SAST (Semgrep) ───────┐
Pull request ────┼── Secret detection ──────┤
                 ├── SCA (Trivy) ───────────┤── Security gate
                 └── Container + SBOM ──────┘
```

The workflow runs on pull requests and pushes to `main`, uses `contents: read`, and uploads machine-readable evidence for 14 days. The container job performs `make security-container` followed by `make security-sbom`, avoiding a separate independent image build. Build, Trivy or Syft failures block the pipeline. No registry, signing, provenance, OPA/Rego or deployment is included.
