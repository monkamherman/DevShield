package devshield.policy_test

import rego.v1
import data.devshield.policy

base := {
  "schema_version": "1.0",
  "policy": {"version": "1.0.0", "trusted_registries": ["harbor.example.test"], "trusted_signers": ["oidc:devshield-main"]},
  "environment": "production",
  "artifact": {"repository": "harbor.example.test/devshield/fixture", "reference": "harbor.example.test/devshield/fixture@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", "digest": "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"},
  "source": {"repository": "org/devshield", "commit": "abc123"},
  "security": {"sast": {"status": "PASS"}, "secrets": {"status": "PASS"}, "sca": {"status": "PASS", "critical": 0, "high": 0, "unknown": 0}, "container": {"status": "PASS", "critical": 0, "high": 0, "unknown": 0}},
  "sbom": {"present": true, "digest": "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"},
  "registry": {"trusted": true, "digest": "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"},
  "signature": {"signed": true, "verified": true, "digest": "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", "signer": "oidc:devshield-main"},
  "provenance": {"present": true, "trusted": true, "digest": "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", "source_commit": "abc123"}
}

test_valid_production if {
  result := policy.decision with input as base
  result.decision == "ALLOW"
}

test_development_allows_unsigned_local_artifact if {
  local := object.union(base, {"environment": "development", "registry": {"trusted": false, "digest": null}, "signature": {"signed": false, "verified": false, "digest": null, "signer": null}, "provenance": {"present": false, "trusted": false, "digest": null, "source_commit": null}})
  result := policy.decision with input as local
  result.decision == "ALLOW"
}

test_missing_digest_denies if {
  altered := object.union(base, {"artifact": object.union(base.artifact, {"digest": null})})
  result := policy.decision with input as altered
  result.decision == "DENY"
}

test_mutable_production_reference_denies if {
  altered := object.union(base, {"artifact": object.union(base.artifact, {"reference": "harbor.example.test/devshield/fixture:latest"})})
  result := policy.decision with input as altered
  result.decision == "DENY"
}

test_critical_vulnerability_denies if {
  altered := object.union(base, {"security": object.union(base.security, {"sca": object.union(base.security.sca, {"critical": 1})})})
  result := policy.decision with input as altered
  result.decision == "DENY"
}

test_unknown_container_finding_denies if {
  altered := object.union(base, {"security": object.union(base.security, {"container": object.union(base.security.container, {"unknown": 1})})})
  result := policy.decision with input as altered
  result.decision == "DENY"
}

test_missing_sbom_denies if {
  altered := object.union(base, {"sbom": {"present": false, "digest": null}})
  result := policy.decision with input as altered
  result.decision == "DENY"
}

test_sbom_tampering_denies if {
  altered := object.union(base, {"sbom": {"present": true, "digest": "sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"}})
  result := policy.decision with input as altered
  result.decision == "DENY"
}

test_untrusted_registry_denies if {
  altered := object.union(base, {"registry": {"trusted": false, "digest": base.artifact.digest}})
  result := policy.decision with input as altered
  result.decision == "DENY"
}

test_missing_signature_denies if {
  altered := object.union(base, {"signature": {"signed": false, "verified": false, "digest": null, "signer": null}})
  result := policy.decision with input as altered
  result.decision == "DENY"
}

test_wrong_digest_signature_denies if {
  altered := object.union(base, {"signature": object.union(base.signature, {"digest": "sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"})})
  result := policy.decision with input as altered
  result.decision == "DENY"
}

test_wrong_signer_denies if {
  altered := object.union(base, {"signature": object.union(base.signature, {"signer": "oidc:untrusted"})})
  result := policy.decision with input as altered
  result.decision == "DENY"
}

test_missing_provenance_denies if {
  altered := object.union(base, {"provenance": {"present": false, "trusted": false, "digest": null, "source_commit": null}})
  result := policy.decision with input as altered
  result.decision == "DENY"
}

test_sast_failure_denies if {
  altered := object.union(base, {"security": object.union(base.security, {"sast": {"status": "SECURITY_FAILURE"}})})
  result := policy.decision with input as altered
  result.decision == "DENY"
}
