#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

: "${COSIGN_PASSWORD:?Set COSIGN_PASSWORD without printing it}"
key_dir="${DEVSHIELD_COSIGN_KEY_DIR:-$repo_root/.local/cosign}"
key_prefix="$key_dir/cosign"
[[ "$key_dir" == "$repo_root"/* ]] || { echo 'SECURITY_FAILURE: Cosign key directory must be inside the ignored repository-local .local directory' >&2; exit 1; }
if [[ -e "$key_prefix.key" || -e "$key_prefix.pub" ]] && [[ "${DEVSHIELD_FORCE_KEYGEN:-0}" != 1 ]]; then
  echo "SECURITY_FAILURE: refusing to overwrite existing Cosign key pair in ${key_dir}" >&2
  exit 1
fi
mkdir -p "$key_dir"
chmod 700 "$key_dir"
umask 077
require_cosign_version
cosign_run generate-key-pair --output-key-prefix "/work/${key_prefix#"$repo_root/"}" >/dev/null
chmod 600 "$key_prefix.key"
chmod 644 "$key_prefix.pub"
echo "Cosign key pair: PASS (${key_prefix}.pub; private key remains local)"
