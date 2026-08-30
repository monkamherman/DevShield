# Software Composition Analysis

DevShield uses Trivy for dependency vulnerability analysis. It runs in filesystem mode with only the `vuln` scanner enabled; container, OS, IaC and SBOM scanning are reserved for later phases.

Run `make security-sca`. The wrapper scans dependency manifests and lockfiles when present, writes JSON evidence to `reports/`, and fails closed when Trivy cannot produce a trustworthy result.
