# Phase 05 — Container Security

## Scope

Phase 05 introduces the first container artifact using the minimal Node.js foundation fixture in `apps/fixture/`. It is validation code, not a production application architecture. `security/container/build.sh` builds it once and `security/container/scan.sh` scans that exact local image.

The image scan uses Trivy `0.73.0` in `image --scanners vuln` mode for OS and application packages. A separate `trivy config` scan evaluates Dockerfile configuration. Vulnerability findings and misconfiguration findings remain separate in evidence and policy.

## Dockerfile baseline

The Dockerfile uses an explicit Node Alpine version tag, no `latest`, no secrets or build arguments, a small runtime context, `npm ci` from the lockfile, a healthcheck, explicit port, and the non-root `node` user. There is no multi-stage build because this fixture has no compilation step; adding one for appearance would add complexity without reducing the runtime surface. `.dockerignore` excludes source-control data, caches, reports, credentials and generated content.

A version tag is more reviewable than `latest` but is not immutable. A future phase can replace it with a verified digest and attach provenance. Runtime flags such as read-only filesystem, `no-new-privileges` and dropped capabilities belong to deployment configuration, not this image build; privileged execution is not used.

## Evidence and policy

Evidence is written to ignored `reports/trivy-container-image.json`, `reports/trivy-container-config.json` and `reports/trivy-container-metadata.json`. Metadata records repository, commit, workflow, image reference, local image ID, a registry `image_digest` only if one exists (otherwise `null`), scanner/version, timestamp and normalized findings. No digest is fabricated for an unpublished local image.

CRITICAL, HIGH and UNKNOWN image or configuration findings block as `SECURITY_FAILURE`; MEDIUM warns; LOW is informational. Build, scanner or configuration execution errors are `TOOL_FAILURE`. A failed build never creates a fake scan result. No vulnerability exceptions are configured.

## Local operation and boundaries

Run `make container-build`, `make security-container`, or `make security` (which includes Semgrep, Gitleaks, SCA and container security). The image remains local/CI-only; Harbor, GHCR, Docker Hub, signing, SBOM, provenance, OPA/Rego and runtime protection are deferred. The Trivy database is cached in `.trivy-cache/` and uses normal verified HTTPS downloads; a database failure blocks the result.

The tests cover a clean image, vulnerable isolated fixture, build failure, scanner failure, non-root execution and absence of a test secret in the image. Runtime behavior, capabilities and read-only filesystem enforcement will be tested in deployment/runtime phases.
