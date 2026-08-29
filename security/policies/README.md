# Security Policies

Phase 03 uses the deterministic gate in `security/run.sh` and the security workflow. OPA/Rego is intentionally deferred. The current gate treats a Semgrep or Gitleaks finding and any scanner execution error as blocking.
