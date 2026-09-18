#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

name="${DEVSHIELD_RUNTIME_CONTAINER_NAME:-$RUNTIME_CONTAINER_NAME}"
require_runtime_files
"$repo_root/security/runtime/validate.sh"
docker_available || { echo 'RUNTIME_SECURITY_STARTUP_FAILURE: Docker daemon is unavailable' >&2; exit 2; }
docker_cmd rm -f "$name" >/dev/null 2>&1 || true
docker_cmd run -d --name "$name" \
  --cap-drop ALL \
  --cap-add SYS_ADMIN \
  --cap-add SYS_RESOURCE \
  --cap-add SYS_PTRACE \
  -v /sys/kernel/tracing:/sys/kernel/tracing:ro \
  -v /var/run/docker.sock:/host/var/run/docker.sock:ro \
  -v /proc:/host/proc:ro \
  -v /etc:/host/etc:ro \
  -v "$config_file:/etc/falco/falco.yaml:ro" \
  -v "$rules_file:/etc/falco/rules.d/devshield-rules.yaml:ro" \
  "$FALCO_IMAGE" >/dev/null || { echo 'RUNTIME_SECURITY_STARTUP_FAILURE: unable to start Falco' >&2; exit 2; }
printf 'RUNTIME_SECURITY_STARTED: name=%s falco=%s driver=%s rules_hash=%s config_hash=%s\n' "$name" "$FALCO_VERSION" "$FALCO_DRIVER" "$(rules_hash)" "$(config_hash)"
