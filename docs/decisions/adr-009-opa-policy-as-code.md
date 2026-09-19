# ADR-009: OPA/Rego as the policy decision engine

## Status

Accepted for Phase 09.

## Context

DevShield now produces independent SAST, secret, SCA, container, SBOM, registry and Cosign evidence. Shell gates establish fail-closed scanner behavior, but a versioned and environment-aware decision over the complete evidence set is required before deployment policy can be introduced.

## Decision

Use OPA/Rego `v1.20.2` as the central policy decision engine. A repository-owned normalizer converts existing evidence into a stable `policy-input.json`; Rego evaluates that input and returns deterministic `ALLOW` or `DENY`. The wrapper records policy and input hashes in `policy-decision-evidence.json`.

OPA does not execute scanners, sign artifacts or replace the existing security gate. The gate must pass before Harbor publication/signing, and OPA evaluates after the available artifact evidence is assembled.

## Alternatives considered

- Extending shell conditionals was rejected because environment rules and reasons would become difficult to review and reuse.
- Conftest was not selected as the primary engine because the project needs a general evidence decision document, not only configuration-file assertions; it may consume the same Rego later.
- Gatekeeper/admission control is deferred because no Kubernetes deployment boundary exists yet.
- A hosted policy service would add an external trust dependency and reduce local/CI reproducibility.

## Environment trust model

Development requires passing controls, a valid digest and matching SBOM but may use a local artifact without Harbor, signature or provenance. Staging and production require a trusted Harbor registry, digest-bound verified Cosign signature, explicitly trusted signer and trusted provenance linked to source commit and artifact digest.

## Security implications

The policy fails closed on missing/unknown controls, invalid digests, untrusted registries, mismatched SBOM/signature/provenance and untrusted signers. Policies and tests are versioned in Git. Trusted registry/signer configuration is explicit input and is retained in the normalized evidence.

Policy tampering remains a repository/CI integrity risk; Git review, policy hashes and CI validation reduce but do not eliminate it. A future production design should protect policy delivery and evaluate policy changes through a trusted workflow.

## Consequences

Policy decisions become deterministic, explainable and reusable across environments. The repository gains a required OPA runtime and a normalized evidence contract. Existing scanner formats remain unchanged, but the normalizer must be maintained when evidence schemas evolve.

## Future evolution

OPA may later authorize Kubernetes admission or deployment promotion. Gatekeeper, Conftest, provenance attestations and formal exception workflows are intentionally not implemented in Phase 09.
