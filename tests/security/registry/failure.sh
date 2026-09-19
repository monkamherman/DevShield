#!/usr/bin/env bash
set -euo pipefail
log="$(mktemp)"
trap 'rm -f "$log"' EXIT
if DEVSHIELD_SKIP_SECURITY_GATE=1 DEVSHIELD_GATE_CONFIRMED=0 HARBOR_REGISTRY=unused security/registry/push.sh >"$log" 2>&1; then
  echo "SECURITY_FAILURE test: push bypass was accepted" >&2; exit 1
fi
grep -q 'refusing ungated registry push' "$log"
echo 'Failed security gate prevents registry push: PASS'
