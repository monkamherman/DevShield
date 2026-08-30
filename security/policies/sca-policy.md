# Phase 04 SCA Policy

| Severity | Action |
| --- | --- |
| CRITICAL | `SECURITY_FAILURE`, blocks CI |
| HIGH | `SECURITY_FAILURE`, blocks CI |
| MEDIUM | `WARN`, pass with evidence |
| LOW | Informational, pass |
| UNKNOWN | `SECURITY_FAILURE`, fail closed |

Evidence distinguishes a `fixed_version` from a vulnerability with no known fix. No exceptions are configured in Phase 04. Future exceptions must identify vulnerability ID, package, reason, risk assessment, owner and expiration/review date.
