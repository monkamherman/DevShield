#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"
name="${WAF_CONTAINER_NAME:-$WAF_DEFAULT_NAME}"
url="${WAF_URL:-http://127.0.0.1:${WAF_PORT:-8080}/health}"
docker inspect "$name" >/dev/null 2>&1 || { echo 'WAF_STARTUP_FAILURE: container does not exist' >&2; exit 2; }
running="$(docker inspect --format '{{.State.Running}}' "$name")"
[[ "$running" == true ]] || { echo 'WAF_STARTUP_FAILURE: container is not running' >&2; exit 2; }
docker exec "$name" test -d /opt/coraza/owasp-crs/rules || { echo 'WAF_CRS_FAILURE: CRS rule directory is not loaded' >&2; exit 2; }
docker exec "$name" test -s /opt/coraza/config/coraza-rules.conf || { echo 'WAF_CRS_FAILURE: Coraza rule chain is not loaded' >&2; exit 2; }
curl --fail --silent --show-error --max-time "${WAF_HEALTH_TIMEOUT:-5}" "$url" >/dev/null || { echo 'WAF_UPSTREAM_FAILURE: WAF health endpoint is not reachable' >&2; exit 3; }
echo "WAF_READY: ${name} ${url}"
