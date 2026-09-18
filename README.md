# DevShield

DevShield is a platform for building a verifiable chain of trust from source code to production runtime. It will progressively host application components, CI/CD controls, supply-chain evidence, deployment models and operational security documentation.

## Architecture at a glance

```text
Source → Development → CI/CD → Security evidence → Signed artifact
       → Policy verification → Deployment → Runtime protection → Observability
```

The platform is being implemented incrementally. SAST, secret detection, dependency and container scanning, SBOM generation, artifact inventory, secure registry integration, signing/verification and OPA policy decisions are currently implemented. Provenance, DAST, WAF and runtime security remain planned.

## Incremental implementation

DevShield is implemented phase by phase. Each phase is independently testable and documented; future phases must not be treated as complete until their controls and failure behavior have been validated.

## Current status

**Phase 09 — Policy as Code with OPA/Rego.** Semgrep, Gitleaks, Trivy SCA, container security, Syft CycloneDX inventory, Harbor and Cosign evidence are normalized and evaluated by versioned fail-closed Rego policies. Development, staging and production have explicit trust requirements. Provenance is consumed when present; deployment, DAST, WAF and runtime controls remain future phases.

Use `make registry-up` for the pinned official Harbor installer model and see [registry security](docs/02-security/registry.md), [signing](docs/02-security/signing.md), [policy as code](docs/02-security/policy-as-code.md) and [CI signing integration](docs/04-cicd/signing-integration.md).

See [PROJECT_SPECIFICATION.md](PROJECT_SPECIFICATION.md) for the initial architectural specification.
