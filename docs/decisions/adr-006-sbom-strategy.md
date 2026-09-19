# ADR-006: Syft CycloneDX SBOM from the final image

## Status

Accepted for Phase 06.

## Decision

Use Syft `1.51.0` as the sole SBOM generator and CycloneDX JSON as the canonical format. Generate from the final container image, validate the result, and correlate it with the BuildKit image digest in a separate artifact inventory.

## Rationale and alternatives

Syft provides broad OS and language-package inventory and has a practical container-image workflow. CycloneDX JSON is machine-readable, interoperable with vulnerability and future policy tooling, and suitable for later registry/attestation integration. SPDX remains a useful interoperability alternative but is not generated in this phase to avoid two competing canonical outputs.

Trivy SBOM generation was considered, but Trivy is already the vulnerability scanner in Phases 04–05; assigning inventory to Syft keeps “what is present” separate from “what was found vulnerable.” CycloneDX-specific tooling was also considered, but it would add redundant generation and maintenance.

The SBOM is generated from the final image rather than source because the image can contain OS/runtime components and pruning differences. BuildKit supplies the digest; a Git SHA is never substituted. Signing, provenance and attestations are deferred because an SBOM is an observation, not proof of origin or integrity.

## Consequences

The local build must produce BuildKit metadata and a valid digest. Syft/database/tool failures, invalid/empty SBOMs and missing identity fail closed. Reports are ephemeral CI artifacts. No registry publication, signature, provenance, custom inventory service or vulnerability correlation engine is introduced.
