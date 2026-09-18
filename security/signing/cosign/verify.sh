#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

reference="${1:-$(security/signing/cosign/digest.sh)}"
validate_digest_reference "$reference"
validate_approved_registry "$reference"
require_cosign_version
registry_login
mode="${DEVSHIELD_SIGNING_MODE:-key}"
signer=''
verify_args=(verify)
case "$mode" in
  key)
    key="${DEVSHIELD_COSIGN_PUBLIC_KEY:-$repo_root/.local/cosign/cosign.pub}"
    [[ -f "$key" ]] || { echo "VERIFICATION_FAILURE: trusted Cosign public key not found at ${key}" >&2; exit 1; }
    signer="public-key:$(sha256sum "$key" | awk '{print $1}')"
    verify_args+=(--key "/work/${key#"$repo_root/"}")
    ;;
  keyless)
    signer="${COSIGN_CERTIFICATE_IDENTITY:?Set COSIGN_CERTIFICATE_IDENTITY for keyless verification}"
    verify_args+=(--certificate-identity "$signer" --certificate-oidc-issuer "${COSIGN_CERTIFICATE_OIDC_ISSUER:-https://token.actions.githubusercontent.com}")
    ;;
  *) echo "TOOL_FAILURE: unsupported signing mode ${mode}" >&2; exit 2 ;;
esac
if ! cosign_run "${verify_args[@]}" "$reference" >/dev/null 2>&1; then
  echo 'VERIFICATION_FAILURE: Cosign signature is missing, invalid, for the wrong digest or from the wrong signer' >&2
  exit 1
fi

output="${DEVSHIELD_SIGNING_EVIDENCE:-$repo_root/reports/cosign-signing-evidence.json}"
if [[ -s "$output" ]]; then
  export DEVSHIELD_EVIDENCE_OUTPUT="$output" DEVSHIELD_EVIDENCE_REFERENCE="$reference" DEVSHIELD_EVIDENCE_MODE="$mode" DEVSHIELD_EVIDENCE_SIGNER="$signer" DEVSHIELD_EVIDENCE_VERIFIED=true DEVSHIELD_COSIGN_VERSION="$COSIGN_VERSION" DEVSHIELD_COMMIT="${GITHUB_SHA:-$(git rev-parse HEAD 2>/dev/null || echo unknown)}"
  node <<'NODE'
const fs = require('fs');
const p = process.env.DEVSHIELD_EVIDENCE_OUTPUT;
const x = JSON.parse(fs.readFileSync(p, 'utf8'));
x.signature_status = x.signature_status || 'SIGNED';
x.verification_status = 'VERIFIED';
x.verified = true;
x.signer_identity = process.env.DEVSHIELD_EVIDENCE_SIGNER;
x.timestamp = new Date().toISOString();
fs.writeFileSync(p, `${JSON.stringify(x, null, 2)}\n`);
NODE
else
  write_json_evidence "$output" SIGNED "$reference" "$mode" "$signer" true
fi
echo "Cosign verification: PASS ($reference)"
