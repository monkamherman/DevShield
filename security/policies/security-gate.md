# Security Gate — Current Baseline

The shell-based gate remains the current policy implementation until OPA/Rego is introduced. It evaluates all source, dependency, container and SBOM controls:

| Condition | Result | Pipeline action |
| --- | --- | --- |
| All controls complete with no blocking finding | `PASS` | Continue |
| Security finding in any control | `SECURITY FAILURE` | Stop |
| Scanner, Docker, SBOM or configuration error | `TOOL FAILURE` | Stop |

Each control writes machine-readable evidence and metadata, returns a non-zero status for a finding or tool error, and the `security-gate` job evaluates the control jobs. Harbor publication is a separate optional step that requires a successful gate. This policy can later be replaced or extended by centralized policy-as-code.
