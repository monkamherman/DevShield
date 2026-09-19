# Secret Detection

DevShield uses Gitleaks to detect credentials and tokens committed to the repository. Reports are redacted and isolated control fixtures are excluded from the normal scan only so that they can be tested separately.

Run locally with `make security-secrets`. A detected secret returns `SECURITY_FAILURE`; scanner or configuration errors return `TOOL_FAILURE`.
