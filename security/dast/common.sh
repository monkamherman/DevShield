#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ZAP_IMAGE="${DEVSHIELD_ZAP_IMAGE:-zaproxy/zap-stable:2.15.0}"
ZAP_VERSION="2.15.0"

dast_error() {
  echo "$1: $2" >&2
  return 1
}

validate_environment() {
  case "$1" in
    development|staging|production) return 0 ;;
    *) dast_error CONFIGURATION_FAILURE "unsupported DAST environment: $1" ;;
  esac
}

parse_target() {
  node - "$1" <<'NODE'
const value = process.argv[2];
try {
  const url = new URL(value);
  if (!['http:', 'https:'].includes(url.protocol) || !url.hostname || url.username || url.password || url.search || url.hash) process.exit(1);
  if (url.port && (!/^\d+$/.test(url.port) || Number(url.port) < 1 || Number(url.port) > 65535)) process.exit(1);
  process.stdout.write(JSON.stringify({protocol:url.protocol, host:url.hostname, port:url.port || null}));
} catch (_) { process.exit(1); }
NODE
}

validate_target_configuration() {
  local target="$1" allowed_hosts="${2:-${DEVSHIELD_DAST_ALLOWED_HOSTS:-localhost,127.0.0.1,::1}}"
  local parsed
  if ! parsed="$(parse_target "$target" 2>/dev/null)"; then
    dast_error CONFIGURATION_FAILURE "invalid target URL"
    return 1
  fi
  local host
  host="$(node -e 'process.stdout.write(JSON.parse(process.argv[1]).host)' "$parsed")"
  local allowed=0 candidate
  IFS=',' read -ra candidates <<< "$allowed_hosts"
  for candidate in "${candidates[@]}"; do
    [[ "${candidate//[[:space:]]/}" == "$host" ]] && allowed=1
  done
  if [[ "$allowed" -ne 1 ]]; then
    dast_error CONFIGURATION_FAILURE "target host ${host} is not explicitly allowed"
    return 1
  fi
  printf '%s\n' "$parsed"
}

check_target_reachable() {
  local target="$1" timeout_seconds="${2:-10}" code curl_status
  local curl_bin="curl"
  if [[ "${DEVSHIELD_DAST_TEST_MODE:-0}" == "1" && -n "${DEVSHIELD_CURL_BIN:-}" ]]; then curl_bin="$DEVSHIELD_CURL_BIN"; fi
  set +e
  code="$($curl_bin --silent --show-error --output /dev/null --write-out '%{http_code}' --connect-timeout "$timeout_seconds" --max-time "$timeout_seconds" "$target" 2>"${TMPDIR:-/tmp}/devshield-dast-curl.err")"
  curl_status=$?
  set -e
  if [[ "$curl_status" -eq 28 ]]; then
    echo "TARGET_TIMEOUT: target did not respond within ${timeout_seconds}s" >&2
    return 3
  elif [[ "$curl_status" -ne 0 ]]; then
    local detail
    detail="$(tr '\n' ' ' < "${TMPDIR:-/tmp}/devshield-dast-curl.err")"
    echo "TARGET_FAILURE: target is unreachable${detail:+: $detail}" >&2
    return 3
  fi
  [[ "$code" =~ ^[0-9]{3}$ ]] || { echo 'TARGET_FAILURE: target returned no HTTP status' >&2; return 3; }
  echo "TARGET_REACHABLE: ${code} ${target}"
}
