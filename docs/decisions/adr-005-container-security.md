# ADR-005: Docker BuildKit and Trivy for Container Security

## Status

Accepted for Phase 05.

## Decision

Use Docker BuildKit for the local/CI image build and Trivy `0.73.0` for image vulnerability and Dockerfile configuration scanning. Build once, scan that image, emit JSON evidence and evaluate it in the existing centralized gate.

## Alternatives

Grype was considered as another image vulnerability scanner. It has strong ecosystem support and can be useful with Syft SBOMs, but adding it now would duplicate Trivy's Phase 04 vulnerability signal and increase operational complexity. Trivy already supplies the dependency control and has a coherent path toward the future container and SBOM phases. Grype may only be introduced after a concrete coverage gap and an explicit architectural decision.

## Consequences and limits

The current artifact is a foundation Node.js fixture because no application exists. The base image uses a version tag rather than a digest; this is explicit but not immutable and is scheduled for future digest/provenance enforcement. The image is not published, signed or attested. Trivy database freshness depends on network access, and all build/scanner failures are fail-closed. Runtime security, registry, SBOM, signing and provenance remain separate phases.
