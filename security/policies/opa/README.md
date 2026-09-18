# OPA/Rego policy engine

OPA is the decision engine for Phase 09. Scanners and Cosign remain evidence producers; OPA only evaluates the normalized input in `reports/policy-input.json`.

The source of truth is `policy.rego`, versioned with Git. The wrapper uses official OPA `v1.20.2`, downloaded only by `install.sh` from the official release URL and verified against the pinned Linux amd64 SHA-256 checksum. Run `make opa-install` and `make opa-version` locally or in CI.

The normalized input contains:

```text
artifact.repository/reference/digest
source.repository/commit/branch
environment
security.sast/secrets/sca/container
sbom
registry
signature
provenance
policy.trusted_registries/trusted_repositories/trusted_signers
```

Development requires a valid digest, passing controls and a matching SBOM, but does not require Harbor or a signature. Staging and production additionally require an approved registry, digest-bound verified signature, trusted signer and trusted provenance. Critical, high and unknown vulnerabilities deny every environment. Missing or unknown evidence fails closed.

`evaluate.sh` writes `reports/policy-decision-evidence.json`, including policy/OPA versions, policy and input hashes, artifact identity, environment, decision and reasons. A `DENY` returns exit code 1; an OPA or input error returns exit code 2.

OPA is not a deployment controller and does not sign artifacts. Phase 09 does not implement Gatekeeper, admission control or production deployment.
