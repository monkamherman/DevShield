# Semgrep

The project uses the Semgrep Community Edition container `semgrep/semgrep:1.172.0`. The version is pinned by tag in the local wrapper and CI workflow documentation; upgrading it is an explicit change that must be validated.

`semgrep.yml` contains the project-owned baseline rule. It targets JavaScript and TypeScript because those are the supported application languages, while the current repository contains no application source. The rule blocks direct use of `eval` with a high-severity finding because it can execute attacker-controlled code.

Normal scans exclude `tests/security/fixtures/`, which is reserved for isolated control tests. Those fixtures are scanned directly by `tests/security/sast/run.sh` so they cannot make the normal repository scan fail while still proving detection behavior.
