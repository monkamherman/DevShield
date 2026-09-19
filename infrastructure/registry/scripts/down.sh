#!/usr/bin/env bash
set -euo pipefail
root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"; runtime="$root/infrastructure/registry/runtime"
compose="${HARBOR_COMPOSE_FILE:-$runtime/docker-compose.yml}"
[[ -f "$compose" ]] || { echo 'INFRASTRUCTURE_FAILURE: Harbor Compose file not found; run the official installer first' >&2; exit 2; }
docker compose -f "$compose" down
