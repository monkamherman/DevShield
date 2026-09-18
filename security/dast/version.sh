#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"
echo "OWASP ZAP image: ${ZAP_IMAGE}"
echo "OWASP ZAP pinned version: ${ZAP_VERSION}"
if command -v docker >/dev/null 2>&1; then
  set +e
  docker image inspect "$ZAP_IMAGE" >/dev/null 2>&1
  cached=$?
  set -e
  if [[ "$cached" -eq 0 ]]; then echo "Docker image status: available locally"; else echo "Docker image status: not present locally"; fi
else
  echo "Docker image status: Docker unavailable"
fi
