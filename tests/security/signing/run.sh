#!/usr/bin/env bash
set -euo pipefail
root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$root"

test ! -e .local/cosign/cosign.key
test -z "$(git ls-files | grep -E '(^|/)(cosign\.key|cosign\.pub)$' || true)"

digest="harbor.example.test/devshield/fixture@sha256:$(printf 'a%.0s' {1..64})"
if DEVSHIELD_GATE_CONFIRMED=0 HARBOR_REGISTRY=harbor.example.test security/signing/cosign/sign.sh "$digest"; then
  echo 'Expected signing without gate confirmation to fail.' >&2
  exit 1
fi
if DEVSHIELD_GATE_CONFIRMED=1 HARBOR_REGISTRY=harbor.example.test security/signing/cosign/sign.sh harbor.example.test/devshield/fixture:latest; then
  echo 'Expected mutable tag signing to fail.' >&2
  exit 1
fi
if DEVSHIELD_GATE_CONFIRMED=1 HARBOR_REGISTRY=harbor.example.test security/signing/cosign/sign.sh "other.example.test/devshield/fixture@sha256:$(printf 'b%.0s' {1..64})"; then
  echo 'Expected wrong-registry signing to fail.' >&2
  exit 1
fi

tests/security/signing/negative.sh
tests/security/signing/digest-mismatch.sh
if [[ "${DEVSHIELD_SIGNING_INTEGRATION:-0}" == 1 ]]; then
  tests/security/signing/integration.sh
fi
echo 'Cosign deterministic policy tests: PASS'
