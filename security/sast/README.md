# SAST

DevShield uses Semgrep for source-code security analysis. The initial configuration is intentionally small and explicit because the repository currently has no application code. It scans repository source while excluding VCS data, generated output and isolated security fixtures.

Run locally with `make security-sast`. Semgrep findings and scanner errors both fail the command; the wrapper records `SECURITY_FAILURE` for findings and `TOOL_FAILURE` for execution errors.
