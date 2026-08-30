# Phase 04 — Software Composition Analysis

## Purpose

SCA analyzes direct and transitive dependencies from repository manifests and lockfiles to identify known vulnerabilities. It covers both production and development dependencies because build and test tooling can affect the software supply chain.

## Trivy strategy

DevShield uses the pinned container `aquasec/trivy:0.73.0`, selected instead of adding OWASP Dependency-Check. Trivy fits the existing container-oriented security stack and can evolve into the future container and SBOM phases without adding a second dependency scanner. This phase enables only `fs --scanners vuln`; container, OS, IaC, registry and SBOM scans are intentionally deferred.

The flow is `manifest → lockfile → resolved graph → Trivy → JSON evidence → centralized gate`. No package manager runs, no dependencies are installed, and no lockfile is regenerated. The current repository has no manifests, so the normal scan records an empty dependency result and passes explicitly.

## Database and reproducibility

Trivy obtains its vulnerability database through its standard verified HTTPS registry mechanism. Local runs cache it under `.trivy-cache/`; CI uses a fresh runner. The scanner version is pinned to `0.73.0`; updating it is an explicit change requiring validation. Failure to download, verify or use the database is `TOOL_FAILURE`, never a clean result.

## Policy and evidence

`security/policies/sca-policy.md` defines the initial policy: CRITICAL and HIGH block; MEDIUM warns; LOW is informational; UNKNOWN blocks fail-closed. Evidence includes repository, commit, workflow, scanner/version, timestamp, target, package, installed version, vulnerability ID, severity, fixed version, status and dependency path. A fixed version is distinguished from no known fix. There are no exceptions in this phase.

Reports are written to ignored `reports/trivy-sca.json` and metadata to `reports/trivy-sca-metadata.json`. They contain no credentials. The workflow runs on pull requests and pushes to `main`, with `contents: read`, and the centralized gate fails when Semgrep, Gitleaks or Trivy fails.

## Tests and limitations

`tests/security/sca/run.sh` scans isolated clean and vulnerable npm lockfile fixtures; it never changes the real dependency tree. A controlled fake-Docker test verifies that scanner execution failure produces `TOOL_FAILURE` and a non-zero exit. Medium/low behavior is represented in policy and evidence but is not forced by the initial fixtures. No automated remediation, exception approval, package installation, container scanning or SBOM generation is included.
