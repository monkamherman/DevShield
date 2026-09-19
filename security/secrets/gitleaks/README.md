# Gitleaks

The project uses the Gitleaks container `ghcr.io/gitleaks/gitleaks:v8.30.1`. The normal configuration extends the upstream default rules and adds only repository-boundary exclusions for generated output and isolated fixtures. It does not add a broad allowlist. Isolated fixture tests use `gitleaks-test.toml`, which has no fixture exclusion.

The wrapper uses `--redact` so report artifacts identify findings without retaining secret values. The isolated fake-secret fixture is scanned directly by `tests/security/secrets/run.sh` and is never included in the normal repository scan.
