# CI/CD

This area documents the progressive DevShield delivery pipeline. Phase 02 provides the first foundational workflow; detailed design is documented in [ci-foundation.md](ci-foundation.md).

Security scanning, artifact creation, optional Harbor publication and optional Cosign signing/verification are implemented in the dedicated security workflow. Provenance, policy verification with OPA/Rego and deployment remain deferred to later phases. A successful foundation workflow must not be interpreted as a security approval.
