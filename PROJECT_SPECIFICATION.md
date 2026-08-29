# DevShield — Project Specification

## 1. Project Vision

DevShield aims to establish a verifiable chain of trust from source code to production runtime. Every important security control should produce evidence that can be evaluated by an explicit policy and result in a documented action.

## 2. Objectives

- Provide a maintainable foundation for application and platform components.
- Make security evidence traceable to source, builds and immutable artifacts.
- Separate development, staging and production responsibilities.
- Introduce controls incrementally with positive, negative and failure tests.

## 3. Scope

The repository will eventually contain application code, security controls, infrastructure definitions, deployment models, tests and documentation. This phase establishes only the repository skeleton and architectural baseline.

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

The planned layers are SAST, secret detection, software composition analysis, container security, SBOM, signing, provenance, policy as code, DAST, WAF and runtime security. Their configurations and rules will be introduced in later phases.

## 6. Target Technology Stack

The target application ecosystem supports Node.js/Express backends and React and/or Angular frontends. Planned security technologies include Semgrep, Gitleaks, Trivy, Syft, Harbor, Cosign, OPA/Rego, OWASP ZAP, Coraza with OWASP CRS and Falco, subject to later phase specifications and validation.

## 7. Environment Model

Development is intended for fast feedback, staging for broader validation and production for strict trust verification. Production deployments are expected to use immutable artifact digests.

## 8. Supply-Chain Trust Model

Production artifacts should be traceable to their source commit, repository, build workflow, builder, timestamp, digest, SBOM, scan evidence and signature. Deployment policy should verify the required evidence before promotion.

## 9. CI/CD Strategy

The pipeline will progressively establish trust through quality checks, tests, analysis, artifact creation, evidence generation, signing, policy verification, deployment and post-deployment validation. Phase 02 established a minimal GitHub Actions workflow with separate foundation, quality, test and build jobs. Phase 03 adds Semgrep and Gitleaks as the first source-security controls, with explicit evidence and a fail-closed gate. Because no application exists yet, the application-aware Make targets report explicit limitations without pretending that linting, tests or builds are operational. Remaining security stages and enforcement rules will be defined in later phases.

## 10. Testing Strategy

Tests will be separated into unit, integration, end-to-end and security categories. Security controls must include secure-input positive tests, malicious or vulnerable-input negative tests and explicit verification of failure behavior.

## 11. Implementation Strategy

Implementation proceeds by phase: inspect, plan, implement, test, simulate failure, correct, validate and document. Major architectural changes require an explicit decision rather than a silent substitution.

## 12. Current Status

**Phase 03 — SAST & Secret Detection.** The repository structure, CI foundation, Semgrep and Gitleaks workflows, evidence model and temporary security gate are established. No SCA, container, SBOM, signing, provenance, DAST, WAF, runtime security, artifact publication or deployment implementation is complete.
