#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"
name="${DEVSHIELD_RUNTIME_CONTAINER_NAME:-$RUNTIME_CONTAINER_NAME}"
docker_cmd rm -f "$name" >/dev/null 2>&1 || true
echo "RUNTIME_SECURITY_STOPPED: ${name}"
