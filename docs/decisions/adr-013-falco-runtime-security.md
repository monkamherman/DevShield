# ADR-013: Falco runtime security

## Decision

Use Falco `0.44.1` with the Modern eBPF backend for the first DevShield runtime-security capability. Run the official container image with a documented least-privilege capability profile and read-only host mounts. Add versioned DevShield rules for suspicious container shells, network tooling, sensitive-file access, writes below `/etc` and execution from temporary directories.

The first phase is detection-only. Events are normalized into runtime evidence with container/image context and an image digest only when supplied by Falco. No automatic remediation is performed.

## Context

DevShield currently has Docker conventions but no Kubernetes runtime, monitoring platform or incident-response system. A Docker-oriented wrapper establishes the runtime boundary without inventing Kubernetes infrastructure. Falco is appropriate because it observes syscall/container behavior, while existing scanners and policy engines have different responsibilities.

## Alternatives considered

Kubernetes Falco Operator and Helm were rejected for this phase because Kubernetes is not present. A custom syscall monitor would duplicate Falco and create a larger security surface. Host-based commercial agents were not selected because the requested architecture specifies Falco and versioned, testable rules.

## Scope

Included: pinned Falco image, Modern eBPF configuration, least-privilege Docker wrapper, custom rules, readiness checks, event normalization, evidence and failure-oriented tests.

Not included: automatic process killing, container termination, network isolation, Kubernetes, SIEM, alert routing, full incident response or runtime admission policy.

## Security implications

Runtime observation requires host-sensitive access. The wrapper drops all capabilities and adds only the documented capabilities currently required by Docker's Modern eBPF setup. Host tracing, `/proc`, `/etc` and the Docker socket are read-only, but this remains a high-trust component requiring host review. A missing or unloaded rule set is a runtime-security failure.

The custom rules are additive and auditable. They do not silently disable upstream rules or provide an environment-variable bypass. False positives and false negatives are expected; contextual tuning must be reviewed and versioned.

## Consequences

DevShield gains a consistent runtime event/evidence boundary and can later correlate a Falco event with an authorized image digest. The current environment cannot prove live syscall capture without a suitable Linux host and Docker privileges. Runtime availability is visible but is not yet wired into OPA as an automatic deployment blocker.

## Future evolution

The next phase can add observability, alert routing, retention and incident response. A later Kubernetes phase may use a DaemonSet or Falco Operator while preserving the same event/evidence contract. Automated response requires a separate risk-reviewed decision.
