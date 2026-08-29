# SAST and Secret Detection

## Purpose

Phase 03 introduces the first DevShield security controls: Semgrep for source-code security analysis and Gitleaks for committed-secret detection. The controls are intentionally separate from future SCA, container, SBOM, signing, provenance, DAST, WAF and runtime phases.

## Scope and configuration

Semgrep uses `security/sast/semgrep/semgrep.yml` with one explicit high-severity JavaScript/TypeScript rule for direct `eval(...)`. The baseline is deliberately narrow because the repository has no application source; it avoids enabling a broad, unjustified ruleset.

Gitleaks uses `security/secrets/gitleaks/gitleaks.toml`, extending its default rules and excluding only generated output and isolated security fixtures. The normal scan covers the repository source and does not use a broad allowlist.

## Local execution

Prerequisite: Docker must be available. No scanner is installed as a project dependency.

```bash
make security-sast
make security-secrets
make security
```

The wrappers pin Semgrep `1.172.0` and Gitleaks `8.30.1`. They create `reports/` locally, which is ignored by Git. Scanner exit code `1` means a finding; any other non-zero scanner exit means a tool/configuration failure.

## CI execution

`.github/workflows/security.yml` runs on pull requests and pushes to `main`. Semgrep and Gitleaks run in separate jobs with read-only repository permissions. The security gate executes after both jobs and blocks unless both jobs succeed. No repository secrets are exposed, including for fork pull requests.

The workflow uploads machine-readable JSON evidence for 14 days. Gitleaks runs with `--redact`; its report is therefore designed to identify findings without retaining secret values. Semgrep output can contain source context and should be treated as repository-sensitive evidence.

## Tests and failure behavior

The isolated fixtures under `tests/security/fixtures/` are not part of the normal scan path. `tests/security/sast/run.sh` verifies that the vulnerable `eval` fixture fails and the safe fixture passes. `tests/security/secrets/run.sh` verifies that the clearly fake token fixture fails and clean documentation passes. Neither fixture contains a real credential.

The deterministic gate has these outcomes:

```text
No blocking findings       → PASS
Semgrep finding            → SECURITY FAILURE
Detected secret            → SECURITY FAILURE
Scanner/tool/config error  → TOOL FAILURE
```

Both failure classes stop CI. OPA/Rego is intentionally deferred; this shell/CI gate is a temporary Phase 03 policy.

## False positives and limitations

There are no allowlisted findings in this phase. A future exception must be narrowly scoped, documented with an owner and expiry, and reviewed separately. The initial Semgrep rule is not a complete SAST program, and Gitleaks cannot prove that a repository contains no undiscovered secret; these controls are the first gate, not complete application security.
