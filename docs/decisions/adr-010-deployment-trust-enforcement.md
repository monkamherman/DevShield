# ADR-010: Deployment trust enforcement

## Context

Phase 09 produces a fail-closed OPA decision, but a policy decision has no security value if a deployment path can ignore it. DevShield currently has no Kubernetes or deployment runtime, so introducing an admission controller would add an unapproved platform rather than solve the current integration boundary.

## Decision

Introduce a runtime-independent deployment authorization contract under `security/deployment/`. `authorize.sh` validates an immutable image reference, binds it to the normalized policy input, re-evaluates OPA for the requested environment, and emits authorization evidence. Only exit code `0` (`AUTHORIZED`) permits a future deployment adapter to proceed. The adapter must deploy the exact authorized digest.

The trust chain is:

```text
trusted registry + digest + security evidence + SBOM
        + verified signature + trusted signer + provenance
        + OPA ALLOW
        → deployment authorization
```

The wrapper fails closed on OPA, input, registry evidence or verification failures. Stored authorization is not a reusable generic approval: authorization is re-evaluated for each request.

## Alternatives considered

* CI-only authorization: useful immediately, but insufficient if a later deployment path bypasses CI.
* Admission control: stronger runtime enforcement, deferred because no Kubernetes/runtime exists.
* GitOps authorization: compatible with the contract, deferred until a GitOps system exists.
* Deployment wrapper: selected as the present abstraction because it is testable locally and can be consumed by each future target.

## Consequences

Positive consequences include explicit digest binding, reusable exit-code semantics, auditable evidence and a clear seam for CI, Docker, GitOps or admission integration. The limitation is that Phase 10 cannot enforce a runtime deployment that does not yet exist; the current enforcement point is the authorization command and CI dependency graph.

## Security implications

Digest substitution, mutable tags, OPA denial, missing evidence, wrong signer, signature failure, untrusted registry and policy/tool unavailability all block authorization. Policy files remain versioned in Git and their hash is recorded. A future deployment system must protect the policy source and require fresh authorization rather than trusting manually copied evidence.

## Future evolution

When DevShield adopts Kubernetes or GitOps, the adapter must call the same contract and pass the exact digest to the runtime. A later phase may add Kubernetes admission control, OPA Gatekeeper or runtime enforcement without changing the trust contract.
