# Harbor registry security

Harbor is DevShield's controlled artifact repository. It stores and distributes images, enforces project access, retains metadata and can rescan stored artifacts with its native Trivy adapter. It does not establish source trust, cryptographic authenticity or production approval yet.

The trust boundary is:

```text
build output → DevShield security gate → Harbor
```

The gate is fail-closed: SAST, Gitleaks, Trivy SCA, Trivy image/configuration scan and SBOM validation must pass before `security/registry/push.sh` pushes. Harbor is deliberately not part of ordinary `make security`, because a developer's local Harbor is not reachable from GitHub-hosted runners.

## Local deployment

The repository pins Harbor `2.14.4` and uses the official offline installer. The installer generates Harbor's supported multi-service Docker Compose topology; DevShield does not reimplement Harbor internals. `infrastructure/registry/harbor.yml.example` is an HTTPS local profile. Copy it into the official installer directory, replace paths and passwords, and create a locally trusted certificate. The installer archive is accepted only when `HARBOR_INSTALLER_SHA256` is supplied.

Run `make registry-up`, complete the official `prepare`/`install.sh` step, then `make registry-status`. No credentials are stored in Git. Internal database, Redis and scanner services are not exposed as host services.

## Identity and access

Use a Harbor project named `devshield`, with repository `fixture` for the current foundation fixture. The CI publisher receives only project-level push permission. Developers receive read-only access by default. The administrator is reserved for Harbor administration. Configure tag immutability for `sha-*` and release tags. A tag is a convenience reference; the artifact identity is `repository@sha256:<digest>`.

The same image is built and scanned before push. Harbor's Trivy scan is complementary continuous visibility, while DevShield's Trivy scan is the pre-push decision. The push evidence records Harbor repository, commit, tag and returned registry digest. The local BuildKit digest and Harbor manifest digest are distinct digest namespaces; both must be retained rather than falsely equated.

## Failure and operations

Invalid credentials are a security failure, denied RBAC operations are expected denials, and an unavailable Harbor is an infrastructure failure. None is converted into PASS. Retention must keep release artifacts and their metadata; development cleanup must not remove artifacts needed to reproduce a release. Backups eventually need registry storage, Harbor database, configuration, certificates and metadata.

Phase 07 does not add signing, provenance, OPA or deployment authorization. Cosign will attach identity to the same image digest in Phase 08.
