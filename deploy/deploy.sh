#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

config_file="${DEVSHIELD_RUNTIME_ENV_FILE:-$deploy_root/runtime.env}"
authorization_evidence=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --env-file) config_file="$2"; shift 2 ;;
    --authorization-evidence) authorization_evidence="$2"; shift 2 ;;
    *) echo 'TOOL_FAILURE: deploy.sh accepts only --env-file and --authorization-evidence' >&2; exit 2 ;;
  esac
done
if [[ -f "$config_file" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$config_file"
  set +a
fi

require_runtime_config
authorization_evidence="${authorization_evidence:-${DEVSHIELD_DEPLOYMENT_AUTHORIZATION:-$repo_root/reports/deployment-authorization-evidence.json}}"
state_file="${DEVSHIELD_DEPLOYMENT_STATE_FILE:-/var/lib/devshield/deployment/${CONTAINER_NAME}.json}"
health_timeout="${HEALTHCHECK_TIMEOUT:-5}"
health_retries="${HEALTHCHECK_RETRIES:-10}"
restart_policy="${RESTART_POLICY:-unless-stopped}"
deployment_id="${DEPLOYMENT_ID:-deploy-$(date -u +%Y%m%dT%H%M%SZ)-$$}"
artifact="$(artifact_reference)"

[[ -s "$authorization_evidence" ]] || deny_deployment "authorization evidence is missing: $authorization_evidence"
command -v "$docker_bin" >/dev/null 2>&1 || fail_deployment 'Docker executable is unavailable'
"$docker_bin" info >/dev/null 2>&1 || fail_deployment 'Docker daemon is unavailable'
[[ -z "${CONTAINER_ENV_FILE:-}" || -s "$CONTAINER_ENV_FILE" ]] || fail_deployment 'CONTAINER_ENV_FILE does not exist'
"$repo_root/security/deployment/validate-evidence.sh" --evidence "$authorization_evidence" --artifact "$artifact" --environment "$DEPLOYMENT_ENVIRONMENT" >/dev/null || deny_deployment 'DevShield authorization is invalid for this artifact'

"$docker_bin" pull "$artifact" >/dev/null || fail_deployment 'unable to pull the exact Harbor digest'
actual="$(actual_digest "$artifact" || true)"
valid_digest "$actual" || fail_deployment 'Docker did not expose a valid local digest'
[[ "$actual" == "$EXPECTED_DIGEST" ]] || deny_deployment "local digest ${actual} differs from EXPECTED_DIGEST ${EXPECTED_DIGEST}"
if [[ "${REQUIRE_NON_ROOT:-1}" == 1 ]]; then
  image_user="$("$docker_bin" image inspect --format '{{.Config.User}}' "$artifact" 2>/dev/null || true)"
  [[ -n "$image_user" && "$image_user" != root && "$image_user" != 0 ]] || deny_deployment 'image does not declare a non-root runtime user'
fi

previous_reference=""
previous_digest=""
previous_auth=""
previous_container="${CONTAINER_NAME}.previous"
if [[ -s "$state_file" ]]; then previous_auth="$(state_value "$state_file" current_authorization_evidence)"; fi
if "$docker_bin" inspect "$CONTAINER_NAME" >/dev/null 2>&1; then
  previous_reference="$("$docker_bin" inspect --format '{{.Config.Image}}' "$CONTAINER_NAME" 2>/dev/null || true)"
  [[ -n "$previous_reference" ]] || fail_deployment 'current container has no inspectable image reference'
  validate_artifact_reference "$previous_reference" || deny_deployment 'current container is not bound to an immutable digest'
  previous_digest="${previous_reference##*@}"
  "$docker_bin" stop "$CONTAINER_NAME" >/dev/null || fail_deployment 'unable to stop current container safely'
  "$docker_bin" rm -f "$previous_container" >/dev/null 2>&1 || true
  "$docker_bin" rename "$CONTAINER_NAME" "$previous_container" >/dev/null || fail_deployment 'unable to preserve current container for rollback'
fi

mkdir -p "$(dirname "$state_file")" || fail_deployment 'unable to create deployment state directory'
write_state "$state_file" deploying "$deployment_id" "$DEPLOYMENT_ENVIRONMENT" "$CONTAINER_NAME" "$artifact" "$EXPECTED_DIGEST" "$authorization_evidence" "$previous_reference" "$previous_digest" "$previous_auth" "$HOST_PORT" "$CONTAINER_PORT" "$HEALTHCHECK_URL" "$health_timeout" "$health_retries" "${RUNTIME_NETWORK:-}" "$restart_policy" "${CONTAINER_ENV_FILE:-}"

container_run_args
"$docker_bin" "${run_args[@]}" "$artifact" >/dev/null || {
  echo 'DEPLOYMENT_FAILURE: new container failed to start' >&2
  if [[ "${ROLLBACK_ENABLED:-1}" == 1 && -n "$previous_reference" ]]; then "$deploy_root/rollback.sh" --state-file "$state_file" || true; fi
  exit 2
}

if ! DEVSHIELD_DOCKER_BIN="$docker_bin" CONTAINER_NAME="$CONTAINER_NAME" HEALTHCHECK_URL="$HEALTHCHECK_URL" HEALTHCHECK_TIMEOUT="$health_timeout" HEALTHCHECK_RETRIES="$health_retries" "$deploy_root/healthcheck.sh"; then
  echo 'DEPLOYMENT_FAILURE: healthcheck failed' >&2
  if [[ "${ROLLBACK_ENABLED:-1}" == 1 && -n "$previous_reference" ]]; then "$deploy_root/rollback.sh" --state-file "$state_file" || true; else echo 'ROLLBACK_FAILED: no previous immutable version is available' >&2; fi
  exit 3
fi

if "$docker_bin" inspect "$previous_container" >/dev/null 2>&1; then "$docker_bin" rm -f "$previous_container" >/dev/null || fail_deployment 'healthy deployment could not clean the previous container'; fi
write_state "$state_file" success "$deployment_id" "$DEPLOYMENT_ENVIRONMENT" "$CONTAINER_NAME" "$artifact" "$EXPECTED_DIGEST" "$authorization_evidence" "$previous_reference" "$previous_digest" "$previous_auth" "$HOST_PORT" "$CONTAINER_PORT" "$HEALTHCHECK_URL" "$health_timeout" "$health_retries" "${RUNTIME_NETWORK:-}" "$restart_policy" "${CONTAINER_ENV_FILE:-}"
echo "DEPLOYMENT_SUCCESS: ${artifact}"
