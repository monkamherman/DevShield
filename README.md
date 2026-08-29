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

**Phase 01 — Repository Skeleton.** The repository currently provides the structure and architectural documentation needed for later work. No security scanner, deployment system, production infrastructure or complete CI/CD pipeline has been introduced yet.

See [PROJECT_SPECIFICATION.md](PROJECT_SPECIFICATION.md) for the initial architectural specification.
