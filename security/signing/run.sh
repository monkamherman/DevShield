#!/usr/bin/env bash
set -euo pipefail
root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$root"
if [[ "${DEVSHIELD_SKIP_SECURITY_GATE:-0}" == 1 ]]; then
  [[ "${DEVSHIELD_GATE_CONFIRMED:-0}" == 1 ]] || { echo 'SECURITY_FAILURE: signing requires explicit gate confirmation' >&2; exit 1; }
else
  make security
  export DEVSHIELD_GATE_CONFIRMED=1
fi

if [[ "${DEVSHIELD_SKIP_SECURITY_GATE:-0}" != 1 ]]; then
  DEVSHIELD_SKIP_SECURITY_GATE=1 DEVSHIELD_GATE_CONFIRMED=1 make registry-push
fi

reference="$(security/signing/cosign/digest.sh)"
security/signing/cosign/sign.sh "$reference"
security/signing/cosign/verify.sh "$reference"
echo "DevShield signing flow: PASS ($reference)"
