# Deployment trust enforcement

## Scope

DevShield has no Kubernetes, Helm, GitOps controller or application deployment executor yet. Phase 10 therefore implements a deployment authorization contract rather than introducing a runtime platform. The contract can later be consumed by CI/CD, a Docker wrapper, GitOps or an admission controller.

## Decision flow

```text
security evidence
      ↓
OPA/Rego decision
      ↓
deployment/authorize.sh
      ↓
exact digest + environment binding
      ↓
AUTHORIZED or BLOCKED
```

`authorize.sh` calls the Phase 09 OPA evaluator again immediately before authorization. A successful policy evaluation is not a generic approval: it is bound to the repository, digest, policy input, policy version and environment recorded in the evidence.

## Contract

The required artifact reference is:

```text
harbor.example/devshield/backend@sha256:<64 lowercase hexadecimal characters>
```

`latest`, `production`, version tags and any other mutable reference are rejected. The policy input reference and digest must equal the requested deployment reference. The generated evidence contains the exact artifact, policy decision/version/hashes, source information, environment, reasons and timestamp.

Exit codes are:

| Code | Meaning |
| ---: | --- |
| 0 | `AUTHORIZED` |
| 1 | `POLICY_DENIED` or `VERIFICATION_FAILURE` |
| 2 | `TOOL_FAILURE` or invalid invocation |

No deploy step exists yet. When one is added, it must require this command to succeed and must use the exact reference passed to it. It must not use `continue-on-error` on authorization.

The CI authorization job is intentionally opt-in through the `DEVSHIELD_DEPLOYMENT_ENABLED` repository variable and only runs on a push. Pull requests can exercise policy and local authorization tests, but cannot create a production deployment path.

## Environment requirements

Production and staging use the strict Phase 09 policy: trusted registry, immutable digest, passing SAST/secret/SCA/container evidence, matching SBOM, verified signature, trusted signer and trusted provenance. Development still uses the same immutable deployment reference and security evidence; its policy may be less strict about registry/signing/provenance for local workflows. Development convenience is never inherited by staging or production.

## Failure and replay behavior

OPA denial, OPA unavailability, malformed input, a digest mismatch, a mutable tag, untrusted registry, missing or invalid signature, wrong signer, missing SBOM or invalid provenance all block authorization. A Harbor outage cannot create trusted registry evidence and therefore cannot authorize production.

Authorization is intentionally short-lived operational evidence: the policy is re-evaluated for each authorization request. A stored evidence file is not sufficient by itself for a new deployment; `validate-evidence.sh` only checks its contract binding and is not a replacement for fresh authorization.

## Invariants

* I1: production deployment references an immutable artifact.
* I2: deployed digest equals authorized digest.
* I3: OPA `DENY` prevents deployment.
* I4: missing mandatory evidence prevents deployment.
* I5: signature verification precedes authorization.
* I6: signer identity satisfies the environment policy.
* I7: policy failure never becomes implicit authorization.
* I8: registry failure never becomes implicit authorization.
* I9: authorization is environment-specific.
* I10: evidence identifies the exact artifact digest.

## Future admission control

The future runtime path can be:

```text
deployment request → OPA/authorization contract → admission layer → runtime
```

Gatekeeper, Kubernetes admission and GitOps enforcement are deliberately deferred until a runtime exists.
