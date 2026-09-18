# DevShield — Project Specification

## 1. Project Vision

DevShield aims to establish a verifiable chain of trust from source code to production runtime. Every important security control should produce evidence that can be evaluated by an explicit policy and result in a documented action.

## 2. Objectives

- Provide a maintainable foundation for application and platform components.
- Make security evidence traceable to source, builds and immutable artifacts.
- Separate development, staging and production responsibilities.
- Introduce controls incrementally with positive, negative and failure tests.

## 3. Scope

The repository contains the architectural baseline, security controls, evidence producers, infrastructure integration points, tests and documentation. Application implementation and deployment environments will be added incrementally in later phases.

## 4. High-Level Architecture

```text
Source
  ↓
Development and CI/CD
  ↓
Analysis and security evidence
  ↓
Build, SBOM, signing and provenance
  ↓
Policy verification
  ↓
Environment deployment
  ↓
DAST, WAF, runtime security and observability
```

## 5. Security Layers

The implemented layers are SAST, secret detection, software composition analysis, container security, SBOM, artifact inventory, secure registry integration, Cosign artifact signing/verification, OPA policy decisions, digest-bound deployment authorization, OWASP ZAP baseline DAST, Coraza/OWASP CRS WAF, a Docker-oriented Falco runtime-security integration and a structured security-event JSONL writer. Provenance is consumed when available. An external observability backend and a concrete production runtime remain outside this phase.

## 6. Target Technology Stack

The target application ecosystem supports Node.js/Express backends and React and/or Angular frontends. Planned security technologies include Semgrep, Gitleaks, Trivy, Syft, Harbor, Cosign, OPA/Rego, OWASP ZAP, Coraza with OWASP CRS and Falco, subject to later phase specifications and validation.

## 7. Environment Model

Development is intended for fast feedback, staging for broader validation and production for strict trust verification. Production deployments are expected to use immutable artifact digests.

## 8. Supply-Chain Trust Model

Production artifacts should be traceable to their source commit, repository, build workflow, builder, timestamp, digest, SBOM, scan evidence and signature. Deployment authorization verifies the required evidence immediately before promotion and binds the decision to the exact digest and environment.

## 9. CI/CD Strategy

The pipeline progressively establishes trust through quality checks, tests, analysis, artifact creation, evidence generation, signing, policy verification and deployment authorization. Phase 02 established the CI foundation; Phase 03 added Semgrep and Gitleaks; Phase 04 added Trivy SCA; Phase 05 added container build and image security; Phase 06 added Syft SBOM generation and artifact inventory; Phase 07 added Harbor integration; Phase 08 added Cosign signing and verification; Phase 09 added OPA policy decisions; and Phase 10 added the digest-bound authorization contract. Because no production application or deployment runtime exists yet, the application-aware Make targets report explicit limitations without pretending that deployment is operational. Runtime deployment remains future work.

## 10. Testing Strategy

Tests will be separated into unit, integration, end-to-end and security categories. Security controls must include secure-input positive tests, malicious or vulnerable-input negative tests and explicit verification of failure behavior.

## 11. Implementation Strategy

Implementation proceeds by phase: inspect, plan, implement, test, simulate failure, correct, validate and document. Major architectural changes require an explicit decision rather than a silent substitution.

## 12. Current Status

**Phase 14 — Security Event Logging & External Observability Export.** The repository provides a versioned JSONL event contract, validation, redaction, local bounded logging and external collector compatibility. No Prometheus, Grafana, Loki, SIEM, collector or automatic response system is embedded. Component-wide automatic log hooks and end-to-end validation remain Phase 15 work.
