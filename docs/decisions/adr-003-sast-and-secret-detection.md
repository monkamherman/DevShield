# ADR-003: Semgrep and Gitleaks for the First Security Gate

## Status

Accepted for Phase 03.

## Decision

Use Semgrep Community Edition for source-code security analysis and Gitleaks for committed-secret detection. Run them in separate GitHub Actions jobs and evaluate them with a small deterministic security gate.

## Alternatives considered

- SonarQube was not selected because it would duplicate the SAST responsibility assigned to Semgrep and adds operational complexity.
- Trivy and OWASP Dependency-Check were not selected because dependency/SCA scanning belongs to Phase 04.
- Hosted integrations and tool-specific actions were not selected for this initial gate because local Docker wrappers keep local and CI invocation identical and avoid requiring service tokens or write permissions.

## Strengths

- Both tools have established repository and CI usage and machine-readable output.
- Docker image versions are explicit and the same wrappers run locally and in CI.
- The tools cover distinct signals: code patterns versus committed credentials.
- Findings and tool failures are blocking and evidence is retained for review.

## Limitations

The repository has no application source, so the initial Semgrep baseline contains only one justified JavaScript/TypeScript rule. Gitleaks default rules cannot guarantee detection of every secret. Docker image tags are version-pinned but not digest-pinned yet. Neither tool provides complete application security.

## Future integration

The gate can later consume SCA, container, SBOM, provenance and policy evidence. OPA/Rego may replace or extend the temporary shell gate once the evidence model and policy requirements are sufficiently defined.
