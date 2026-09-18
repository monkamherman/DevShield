# Dynamic Application Security Testing

## Purpose

DevShield uses OWASP ZAP for a non-destructive baseline scan of an explicitly deployed HTTP/HTTPS application. DAST observes the running application's behavior; it does not replace Semgrep, Gitleaks, Trivy, SBOM, Cosign or OPA.

The current repository has no application runtime or deployment manifests. The supported integration point is therefore:

```text
deployment authorization
        ↓
explicit test target
        ↓
ZAP baseline scan
        ↓
JSON + HTML reports
        ↓
DAST evidence
```

## Version and execution

The pinned image is `zaproxy/zap-stable:2.15.0`. `make dast-version` displays the selected image and version. The normal runner executes `zap-baseline.py` in Docker with host networking and a mounted report directory. It uses no `latest` tag and does not download arbitrary scripts.

```bash
make dast-version
make dast-run TARGET_URL=http://127.0.0.1:8080 DAST_ENVIRONMENT=staging DAST_ALLOWED_HOSTS=127.0.0.1
```

The target, environment and allowed host are explicit. By default only `localhost`, `127.0.0.1` and `::1` are allowed. A staging hostname must be explicitly supplied through `DAST_ALLOWED_HOSTS`; arbitrary external targets are rejected.

TLS certificate errors are not ignored. Target validation distinguishes malformed configuration (`4`), unreachable/timeout (`3`) and scanner/tool failure (`2`).

## Baseline policy

The baseline scan is non-destructive. The initial severity policy is:

| ZAP risk | DAST result |
|---|---|
| High | `SECURITY_FAILURE` and exit `1` |
| Medium | warning in evidence; no blocking result |
| Low | informational |
| Informational | informational |

Missing reports, invalid JSON or an unavailable ZAP runner are `TOOL_FAILURE` and never become `PASS`.

## Reports and evidence

Each run writes `reports/dast/zap-report.json`, `zap-report.html` and `dast-evidence.json`. Evidence records the target, environment, optional artifact reference, scanner/version, timestamps, severity counts, findings, report paths and a SHA-256 hash of the JSON report.

`validate-evidence.sh` recalculates the report hash and finding counts. This detects a changed report or an evidence count/status inconsistent with the report. The evidence is not a cryptographic authorization token; future signing or attestation of evidence must be designed explicitly.

## CI

The GitHub Actions DAST job is opt-in with `DEVSHIELD_DAST_ENABLED=true`, runs only after deployment authorization, and requires `DEVSHIELD_DAST_TARGET_URL` and `DEVSHIELD_DAST_ALLOWED_HOSTS`. It does not deploy an application itself. A future test-deployment job must deploy the authorized digest before this job runs.

Pull requests do not receive access to a staging target through this workflow. Production active scanning, authenticated scanning and API scanning are not enabled.

## OPA and future extensions

The OPA normalizer exposes an optional `security.dast` object containing status and severity counts when `dast-evidence.json` exists. DAST evidence can therefore be consumed by a future deployment/staging policy without duplicating the scanner. This phase does not change the existing artifact authorization policy because DAST runs after test deployment.

Future work may add ZAP contexts, authenticated scans, OpenAPI/API scans and explicit, reviewed finding suppressions. Credentials must come from secure CI secret mechanisms and must never appear in reports, logs or evidence.

DAST is not a proof that an image is safe, and a DAST pass does not override failures in the supply-chain controls.
