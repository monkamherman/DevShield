# Security Policies

The current pipeline uses the deterministic gate in `security/run.sh` and the security workflow. Semgrep, Gitleaks, Trivy SCA, container scanning and SBOM validation are blocking controls; findings and scanner or tooling errors fail the gate. OPA/Rego then evaluates normalized evidence and emits an `ALLOW` or `DENY` decision. Harbor publication and Cosign signing remain upstream trust steps; OPA does not sign or replace them.
