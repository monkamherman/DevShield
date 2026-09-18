# Phase 09 — Policy as Code with OPA/Rego

## Purpose

OPA is the central decision engine for accumulated DevShield evidence. It does not scan source, inspect dependencies, sign images or replace the existing gate. It answers whether an artifact satisfies the policy for a requested environment.

```text
scanner evidence → normalized input → OPA/Rego → ALLOW or DENY → policy evidence
```

## Normalized input

`security/policies/opa/normalize.sh` reads the existing metadata files without changing them:

| Existing evidence | Normalized field |
| --- | --- |
| `semgrep-metadata.json` | `security.sast` |
| `gitleaks-metadata.json` | `security.secrets` |
| `trivy-sca-metadata.json` | `security.sca` |
| `trivy-container-metadata.json` | `security.container` |
| `artifact-inventory.json` | `sbom` and artifact digest |
| `container-build-metadata.json` | local artifact/source identity |
| `registry-push-evidence.json` | Harbor registry and digest |
| `cosign-signing-evidence.json` | signature, digest and signer |
| optional `provenance.json` | provenance |

The complete normalized document is written to `reports/policy-input.json`. It contains `schema_version`, `policy`, `environment`, `artifact`, `source`, `security`, `sbom`, `registry`, `signature`, `provenance` and evidence references. Missing evidence is represented as `MISSING`, `false` or `null`; it is never silently treated as valid.

Trusted registries, repositories and signers are supplied as configuration (`DEVSHIELD_TRUSTED_REGISTRY`, `DEVSHIELD_TRUSTED_REPOSITORY` and `DEVSHIELD_TRUSTED_SIGNER`) and are copied into the input so the decision is auditable. An empty repository list means any repository in the trusted registry; production CI should configure an explicit project/repository allowlist. These values are not arbitrary values hardcoded in Rego.

## Policy behavior

All environments require:

- a repository and valid `sha256` digest;
- SAST, secret detection, SCA and container status `PASS`;
- zero CRITICAL, HIGH and UNKNOWN findings;
- an SBOM whose digest equals the artifact digest.

Development allows a local digest without Harbor, signature or provenance for fast feedback. Staging and production additionally require:

- a trusted Harbor registry;
- a signed and verified signature bound to the artifact digest;
- a signer present in the configured trusted signer list;
- trusted provenance matching both source commit and artifact digest;
- a digest-only artifact reference, never a mutable production tag.

MEDIUM and LOW findings remain visible in scanner evidence but do not deny under the existing Phase 04/05 baseline. UNKNOWN denies fail closed. No vulnerability exception mechanism is implemented.

## Decision and evidence

`security/policies/opa/evaluate.sh` runs the versioned `policy.rego` and writes `reports/policy-decision-evidence.json`. The evidence contains policy version, OPA version, policy hash, normalized input hash, artifact, environment, decision, reasons, timestamp and source commit.

- `ALLOW` exits `0`;
- `DENY` exits `1` and is a security/policy failure;
- missing input, invalid policy or OPA execution failure exits `2` as `TOOL_FAILURE`.

The policy hash and input hash make local/CI decisions traceable. Policy changes require Git review and CI validation.

## CI integration

The policy job runs after the scanner gate and optional Harbor/Cosign evidence is available. On pull requests it evaluates the configured development policy by default; production/staging jobs must set `DEVSHIELD_POLICY_ENVIRONMENT` and the trusted registry/signer variables. OPA cannot authorize an artifact before the existing scanner gate, and it cannot create a signature.

## Tampering and limitations

Changing the artifact digest, SBOM digest, signature digest, signer, registry trust or provenance fields produces `DENY` when the affected environment requires that evidence. Hashes in policy evidence detect changes to the input and policy files after evaluation; they are not a replacement for signed evidence or Git review.

OPA is not a deployment controller. Kubernetes admission, Gatekeeper, production deployment authorization and automated exceptions are future work.

## Local commands

```bash
make opa-install
make opa-version
make policy-test
make policy-input
make policy-check POLICY_INPUT=reports/policy-input.json
make security-policy
```
