# ADR-004: Trivy for Software Composition Analysis

## Status

Accepted for Phase 04.

## Decision

Use Trivy `0.73.0` in filesystem mode with only the vulnerability scanner enabled. Analyze manifests and lockfiles without installing or updating dependencies, produce JSON evidence, and evaluate it in the existing centralized security gate.

## Alternatives

OWASP Dependency-Check was considered. It is mature and useful for dependency vulnerability analysis, but adding it would duplicate the Phase 04 signal, increase database and operational maintenance, and weaken the coherent path toward Trivy container and SBOM integration. It can be reconsidered if a concrete ecosystem gap is demonstrated.

Trivy does not replace future controls. Phase 05 may use Trivy for container scanning and later phases may add Syft, signing, provenance and policy-as-code for their separate responsibilities.

## Consequences

The repository has no application manifests yet, so the initial production scan is an explicit empty graph. Both production and development dependencies will be scanned when introduced. CRITICAL/HIGH/UNKNOWN findings block; MEDIUM and LOW remain visible without blocking. Database freshness depends on network access, and scanner/database failures fail closed.
