# ADR-008: Cosign signing and verification

## Status

Accepted for Phase 08.

## Decision

Use Cosign `v3.1.3` through the official pinned container image for OCI image signing and verification. Sign only the exact Harbor image digest after the existing DevShield security gate. Store the signature through Cosign's OCI-compatible registry mechanism so it remains associated with the Harbor artifact.

Local development uses a password-protected key pair under ignored `.local/cosign/`. Trusted CI signing uses GitHub OIDC keyless signing only on `main`, obtaining a Fulcio certificate and transparency evidence through Rekor. Verification is bound to the local public key or, in CI, the expected workflow certificate identity and Sigstore OIDC issuer.

## Alternatives

- GPG/PGP was rejected because it would introduce a separate artifact-signing trust model and weaker OCI/Sigstore integration.
- Notary was not selected because the project already uses Harbor and the Sigstore/Cosign ecosystem for OCI signatures.
- Custom signatures and SHA-256 files were rejected because a hash is not a digital signature and would duplicate cryptographic implementation.
- Permanent CI key-based signing was rejected for the initial CI path because it requires storing a long-lived private key; keyless OIDC gives the workflow a scoped identity without committing key material.

## Trust root and identity

For local signing, the explicitly selected Cosign public key is the trust root. For CI, the expected identity is the `security.yml` workflow in this repository on `main`, issued by `https://token.actions.githubusercontent.com`. Verification never accepts an arbitrary valid Cosign signer.

## Key lifecycle

Local keys are generated on demand and protected by `COSIGN_PASSWORD`; the private key is ignored and never included in evidence. Rotation requires generating a replacement, updating trusted verification material, auditing existing artifacts and re-signing artifacts that must remain trusted. A compromised key must be removed from the trust configuration immediately. Production KMS-backed key management and formal revocation are deferred.

## Consequences

The signing boundary is after scanning, SBOM generation and the security gate. The implementation cannot prove that an image is safe; it proves only that the exact digest was signed by and verified against the configured identity. OPA/Rego and deployment enforcement remain Phase 09 responsibilities.
