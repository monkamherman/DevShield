# Security controls

The repository currently contains Semgrep and Gitleaks source controls, Trivy SCA and container scanning, Syft SBOM generation, artifact inventory, Harbor registry integration, Cosign digest signing/verification, OPA/Rego policy, digest-bound deployment authorization, explicit-target OWASP ZAP baseline DAST and a Coraza/OWASP CRS WAF wrapper. Each control produces evidence; DAST and WAF do not replace the supply-chain controls or authorize production by themselves. Runtime security remains reserved for a later phase.
