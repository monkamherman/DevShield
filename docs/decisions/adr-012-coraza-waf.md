# ADR-012: Coraza with OWASP CRS

## Decision

Use the official Coraza CRS Docker reverse-proxy integration as DevShield's WAF boundary. Pin the image to `ghcr.io/coreruleset/coraza-crs:4.25.0-nginx-202509051009`, identify the connector as `coraza-nginx-0.21.0`, and identify OWASP CRS as `4.25.0`. Configure the upstream, mode, paranoia level and anomaly threshold explicitly.

Development may use detection mode for tuning. Production defaults to blocking mode. Invalid configuration, missing upstream, missing versioned configuration or startup failure prevents the WAF from being considered ready.

## Context

DevShield has no existing reverse proxy, ingress or application runtime. Coraza is a Go WAF engine compatible with ModSecurity SecLang and CRS; the official CRS Docker project provides reverse-proxy variants and versioned image tags. Using that integration gives the project a reproducible boundary without copying or rewriting the CRS rules.

## Alternatives considered

ModSecurity was not selected because the requested architecture requires Coraza. A custom Go proxy was not selected because it would duplicate a maintained integration and create unnecessary rule-loading and proxy behavior. Kubernetes ingress, Gateway API and service mesh integrations are deferred because no such runtime exists in the repository.

## Scope

Included: versioned image contract, configurable upstream, detection/blocking modes, configuration validation, health check, Docker lifecycle wrapper, audit evidence normalization, deterministic configuration/evidence tests and optional Docker integration tests.

Not included: Kubernetes ingress, Gateway API, GitOps, advanced rate limiting, bot management, TLS certificate provisioning, production tuning, global CRS exclusions or application-specific authenticated behavior.

## Security implications

The WAF is a runtime filter, not artifact authorization. It does not replace DAST, OPA, Cosign, SBOM or Falco. A direct-to-application path must not be introduced when WAF protection is mandatory. Detection mode must never be described as blocking. CRS exclusions must be explicit, minimal, reviewed and versioned. Audit logging must avoid copying credentials and sensitive request content.

## Risks and consequences

CRS tuning can cause false positives and false negatives; paranoia levels and thresholds affect this tradeoff. Blocking mode adds latency and can deny legitimate traffic. The pinned image and configuration hash improve reproducibility, but a production deployment still needs image verification, controlled configuration rollout, TLS design and representative workload testing.

## Future evolution

A later phase may integrate the WAF with a concrete reverse proxy, Kubernetes ingress or Gateway API, connect DAST to the protected staging environment, add reviewed rule exclusions and forward normalized events to monitoring and incident response. Falco remains a separate runtime-security phase.
