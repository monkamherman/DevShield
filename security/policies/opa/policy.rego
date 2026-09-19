package devshield.policy

import rego.v1

default decision := {"decision": "DENY", "reasons": ["policy did not produce a valid decision"], "policy_version": "unknown"}

decision := {"decision": outcome, "environment": input.environment, "artifact": input.artifact, "reasons": reasons, "policy_version": object.get(input.policy, "version", "unknown")} if {
  outcome := "ALLOW"
  count(reasons) == 0
}

decision := {"decision": outcome, "environment": input.environment, "artifact": input.artifact, "reasons": reasons, "policy_version": object.get(input.policy, "version", "unknown")} if {
  outcome := "DENY"
  count(reasons) > 0
}

reasons := sort([reason | deny_reasons[reason]])

deny_reasons contains "unsupported environment" if { not valid_environment }
deny_reasons contains "artifact repository is missing" if { not is_string(object.get(input.artifact, "repository", "")) }
deny_reasons contains "artifact digest is missing or invalid" if { not valid_digest }
deny_reasons contains "production and staging require a digest-only artifact reference" if { strict_environment; not digest_only_reference }
deny_reasons contains "SAST did not PASS" if { object.get(object.get(input, "security", {}), "sast", {}).status != "PASS" }
deny_reasons contains "secret detection did not PASS" if { object.get(object.get(input, "security", {}), "secrets", {}).status != "PASS" }
deny_reasons contains "SCA did not PASS" if { object.get(object.get(input, "security", {}), "sca", {}).status != "PASS" }
deny_reasons contains "container security did not PASS" if { object.get(object.get(input, "security", {}), "container", {}).status != "PASS" }
deny_reasons contains "critical, high or unknown SCA vulnerabilities are present" if { not sca_vulnerabilities_clear }
deny_reasons contains "critical, high or unknown container findings are present" if { not container_findings_clear }
deny_reasons contains "SBOM is missing or does not match the artifact digest" if { not sbom_valid }
deny_reasons contains "registry is not trusted for this environment" if { strict_environment; not registry_valid }
deny_reasons contains "signature is missing, unverified or bound to another digest" if { strict_environment; not signature_valid }
deny_reasons contains "signature signer is not trusted" if { strict_environment; not signer_valid }
deny_reasons contains "provenance is missing, untrusted or inconsistent" if { strict_environment; not provenance_valid }

valid_environment if { input.environment == "development" }
valid_environment if { input.environment == "staging" }
valid_environment if { input.environment == "production" }
strict_environment if { input.environment == "staging" }
strict_environment if { input.environment == "production" }

valid_digest if {
  is_string(object.get(input.artifact, "digest", ""))
  regex.match("^sha256:[0-9a-f]{64}$", input.artifact.digest)
}

digest_only_reference if {
  is_string(object.get(input.artifact, "reference", ""))
  endswith(input.artifact.reference, sprintf("@%s", [input.artifact.digest]))
}

sca_vulnerabilities_clear if {
  object.get(input.security.sca, "critical", -1) == 0
  object.get(input.security.sca, "high", -1) == 0
  object.get(input.security.sca, "unknown", -1) == 0
}

container_findings_clear if {
  object.get(input.security.container, "critical", -1) == 0
  object.get(input.security.container, "high", -1) == 0
  object.get(input.security.container, "unknown", -1) == 0
}

sbom_valid if {
  input.sbom.present == true
  input.sbom.digest == input.artifact.digest
}

registry_valid if {
  input.registry.trusted == true
  input.registry.digest == input.artifact.digest
  trusted_repository
}

trusted_repository if {
  count(object.get(input.policy, "trusted_repositories", [])) == 0
}

trusted_repository if {
  some repository in object.get(input.policy, "trusted_repositories", [])
  repository == input.registry.repository
}

signature_valid if {
  input.signature.signed == true
  input.signature.verified == true
  input.signature.digest == input.artifact.digest
}

signer_valid if {
  some signer in object.get(input.policy, "trusted_signers", [])
  signer == input.signature.signer
}

provenance_valid if {
  input.provenance.present == true
  input.provenance.trusted == true
  input.provenance.digest == input.artifact.digest
  input.provenance.source_commit == input.source.commit
}
