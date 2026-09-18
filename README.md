# DevShield

DevShield is a platform for building a verifiable chain of trust from source code to production runtime. It will progressively host application components, CI/CD controls, supply-chain evidence, deployment models and operational security documentation.

## Architecture at a glance

```text
Source → Development → CI/CD → Security evidence → Signed artifact
       → Policy verification → Deployment → Runtime protection → Observability
```

The platform is being implemented incrementally. SAST, secret detection, dependency and container scanning, SBOM generation, artifact inventory, secure registry integration, signing/verification, OPA policy decisions and digest-bound deployment authorization are currently implemented. Provenance, DAST, WAF, runtime security and a concrete deployment runtime remain planned.

## Incremental implementation

DevShield is implemented phase by phase. Each phase is independently testable and documented; future phases must not be treated as complete until their controls and failure behavior have been validated.

## Current status

**Phase 10 — Deployment Trust Enforcement.** Phase 09 evidence is re-evaluated by OPA immediately before a generic deployment authorization. Only an exact immutable digest can be authorized; OPA denial, missing evidence or tool failure blocks authorization. No Kubernetes or deployment runtime is invented before the repository requires one.

Use `make registry-up` for the pinned official Harbor installer model and see [registry security](docs/02-security/registry.md), [signing](docs/02-security/signing.md), [policy as code](docs/02-security/policy-as-code.md) and [CI signing integration](docs/04-cicd/signing-integration.md).

See [PROJECT_SPECIFICATION.md](PROJECT_SPECIFICATION.md) for the initial architectural specification.
