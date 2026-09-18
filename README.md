# DevShield

DevShield is a platform for building a verifiable chain of trust from source code to production runtime. It will progressively host application components, CI/CD controls, supply-chain evidence, deployment models and operational security documentation.

## Architecture at a glance

```text
Source → Development → CI/CD → Security evidence → Signed artifact
       → Policy verification → Deployment → Runtime protection → Observability
```

The platform is being implemented incrementally. SAST, secret detection, dependency and container scanning, SBOM generation, artifact inventory, secure registry integration, signing/verification, OPA policy decisions, digest-bound deployment authorization and the ZAP DAST integration are currently implemented. Provenance, WAF, runtime security and a concrete deployment runtime remain planned.

## Incremental implementation

DevShield is implemented phase by phase. Each phase is independently testable and documented; future phases must not be treated as complete until their controls and failure behavior have been validated.

## Current status

**Phase 11 — Dynamic Application Security Testing.** OWASP ZAP `2.15.0` provides an explicit-target baseline scan, JSON/HTML reports and fail-closed evidence. The CI job is opt-in and runs only after deployment authorization; no application runtime exists yet for full E2E validation.

Use `make registry-up` for the pinned official Harbor installer model and see [registry security](docs/02-security/registry.md), [signing](docs/02-security/signing.md), [policy as code](docs/02-security/policy-as-code.md) and [CI signing integration](docs/04-cicd/signing-integration.md).

See [PROJECT_SPECIFICATION.md](PROJECT_SPECIFICATION.md) for the initial architectural specification.
