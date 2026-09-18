# Security controls

The repository currently contains Semgrep and Gitleaks source controls, Trivy SCA and container scanning, Syft SBOM generation, artifact inventory, Harbor registry integration, Cosign digest signing/verification, OPA/Rego policy, digest-bound deployment authorization, explicit-target OWASP ZAP baseline DAST, a Coraza/OWASP CRS WAF wrapper and a Docker-oriented Falco runtime detector. Each control produces evidence; DAST, WAF and Falco do not replace the supply-chain controls or authorize production by themselves.

Phase 14 adds `security/observability/logger.sh`, a dependency-free structured security event writer. It validates and redacts events before appending one JSON object per line to `reports/logs/security-events.jsonl`. Existing component evidence remains authoritative; automatic hooks can be added without changing decisions. External collection is deliberately not embedded; see [the observability contract](../docs/04-cicd/observability.md).
