# Deployment authorization

Phase 10 provides a runtime-independent deployment trust gate. It does not invent Kubernetes or a deployment controller because this repository currently contains no runtime manifests or deployment executor.

`authorize.sh` accepts an exact `repository@sha256:<digest>`, the target environment and the normalized Phase 09 policy input. It validates the reference, checks that the input describes the same artifact and environment, re-evaluates the versioned OPA policy, and writes deployment authorization evidence. Exit code `0` means `AUTHORIZED`; `1` means `POLICY_DENIED` or `VERIFICATION_FAILURE`; `2` means a tool/input failure.

Future CI, Docker, GitOps or admission adapters must depend on this authorization result and deploy the exact authorized reference. A tag is never substituted for a digest. The wrapper deliberately re-evaluates OPA at authorization time, so a stale or replayed approval is not implicitly trusted.

The contract is:

```text
OPA ALLOW + exact digest binding + valid evidence
                       ↓
              deployment AUTHORIZED
```

Any missing or inconsistent evidence blocks the deployment. `validate-evidence.sh` is provided for a future adapter to verify that an authorization evidence file remains bound to its artifact and environment.
