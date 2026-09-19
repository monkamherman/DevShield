#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/../signing/cosign/common.sh"

reference="${1:-$(security/signing/cosign/digest.sh)}"
predicate="${DEVSHIELD_PROVENANCE_PREDICATE:-$repo_root/reports/provenance-predicate.json}"
predicate_type="${DEVSHIELD_PROVENANCE_PREDICATE_TYPE:-https://devshield.dev/provenance/v1}"

[[ "${DEVSHIELD_GATE_CONFIRMED:-0}" == 1 ]] || { echo 'SECURITY_FAILURE: refusing provenance attestation without a successful DevShield security gate' >&2; exit 1; }
validate_digest_reference "$reference"
validate_approved_registry "$reference"
[[ -s "$predicate" ]] || { echo "TOOL_FAILURE: provenance predicate is missing at $predicate" >&2; exit 2; }
require_cosign_version
registry_login

relative="${predicate#"$repo_root/"}"
cosign_run attest --yes --type "$predicate_type" --predicate "/work/$relative" "$reference" >/dev/null || {
  echo 'TOOL_FAILURE: Cosign provenance attestation failed' >&2
  exit 2
}
echo "Cosign attestation: PASS ($reference)"
