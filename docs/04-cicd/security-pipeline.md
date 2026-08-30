# Security pipeline

Phase 03 introduced separate Semgrep and Gitleaks jobs with a centralized fail-closed gate. Phase 04 adds a third independent job for Trivy SCA; the gate now requires all three jobs to succeed.

```text
                 ┌── SAST (Semgrep) ───────┐
Pull request ────┼── Secret detection ──────┼── Security gate
                 └── SCA (Trivy) ───────────┘
```

The workflow runs on pull requests and pushes to `main`, uses `contents: read`, and uploads machine-readable evidence for 14 days. Trivy runs only vulnerability scanning in filesystem mode. Its database/tool errors and blocking CRITICAL, HIGH or UNKNOWN findings fail the pipeline. MEDIUM and LOW findings remain visible without blocking according to the Phase 04 policy.

No container scanning, SBOM generation, signing, provenance, OPA/Rego policy or deployment is included in this phase.
