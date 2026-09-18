# DevShield

DevShield is a platform for building a verifiable chain of trust from source code to production runtime. It will progressively host application components, CI/CD controls, supply-chain evidence, deployment models and operational security documentation.

## Architecture at a glance

```text
Source → Development → CI/CD → Security evidence → Signed artifact
       → Policy verification → Deployment → Runtime protection → Observability
```

The platform is being implemented incrementally. SAST, secret detection, dependency and container scanning, SBOM generation, artifact inventory, secure registry integration, signing/verification, OPA policy decisions, digest-bound deployment authorization, ZAP DAST, Coraza/OWASP CRS WAF, Docker-oriented Falco runtime-security integration and the Phase 14 structured security-event writer are currently implemented. A concrete production runtime, automatic hooks in every historical component and an external observability backend remain future validation work.

## Incremental implementation

DevShield is implemented phase by phase. Each phase is independently testable and documented; future phases must not be treated as complete until their controls and failure behavior have been validated.

## Current status

**Phase 14 — Security Event Logging & External Observability Export.** DevShield writes validated, redacted JSONL security events to `reports/logs/security-events.jsonl`, preserving artifact/pipeline/deployment correlation without requiring a network service. External collection is intentionally not embedded. See [observability](docs/04-cicd/observability.md).

Use `make registry-up` for the pinned official Harbor installer model and see [registry security](docs/02-security/registry.md), [signing](docs/02-security/signing.md), [policy as code](docs/02-security/policy-as-code.md) and [CI signing integration](docs/04-cicd/signing-integration.md).

See [PROJECT_SPECIFICATION.md](PROJECT_SPECIFICATION.md) for the initial architectural specification.
