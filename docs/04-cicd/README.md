# CI/CD

This area documents the progressive DevShield delivery pipeline. Phase 02 provides the first foundational workflow; detailed design is documented in [ci-foundation.md](ci-foundation.md).

Security scanning, artifact creation, optional Harbor publication, Cosign signing/verification, OPA policy evaluation and digest-bound authorization are implemented in the dedicated security controls. Phase 14 adds a dependency-free JSONL security-event writer for external collection; it does not install an observability backend. A successful workflow must not be interpreted as a security approval without the documented gates.
