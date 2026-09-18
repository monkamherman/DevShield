#!/usr/bin/env bash
set -euo pipefail
endpoint="${HARBOR_URL:-https://harbor.local:8443}"
root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
ca="${HARBOR_CA_CERT:-$root/infrastructure/registry/secrets/ca.crt}"
ca_args=(); [[ -f "$ca" ]] && ca_args+=(--cacert "$ca")
status="$(curl --silent --show-error --connect-timeout 5 --output /dev/null --write-out "%{http_code}" "${ca_args[@]}" "$endpoint/api/v2.0/systeminfo")" || { echo "INFRASTRUCTURE_FAILURE: Harbor unavailable at $endpoint" >&2; exit 2; }
case "$status" in
  200|401|403) echo "Harbor: PASS ($endpoint, HTTP $status)" ;;
  *) echo "INFRASTRUCTURE_FAILURE: Harbor returned HTTP $status at $endpoint" >&2; exit 2 ;;
esac
