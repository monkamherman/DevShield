# Phase 06 — SBOM

An SBOM answers what was observed inside an artifact; it is not proof that the artifact is authentic or came from a trusted builder. DevShield generates the canonical CycloneDX JSON SBOM from the final local container image, not from source files, using Syft `1.51.0`. Syft runs in a pinned container image and reads the local Docker daemon.

The flow is `BuildKit → image → BuildKit image digest → Syft → CycloneDX SBOM → validation → artifact inventory`. The SBOM is then annotated with the digest obtained from BuildKit; inventory generation rejects a missing or mismatched digest. Trivy remains a separate vulnerability evidence producer for the same image identity.

Validation requires non-empty valid JSON, CycloneDX format/version, generator metadata and components. Syft failure, missing digest, empty/corrupt SBOM or failed validation is `TOOL_FAILURE`; a digest mismatch is an integrity `SECURITY_FAILURE`. Reports are temporary CI artifacts under ignored `reports/`, not committed. No cache or report contains credentials.

Run locally after a build with `make container-build`, then `make sbom`, `make sbom-validate`, `make artifact-inventory`, or `make security-sbom`. `make security` includes the complete gate. The current application is a foundation fixture; its inventory describes the actual image, including OS/runtime packages, rather than claiming to represent a future application.
