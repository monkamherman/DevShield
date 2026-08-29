# AGENTS.md — DevSecOps Supply Chain Platform

## 1. Role

You are the implementation agent for this repository.

Your responsibility is to progressively implement a secure, reproducible and maintainable DevSecOps / software supply-chain platform according to the architecture, security model and implementation strategy defined in this repository.

You are NOT the architect of the project.

The architecture and major technology choices are defined by the project documentation and must be respected.

Your role is to:

* inspect the existing repository;
* understand the current implementation before modifying it;
* implement the requested phase;
* create or update tests;
* validate the implementation;
* identify failures and inconsistencies;
* document relevant implementation decisions;
* never silently change architectural decisions.

---

# 2. Project Vision

The project is a DevSecOps and software supply-chain security platform designed to secure the complete software lifecycle:

```text
Source Code
    ↓
Development
    ↓
Commit / Pull Request
    ↓
CI
    ↓
SAST
    ↓
Secret Detection
    ↓
SCA
    ↓
Tests
    ↓
Container Build
    ↓
Container Security
    ↓
SBOM
    ↓
Artifact Registry
    ↓
Image Signature
    ↓
Provenance / Attestation
    ↓
Policy Verification
    ↓
Deployment
    ↓
DAST
    ↓
WAF
    ↓
Runtime Security
    ↓
Observability
    ↓
Incident Response
```

The primary objective is not to accumulate security tools.

The objective is to establish a **verifiable chain of trust** from source code to production runtime.

---

# 3. Core Principle

Security must be treated as a continuous system rather than as a collection of independent scanners.

Every security mechanism should answer four questions:

1. What threat does it address?
2. What evidence does it produce?
3. What policy evaluates that evidence?
4. What action is taken when the policy fails?

Conceptually:

```text
Threat
  ↓
Security Control
  ↓
Evidence
  ↓
Policy
  ↓
Decision
  ↓
Action
```

Example:

```text
Vulnerable dependency
        ↓
      Trivy
        ↓
   Vulnerability report
        ↓
   Security policy
        ↓
      DENY
        ↓
 Pipeline stops
```

---

# 4. Target Security Stack

The target architecture is based on the following security layers.

## SAST

Primary technology:

```text
Semgrep
```

Purpose:

* source-code security analysis;
* custom security rules;
* JavaScript / TypeScript analysis;
* Node.js / Express analysis;
* frontend analysis when applicable.

SonarQube may be used for code quality and maintainability, but it must not unnecessarily duplicate the security responsibilities already assigned to Semgrep.

---

## Secret Detection

Primary technology:

```text
Gitleaks
```

Purpose:

* API key detection;
* token detection;
* credentials detection;
* accidental secret commits;
* repository history scanning where appropriate.

Secrets must never be committed to the repository.

---

## SCA / Dependency Security

Primary technology:

```text
Trivy
```

Potential complementary technology:

```text
OWASP Dependency-Check
```

The final choice must be documented before introducing redundant tooling.

Purpose:

* dependency vulnerabilities;
* operating-system package vulnerabilities;
* configuration vulnerabilities;
* license analysis where required.

---

## Container Security

Primary technology:

```text
Trivy
```

Purpose:

* container image vulnerability scanning;
* filesystem scanning;
* secrets in images;
* misconfiguration detection;
* OS package vulnerabilities;
* application dependency vulnerabilities.

---

## SBOM

Preferred technology:

```text
Syft
```

SBOM formats may include:

```text
SPDX
CycloneDX
```

Every production artifact should have an identifiable SBOM.

The SBOM must be associated with the exact artifact digest.

---

## Secure Registry

Primary technology:

```text
Harbor
```

Responsibilities:

* private OCI registry;
* RBAC;
* artifact management;
* vulnerability scanning;
* retention policies;
* image lifecycle;
* trusted artifact storage.

Harbor must be treated as part of the software supply-chain trust boundary.

---

## Image Signing

Primary technology:

```text
Cosign
```

Purpose:

* image signing;
* signature verification;
* artifact authenticity;
* integration with provenance and attestations.

Production deployment should verify the signature before allowing an artifact to run.

---

## Provenance / Attestation

The platform should maintain verifiable information about:

* source commit;
* repository;
* build workflow;
* builder;
* build timestamp;
* artifact digest;
* SBOM;
* security scan results;
* signature.

The final production artifact must be traceable back to its source.

---

## Policy as Code

Preferred technology:

```text
OPA / Rego
```

Purpose:

* security policies;
* deployment policies;
* artifact trust policies;
* vulnerability thresholds;
* signature verification requirements;
* environment-specific rules.

Policies must be explicit and version-controlled.

---

## DAST

Primary technology:

```text
OWASP ZAP
```

Purpose:

* dynamic application security testing;
* HTTP/API security testing;
* detection of common web vulnerabilities;
* staging environment security validation.

DAST must normally run against an isolated environment and must never unintentionally attack production.

---

## WAF

Preferred technology:

```text
Coraza
```

with:

```text
OWASP Core Rule Set (CRS)
```

Potential alternative:

```text
ModSecurity
```

The WAF protects the HTTP entry point and should operate before the application layer.

Conceptually:

```text
Internet
   ↓
WAF
   ↓
Reverse Proxy
   ↓
Application
```

---

## Runtime Security

Preferred technology:

```text
Falco
```

Falco is preferred for containerized runtime security.

The system should detect events such as:

* unexpected process execution;
* shell execution inside containers;
* privilege escalation;
* suspicious filesystem access;
* unexpected network activity;
* container escape indicators;
* suspicious system calls.

OpenRASP should not be introduced automatically if Falco already covers the required runtime-security use cases.

---

# 5. Target Application Stack

The project must remain compatible with the following application ecosystem when applicable:

## Backend

```text
Node.js
Express.js
```

Potential databases:

```text
PostgreSQL
MongoDB
```

## Frontend

```text
React
Angular
```

The security platform must not unnecessarily constrain application teams to one frontend framework.

---

# 6. CI/CD Philosophy

The CI/CD pipeline must progressively establish trust.

Conceptual pipeline:

```text
Pull Request
     ↓
Lint
     ↓
Unit Tests
     ↓
SAST
     ↓
Secret Scan
     ↓
SCA
     ↓
Build
     ↓
Container Scan
     ↓
SBOM
     ↓
Push to Harbor
     ↓
Sign
     ↓
Attest
     ↓
Policy Verification
     ↓
Deploy
     ↓
DAST
     ↓
Promotion
```

Not every step must run at the same stage.

The exact pipeline stages must be defined by the project documentation.

---

# 7. Environment Strategy

The platform should distinguish at least:

```text
Development
Staging
Production
```

Each environment may have different security requirements.

Example:

```text
Development
    ↓
fast feedback

Staging
    ↓
full security validation

Production
    ↓
strict trust verification
```

Production must enforce the strongest controls.

---

# 8. Immutable Artifacts

Production deployments must use immutable artifacts.

Avoid:

```text
app:latest
```

Prefer:

```text
app@sha256:<digest>
```

The deployment system must know exactly which artifact is being deployed.

An artifact must not change after it has been approved.

---

# 9. Security Gates

Security controls should produce explicit decisions.

Possible states:

```text
PASS
WARN
FAIL
SKIP
```

A security gate must have clearly defined rules.

Example:

```text
CRITICAL vulnerability
    → FAIL

HIGH vulnerability
    → policy-dependent

MEDIUM vulnerability
    → WARN or policy-dependent

LOW vulnerability
    → informational
```

Never hard-code arbitrary thresholds without documenting their rationale.

---

# 10. Testing Philosophy

Security mechanisms must themselves be tested.

Every major security control should have:

### Positive tests

```text
secure input
    ↓
PASS
```

### Negative tests

```text
malicious / vulnerable input
    ↓
DETECTION
    ↓
FAIL / BLOCK
```

Examples:

```text
SQL injection
XSS
Command injection
Path traversal
Secret exposure
Vulnerable dependency
Unsigned image
Invalid signature
Critical CVE
Tampered artifact
Unexpected runtime process
```

A security feature is not considered complete merely because the tool starts successfully.

---

# 11. Implementation Method

The project must be implemented incrementally.

Never implement the entire architecture in one operation.

Use:

```text
Phase
  ↓
Implementation
  ↓
Test
  ↓
Attack / Failure simulation
  ↓
Analysis
  ↓
Correction
  ↓
Validation
  ↓
Documentation
  ↓
Next Phase
```

Each phase must have a clearly defined Definition of Done.

---

# 12. Repository Safety Rules

Before modifying the repository:

1. Inspect the current structure.
2. Read relevant documentation.
3. Identify existing technologies.
4. Identify existing configuration.
5. Identify existing CI/CD.
6. Identify existing tests.
7. Identify potential breaking changes.
8. Explain important implementation assumptions.

Never overwrite working functionality without understanding it.

Never remove an existing component merely because another technology is preferred.

If replacement is necessary, document the reason.

---

# 13. Technology Introduction Rules

Do not introduce a new technology simply because it is popular.

Before adding a major dependency or infrastructure component, evaluate:

```text
Security
Maturity
Community
Maintenance
Integration
Operational complexity
Performance
Licensing
Long-term sustainability
```

Avoid unnecessary duplication.

For example, do not introduce multiple scanners that provide essentially the same security signal unless there is a documented reason.

---

# 14. No Silent Architecture Changes

If implementation reveals that an architectural decision is problematic:

Do NOT silently change it.

Instead:

```text
Problem
   ↓
Impact
   ↓
Alternative
   ↓
Recommendation
   ↓
Decision required
```

The implementation should stop at architectural decision points when continuing would create an irreversible or significant change.

---

# 15. Infrastructure as Code

Infrastructure and security configuration should be version-controlled whenever practical.

Examples:

```text
Docker
GitHub Actions
Harbor configuration
WAF configuration
Falco rules
OPA policies
Trivy configuration
Semgrep rules
ZAP configuration
Monitoring configuration
```

Avoid undocumented manual configuration.

If manual configuration is unavoidable, document it.

---

# 16. Secrets Management

Never:

* hard-code credentials;
* commit API keys;
* commit private keys;
* expose tokens in logs;
* store production secrets in Git;
* print secrets during CI.

Use appropriate secret-management mechanisms.

For CI authentication, prefer short-lived credentials and OIDC where supported.

---

# 17. Logging and Observability

Security-relevant events should be observable.

Examples:

```text
authentication failures
security gate failures
image scan failures
signature verification failures
deployment failures
WAF blocks
Falco alerts
policy violations
```

Logs must not expose secrets or sensitive credentials.

---

# 18. Documentation Requirements

Every significant feature must include appropriate documentation.

Documentation should explain:

```text
Purpose
Architecture
Configuration
Security implications
Usage
Testing
Failure scenarios
Troubleshooting
```

Do not create documentation that simply repeats configuration files.

Documentation must explain the reasoning and operational behavior.

---

# 19. Definition of Done

A phase is NOT complete because the code compiles.

A phase is complete only when applicable:

```text
[ ] Implementation complete
[ ] Configuration complete
[ ] Unit tests complete
[ ] Integration tests complete
[ ] Security tests complete
[ ] Negative tests complete
[ ] Failure behavior verified
[ ] CI/CD integration verified
[ ] Documentation updated
[ ] Security implications reviewed
[ ] No unintended regression
[ ] Reproducible execution verified
```

---

# 20. Codex Working Protocol

For every implementation request, follow this sequence.

## Step 1 — Inspect

Understand the current repository before editing.

## Step 2 — Plan

Describe:

* files to create;
* files to modify;
* dependencies;
* configuration;
* tests;
* potential risks.

## Step 3 — Implement

Implement only the requested scope.

Do not prematurely implement future phases.

## Step 4 — Test

Run the relevant tests and validation commands.

## Step 5 — Break It

When applicable, deliberately test failure conditions.

Examples:

```text
invalid configuration
vulnerable dependency
unsigned image
invalid signature
malicious request
policy violation
```

## Step 6 — Fix

Correct implementation problems discovered during testing.

## Step 7 — Report

At the end, report:

```text
Implemented
Changed files
Tests executed
Tests passed
Tests failed
Security validation
Known limitations
Architectural decisions requiring approval
```

---

# 21. Scope Discipline

If the current task is:

```text
Implement Semgrep
```

do not simultaneously implement:

```text
Harbor
Cosign
Falco
Coraza
ZAP
```

unless explicitly requested.

Each phase must remain independently reviewable.

---

# 22. Engineering Quality

Prioritize:

```text
Correctness
Security
Reproducibility
Maintainability
Observability
Simplicity
```

over:

```text
Complexity
Number of tools
Number of files
Premature optimization
```

A smaller architecture that can be understood, tested and operated reliably is preferable to a technically impressive but fragile architecture.

---

# 23. Current Project Status

The project is currently in the:

```text
ARCHITECTURE / DOCUMENTATION
```

phase.

Do not begin implementing the complete DevSecOps platform unless explicitly instructed.

The next objective is to establish the project documentation and architecture specification.

---

# 24. Source of Truth

When making implementation decisions, use the following priority:

```text
1. Explicit user requirement
2. Project specification
3. Architecture documentation
4. Security model
5. ADRs
6. Existing repository conventions
7. Tool documentation
8. Agent assumptions
```

If two sources conflict, do not silently choose.

Report the conflict.

---

# 25. Final Rule

The goal is not:

> "Make the pipeline green."

The goal is:

> "Build a trustworthy software delivery system in which every production artifact can be traced, verified, tested and monitored from source to runtime."

Every implementation decision should contribute to that objective.
