# SAST

DevShield uses Semgrep for source-code security analysis. The initial configuration is intentionally small and explicit because the repository currently has no application code. It scans repository source while excluding VCS data, generated output and isolated security fixtures.

Run locally with `make security-sast`. Semgrep findings and scanner errors both fail the command; the wrapper records `SECURITY_FAILURE` for findings and `TOOL_FAILURE` for execution errors.

The wrapper sets `HOME=/tmp` inside the container. GitHub Actions can run the
container with a numeric non-root UID, for which Semgrep otherwise resolves its
user log directory to `/.semgrep` and fails with a permissions error before the
scan starts. The temporary location is writable and does not alter scan policy.
