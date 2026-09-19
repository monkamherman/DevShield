#!/usr/bin/env bash
set -euo pipefail
root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$root"
source security/policies/opa/common.sh
require_opa
"$opa_bin" test security/policies/opa tests/security/policy/policy_test.rego --format pretty
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT
evidence_dir="$tmp_dir/evidence"
mkdir -p "$evidence_dir"
printf '%s\n' '{"result":"PASS","repository":"org/devshield","commit":"abc123"}' > "$evidence_dir/semgrep-metadata.json"
printf '%s\n' '{"result":"PASS","repository":"org/devshield","commit":"abc123"}' > "$evidence_dir/gitleaks-metadata.json"
printf '%s\n' '{"result":"PASS","vulnerability_counts":{"CRITICAL":0,"HIGH":0,"MEDIUM":1,"LOW":0,"UNKNOWN":0}}' > "$evidence_dir/trivy-sca-metadata.json"
printf '%s\n' '{"result":"PASS","image_findings":[],"configuration_findings":[]}' > "$evidence_dir/trivy-container-metadata.json"
printf '%s\n' '{"repository":"local","commit":"abc123","image":"devshield:fixture","image_digest":"sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}' > "$evidence_dir/container-build-metadata.json"
printf '%s\n' '{"result":"PASS","artifact":{"type":"container-image","reference":"devshield:fixture","digest":"sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"},"source":{"repository":"local","commit":"abc123"},"sbom":{"format":"CycloneDX JSON"}}' > "$evidence_dir/artifact-inventory.json"
security/policies/opa/normalize.sh --environment development --evidence-root "$evidence_dir" --output "$tmp_dir/normalized.json"
grep -q '"schema_version": "1.0"' "$tmp_dir/normalized.json"
grep -q '"digest": "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"' "$tmp_dir/normalized.json"
if security/policies/opa/evaluate.sh --input tests/security/fixtures/policy/valid-production.json --output "$tmp_dir/valid-evidence.json"; then
  grep -q '"decision": "ALLOW"' "$tmp_dir/valid-evidence.json"
else
  echo 'Expected valid production policy input to ALLOW.' >&2
  exit 1
fi
if security/policies/opa/evaluate.sh --input tests/security/fixtures/policy/critical.json --output "$tmp_dir/critical-evidence.json"; then
  echo 'Expected critical vulnerability policy input to DENY.' >&2
  exit 1
fi
grep -q '"decision": "DENY"' "$tmp_dir/critical-evidence.json"
if security/policies/opa/evaluate.sh --input tests/security/fixtures/policy/valid-production.json --environment development --output "$tmp_dir/mismatch-evidence.json"; then
  echo 'Expected environment mismatch to fail closed.' >&2
  exit 1
fi
echo 'OPA/Rego policy positive, negative and tampering tests: PASS'
