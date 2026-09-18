# Security controls

The repository currently contains Semgrep and Gitleaks source controls, Trivy SCA and container scanning, Syft SBOM generation, artifact inventory and Harbor registry integration. Each security control produces evidence and is evaluated by the centralized fail-closed gate in `security/run.sh`. Signing, provenance, OPA/Rego, DAST, WAF and runtime security remain reserved for later phases.
