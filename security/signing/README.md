# Artifact signing

DevShield signs the exact Harbor image digest that passed the existing security gate. A mutable tag is never used as the trust identity.

## Cosign distribution

The local and CI wrappers use the official Cosign container image `ghcr.io/sigstore/cosign/cosign:v3.1.3`. `install.sh` runs `cosign version` inside that pinned image and fails if the expected version is not reported. The container tag is version-pinned; digest pinning remains a follow-up hardening task because the upstream release digest is not maintained in this repository yet.

## Signing models

Local development uses a Cosign key pair under `.local/cosign/`:

```bash
COSIGN_PASSWORD='use-a-secret-manager-or-shell-secret' make cosign-keygen
```

The private key is ignored and must never be committed. The public key is also kept local by default; verification requires the expected public-key path.

CI uses keyless signing only for an explicitly enabled `main` push after Harbor publication. GitHub Actions provides an OIDC token to Cosign, which obtains a Fulcio certificate and records transparency evidence in Rekor. Verification requires both the expected certificate identity and the Sigstore OIDC issuer. Pull requests never create trusted signatures.

## Flow

```text
security gate → Harbor push → immutable digest → Cosign sign → Cosign verify
```

`security/signing/cosign/sign.sh` refuses to sign without `DEVSHIELD_GATE_CONFIRMED=1`, an approved Harbor registry and an `@sha256:<digest>` reference. `verify.sh` rejects missing, invalid, wrong-digest, wrong-signer and wrong-registry cases.

The evidence file distinguishes `SIGNED` from `VERIFIED`; only the latter means that the configured trust identity was successfully checked.

## Local flow

Configure Harbor credentials using the existing variables, generate a key, then run:

```bash
COSIGN_PASSWORD='...' make cosign-keygen
make security-signing
```

The command runs the current gate, pushes the already-built image, resolves the registry digest, signs it and verifies it. It does not rebuild after the gate.

## Trust and lifecycle

The local public key is the trust root. In CI, the trusted identity is restricted to the DevShield GitHub workflow on `main` and the Sigstore token issuer. A future production trust store must support key rotation: stop trusting the compromised/retired identity, add the replacement identity, audit existing signatures and re-sign artifacts where required. Cosign does not automatically revoke a leaked private key.

Signing proves authenticity and integrity relative to the configured identity. It does not prove that an image is vulnerability-free or production-approved. Phase 09 consumes the digest, signature status, signer identity and verification state through its normalized OPA input.
