# DevShield

DevShield is a platform for building a verifiable chain of trust from source code to production runtime. It will progressively host application components, CI/CD controls, supply-chain evidence, deployment models and operational security documentation.

## Architecture at a glance

```text
Source → Development → CI/CD → Security evidence → Signed artifact
       → Policy verification → Deployment → Runtime protection → Observability
```

The planned security layers include SAST, secret detection, dependency and container scanning, SBOM generation, signing, provenance, policy as code, DAST, WAF and runtime security. These controls are planned, not implemented in this repository skeleton.

## Incremental implementation

DevShield is implemented phase by phase. Each phase is independently testable and documented; future phases must not be treated as complete until their controls and failure behavior have been validated.

## Current status

**Phase 07 — Secure Registry.** Semgrep, Gitleaks, Trivy SCA, container security and Syft CycloneDX inventory feed a centralized fail-closed gate. Approved images can be pushed to a pinned, project-scoped Harbor registry using `sha-<commit>` tags and digest identity. Local Harbor integration is explicit and optional; signing, provenance, OPA and deployment remain future phases.

Use `make registry-up` for the pinned official Harbor installer model, then see [registry security](docs/02-security/registry.md) and [CI integration](docs/04-cicd/registry-integration.md). Harbor is not treated as cryptographic trust until Phase 08 adds Cosign.

See [PROJECT_SPECIFICATION.md](PROJECT_SPECIFICATION.md) for the initial architectural specification.
