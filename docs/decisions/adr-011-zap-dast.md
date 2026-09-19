# ADR-011: OWASP ZAP baseline DAST

## Decision

Use OWASP ZAP baseline scan as DevShield's first Dynamic Application Security Testing capability. Pin the execution image to `zaproxy/zap-stable:2.15.0`, run it in Docker, require an explicit HTTP/HTTPS target and environment, and restrict hosts through an explicit allowlist.

The scanner produces JSON and HTML reports. A normalizer creates machine-readable DAST evidence with severity counts and a report hash. High findings fail the DAST step; medium findings are warnings; low and informational findings are recorded. Tool, target and configuration failures fail closed and cannot become a security pass.

## Context

DAST must test a running application after a controlled test deployment. DevShield currently has no application runtime, Kubernetes manifests or GitOps controller. The phase therefore establishes the scanner contract and CI seam without inventing deployment infrastructure.

## Alternatives considered

OWASP ZAP was selected because it is an established open-source web scanner with baseline, API and authenticated-scan extensions. Commercial scanners and other open-source scanners were not selected because they would add a different toolchain before the first application environment exists. Active scanning was deferred because it can be disruptive.

## Scope

Included: target validation, host allowlisting, ZAP baseline execution, JSON/HTML reports, evidence, severity handling, deterministic fixtures, CI integration and evidence consistency validation.

Not included: production active scanning, authenticated scanning, OpenAPI scanning, WAF, Kubernetes/GitOps integration or automatic test deployment.

## Risks and consequences

Baseline DAST has false positives and false negatives, depends on target availability and may miss authenticated functionality. A target outage is classified separately from a security finding but still blocks a required scan. The host allowlist reduces accidental scanning of external systems. Any future suppression must be finding-specific, reviewed, versioned and justified; no global bypass is provided.

The optional DAST field in normalized OPA input prepares future policy consumption. It does not make a post-deployment DAST result silently override the existing artifact trust policy.

## Future evolution

After a real staging application exists, add an explicit test-deployment job, authenticated ZAP contexts, OpenAPI/API scans and policy rules appropriate to that environment. WAF/Coraza and runtime security remain separate phases.
