#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"
reference="${1:-$(security/signing/cosign/digest.sh)}"
validate_digest_reference "$reference"
validate_approved_registry "$reference"
require_cosign_version
if ! cosign_run tree "$reference"; then
  echo 'VERIFICATION_FAILURE: unable to inspect Cosign signatures for the digest' >&2
  exit 1
fi
