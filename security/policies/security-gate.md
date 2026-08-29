# Phase 03 Security Gate

The temporary Phase 03 gate has three outcomes:

| Condition | Result | Pipeline action |
| --- | --- | --- |
| Both scanners complete with no blocking finding | `PASS` | Continue |
| Semgrep finding or detected secret | `SECURITY FAILURE` | Stop |
| Scanner, Docker or configuration error | `TOOL FAILURE` | Stop |

The gate is implemented without OPA/Rego. Each scanner writes machine-readable evidence and metadata, returns a non-zero status for a finding or tool error, and the `security-gate` job evaluates both results. This is an intentionally small Phase 03 policy that can later be replaced or extended by centralized policy-as-code.
