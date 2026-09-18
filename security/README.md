# Security controls

The repository currently contains Semgrep and Gitleaks source controls, Trivy SCA and container scanning, Syft SBOM generation, artifact inventory, Harbor registry integration, Cosign digest signing/verification, OPA/Rego policy and digest-bound deployment authorization. The `security/dast/` integration adds an explicit-target OWASP ZAP baseline scan. Each control produces evidence; DAST does not replace the supply-chain controls or authorize production by itself. WAF and runtime security remain reserved for later phases.
