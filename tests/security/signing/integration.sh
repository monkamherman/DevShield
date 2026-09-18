#!/usr/bin/env bash
set -euo pipefail
root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$root"
: "${HARBOR_REGISTRY:?Set HARBOR_REGISTRY for signing integration tests}"
: "${HARBOR_USERNAME:?Set HARBOR_USERNAME for signing integration tests}"
: "${HARBOR_PASSWORD:?Set HARBOR_PASSWORD for signing integration tests}"
: "${COSIGN_PASSWORD:?Set COSIGN_PASSWORD for signing integration tests}"
: "${UNSIGNED_IMAGE_REF:?Set UNSIGNED_IMAGE_REF to a Harbor digest without a signature}"

key_dir="$root/.local/cosign-test-$$"
second_dir="$root/.local/cosign-test-second-$$"
trap 'rm -rf "$key_dir" "$second_dir"' EXIT
DEVSHIELD_COSIGN_KEY_DIR="$key_dir" COSIGN_PASSWORD="$COSIGN_PASSWORD" security/signing/cosign/keygen.sh
DEVSHIELD_COSIGN_KEY_DIR="$key_dir" COSIGN_PASSWORD="$COSIGN_PASSWORD" DEVSHIELD_SIGNING_MODE=key security/signing/run.sh
reference="$(security/signing/cosign/digest.sh)"

last="${reference: -1}"
replacement=a
[[ "$last" == a ]] && replacement=b
wrong_digest="${reference:0:${#reference}-1}${replacement}"
if DEVSHIELD_COSIGN_PUBLIC_KEY="$key_dir/cosign.pub" DEVSHIELD_SIGNING_MODE=key security/signing/cosign/verify.sh "$wrong_digest"; then
  echo 'Expected wrong digest verification to fail.' >&2
  exit 1
fi

DEVSHIELD_COSIGN_KEY_DIR="$second_dir" COSIGN_PASSWORD="$COSIGN_PASSWORD" security/signing/cosign/keygen.sh
if DEVSHIELD_COSIGN_PUBLIC_KEY="$second_dir/cosign.pub" DEVSHIELD_SIGNING_MODE=key security/signing/cosign/verify.sh "$reference"; then
  echo 'Expected wrong signer verification to fail.' >&2
  exit 1
fi
if DEVSHIELD_COSIGN_PUBLIC_KEY="$key_dir/cosign.pub" DEVSHIELD_SIGNING_MODE=key security/signing/cosign/verify.sh "$UNSIGNED_IMAGE_REF"; then
  echo 'Expected missing signature verification to fail.' >&2
  exit 1
fi
echo 'Cosign valid, wrong-digest, wrong-signer and missing-signature tests: PASS'
