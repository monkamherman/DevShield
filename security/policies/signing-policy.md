# Phase 08 Signing Policy

The signing policy binds trust to an exact Harbor image digest. A valid signature is evidence of authenticity and integrity for the configured signer; it is not a vulnerability or deployment approval.

## Required

- the image must have passed the DevShield security gate;
- the image must be stored in the approved Harbor registry;
- the image reference must use `repository@sha256:<digest>`;
- the digest must match the artifact that was scanned and pushed;
- signing must use the pinned Cosign distribution;
- the private signing key must remain outside Git and CI logs;
- verification must check the expected public key or certificate identity and issuer;
- `VERIFIED` evidence is emitted only after Cosign verification succeeds.

## Forbidden

- signing a failed or unscanned artifact;
- signing a mutable tag as the trust identity;
- signing an image outside the approved registry;
- accepting any valid signer without an explicit trust binding;
- bypassing Harbor authentication or TLS verification;
- treating `SIGNED` as equivalent to `VERIFIED`;
- using a signature as proof that the image has no vulnerabilities.

## OPA-compatible evidence

The evidence is intentionally shaped for the future policy layer:

```text
artifact.digest
artifact.registry
artifact.signature.status
artifact.signature.identity
artifact.signature.verified
```

OPA/Rego consumes this signing evidence in Phase 09; it does not replace Cosign verification.
