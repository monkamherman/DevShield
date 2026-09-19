# ADR-007: Harbor as the private artifact registry

Status: accepted for Phase 07

## Decision

Use Harbor `2.14.4`, deployed locally through its official pinned offline installer. Harbor provides OCI storage, project RBAC, audit metadata, retention and registry-side Trivy visibility in one platform that can later integrate with Cosign and a deployment policy engine.

## Alternatives

Docker Hub and GHCR are convenient hosted registries but do not provide the same self-hosted trust boundary and local control. GitLab and cloud registries are viable in environments already committed to those platforms, but add provider coupling and do not fit DevShield's current local/self-hosted architecture. Grype remains useful as an alternative scanner, but adding it would duplicate the Phase 05 Trivy signal without a demonstrated coverage gap.

## Consequences

Harbor adds operational cost: persistent storage, database, certificates, credentials, upgrades, backups and network access. The official installer is preferred over hand-written Harbor Compose because it owns the supported service topology. CI publication is optional until a reachable Harbor runner and project-scoped credentials exist. Tags remain mutable unless Harbor immutability rules are configured; digests are the artifact identity.

Harbor's scanner is complementary to the DevShield pre-push Trivy gate. SBOM, scan evidence and future signatures will all refer to the same image digest. Signing, provenance, OPA and production authorization remain future work.
