# Security Policies

The current pipeline uses the deterministic gate in `security/run.sh` and the security workflow. Semgrep, Gitleaks, Trivy SCA, container scanning and SBOM validation are blocking controls; findings and scanner or tooling errors fail the gate. Harbor publication is allowed only after that gate succeeds. OPA/Rego is intentionally deferred.
