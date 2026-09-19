#!/usr/bin/env bash
set -euo pipefail

docker_bin="${DEVSHIELD_DOCKER_BIN:-docker}"
curl_bin="${DEVSHIELD_CURL_BIN:-curl}"
container_name="${CONTAINER_NAME:-}"
url="${HEALTHCHECK_URL:-}"
timeout_seconds="${HEALTHCHECK_TIMEOUT:-5}"
retries="${HEALTHCHECK_RETRIES:-10}"
fail() { echo "HEALTHCHECK_FAILED: $*" >&2; exit 1; }
[[ -n "$container_name" ]] || fail 'CONTAINER_NAME is required'
[[ -n "$url" && "$url" =~ ^https?://[^[:space:]@]+$ ]] || fail 'HEALTHCHECK_URL must be HTTP(S) without credentials'
[[ "$timeout_seconds" =~ ^[1-9][0-9]*$ && "$retries" =~ ^[1-9][0-9]*$ ]] || fail 'HEALTHCHECK_TIMEOUT/RETRIES are invalid'
command -v "$docker_bin" >/dev/null 2>&1 || fail 'Docker executable is unavailable'
command -v "$curl_bin" >/dev/null 2>&1 || fail 'curl executable is unavailable'
"$docker_bin" inspect "$container_name" >/dev/null 2>&1 || fail 'container does not exist'
[[ "$("$docker_bin" inspect --format '{{.State.Running}}' "$container_name")" == true ]] || fail 'container is not running'
for ((attempt=1; attempt<=retries; attempt++)); do
  if "$curl_bin" --fail --silent --show-error --max-time "$timeout_seconds" "$url" >/dev/null 2>&1; then
    echo "HEALTHCHECK_PASSED: container=${container_name} attempt=${attempt}"
    exit 0
  fi
  [[ "$attempt" -lt "$retries" ]] && sleep 1
done
fail "endpoint did not respond after ${retries} attempt(s)"

