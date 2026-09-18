# Security controls

The repository currently contains Semgrep and Gitleaks source controls, Trivy SCA and container scanning, Syft SBOM generation, artifact inventory, Harbor registry integration and Cosign digest signing/verification. Each security control produces evidence and is evaluated by the centralized fail-closed gate in `security/run.sh`; signing additionally requires explicit gate confirmation. Provenance, OPA/Rego, DAST, WAF and runtime security remain reserved for later phases.
