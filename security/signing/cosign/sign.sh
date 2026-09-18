#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

[[ "${DEVSHIELD_GATE_CONFIRMED:-0}" == 1 ]] || { echo 'SECURITY_FAILURE: refusing to sign without a successful DevShield security gate' >&2; exit 1; }
reference="${1:-$(security/signing/cosign/digest.sh)}"
validate_digest_reference "$reference"
validate_approved_registry "$reference"
require_cosign_version
registry_login

mode="${DEVSHIELD_SIGNING_MODE:-key}"
signer=''
case "$mode" in
  key)
    key="${DEVSHIELD_COSIGN_PRIVATE_KEY:-$repo_root/.local/cosign/cosign.key}"
    [[ -f "$key" ]] || { echo "TOOL_FAILURE: Cosign private key not found at ${key}" >&2; exit 2; }
    : "${COSIGN_PASSWORD:?Set COSIGN_PASSWORD without printing it}"
    signer="public-key:$(sha256sum "${key%.key}.pub" 2>/dev/null | awk '{print $1}')"
    [[ "$signer" != public-key: ]] || { echo 'TOOL_FAILURE: matching Cosign public key not found' >&2; exit 2; }
    key_relative="${key#"$repo_root/"}"
    cosign_run sign --key "/work/$key_relative" --yes "$reference" >/dev/null || { echo 'TOOL_FAILURE: Cosign signing failed' >&2; exit 2; }
    ;;
  keyless)
    [[ "${GITHUB_EVENT_NAME:-}" == push && "${GITHUB_REF:-}" == refs/heads/main ]] || { echo 'SECURITY_FAILURE: keyless trusted signing is restricted to pushes on main' >&2; exit 1; }
    signer="${COSIGN_CERTIFICATE_IDENTITY:?Set COSIGN_CERTIFICATE_IDENTITY for keyless signing}"
    export COSIGN_CERTIFICATE_OIDC_ISSUER="${COSIGN_CERTIFICATE_OIDC_ISSUER:-https://token.actions.githubusercontent.com}"
    cosign_run sign --yes "$reference" >/dev/null || { echo 'TOOL_FAILURE: keyless Cosign signing failed' >&2; exit 2; }
    ;;
  *) echo "TOOL_FAILURE: unsupported signing mode ${mode}" >&2; exit 2 ;;
esac

output="${DEVSHIELD_SIGNING_EVIDENCE:-$repo_root/reports/cosign-signing-evidence.json}"
write_json_evidence "$output" SIGNED "$reference" "$mode" "$signer" false
echo "Cosign signing: PASS ($reference)"
