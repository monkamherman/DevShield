# DevShield provenance

Production provenance is generated in CI from the actual BuildKit metadata,
SBOM inventory and Harbor digest. `generate.sh` refuses missing, fabricated or
inconsistent commit/digest values and emits:

* `reports/provenance.json`: normalized evidence consumed by OPA;
* `reports/provenance-predicate.json`: an in-toto Statement used as the Cosign
  OCI attestation predicate.

GitHub Actions attests the predicate with the existing pinned keyless Cosign
workflow. `verify.sh` verifies that attestation using only the public identity
and OIDC issuer, then reconstructs the normalized evidence on a VPS. It never
requires a private key, Cosign password, GitHub token or OIDC token.

The requested artifact reference, attested digest, source commit and SBOM
digest must all match. Any mismatch fails closed before OPA or deployment.
