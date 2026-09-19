#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"
name="${DEVSHIELD_RUNTIME_CONTAINER_NAME:-$RUNTIME_CONTAINER_NAME}"
docker_available || { echo 'RUNTIME_SECURITY_TOOL_FAILURE: Docker daemon is unavailable' >&2; exit 2; }
docker_cmd inspect "$name" >/dev/null 2>&1 || { echo 'RUNTIME_SECURITY_STARTUP_FAILURE: Falco container does not exist' >&2; exit 2; }
running="$(docker_cmd inspect --format '{{.State.Running}}' "$name")"
[[ "$running" == true ]] || { echo 'RUNTIME_SECURITY_STARTUP_FAILURE: Falco container is not running' >&2; exit 2; }
docker_cmd exec "$name" test -s /etc/falco/rules.d/devshield-rules.yaml || { echo 'RUNTIME_SECURITY_RULE_FAILURE: DevShield rules are not mounted' >&2; exit 2; }
docker_cmd exec "$name" falco --version >/dev/null 2>&1 || { echo 'RUNTIME_SECURITY_TOOL_FAILURE: Falco process is not usable' >&2; exit 2; }
if docker_cmd logs "$name" 2>&1 | grep -Eiq 'error loading|failed to load.*rule|cannot.*load.*rule'; then
  echo 'RUNTIME_SECURITY_RULE_FAILURE: Falco reported a rule loading error' >&2
  exit 2
fi
echo "RUNTIME_SECURITY_READY: ${name} rules_hash=$(rules_hash)"
