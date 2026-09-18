# DevShield

DevShield is a platform for building a verifiable chain of trust from source code to production runtime. It will progressively host application components, CI/CD controls, supply-chain evidence, deployment models and operational security documentation.

## Architecture at a glance

```text
Source → Development → CI/CD → Security evidence → Signed artifact
       → Policy verification → Deployment → Runtime protection → Observability
```

The platform is being implemented incrementally. SAST, secret detection, dependency and container scanning, SBOM generation, artifact inventory and secure registry integration are currently implemented. Signing, provenance, policy as code, DAST, WAF and runtime security remain planned.

## Incremental implementation

DevShield is implemented phase by phase. Each phase is independently testable and documented; future phases must not be treated as complete until their controls and failure behavior have been validated.

## Current status

**Phase 08 — Artifact Signing & Verification.** Semgrep, Gitleaks, Trivy SCA, container security and Syft CycloneDX inventory feed a centralized fail-closed gate. Approved images can be pushed to a pinned, project-scoped Harbor registry, then signed and verified by Cosign against the exact image digest. Local signing uses a protected key pair; trusted `main` CI signing uses GitHub OIDC keyless signing when explicitly enabled. Provenance, OPA, deployment and runtime controls remain future phases.

Use `make registry-up` for the pinned official Harbor installer model and see [registry security](docs/02-security/registry.md), [signing](docs/02-security/signing.md) and [CI signing integration](docs/04-cicd/signing-integration.md).

See [PROJECT_SPECIFICATION.md](PROJECT_SPECIFICATION.md) for the initial architectural specification.
