#!/usr/bin/env bash
set -euo pipefail

deploy_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$deploy_root/.." && pwd)"
docker_bin="${DEVSHIELD_DOCKER_BIN:-docker}"
source "$repo_root/security/deployment/common.sh"

load_runtime_config() {
  local file="${DEVSHIELD_RUNTIME_ENV_FILE:-$deploy_root/runtime.env}"
  if [[ -f "$file" ]]; then
    set -a
    # shellcheck disable=SC1090
    source "$file"
    set +a
  fi
}

valid_digest() { [[ "${1:-}" =~ ^sha256:[0-9a-f]{64}$ ]]; }

fail_deployment() { echo "DEPLOYMENT_FAILURE: $*" >&2; exit 2; }
deny_deployment() { echo "DEPLOYMENT_DENIED: $*" >&2; exit 1; }
fail_rollback() { echo "ROLLBACK_FAILED: $*" >&2; exit 5; }

require_runtime_config() {
  : "${HARBOR_REGISTRY:?DEPLOYMENT_DENIED: HARBOR_REGISTRY is required}"
  : "${HARBOR_PROJECT:?DEPLOYMENT_DENIED: HARBOR_PROJECT is required}"
  : "${HARBOR_REPOSITORY:?DEPLOYMENT_DENIED: HARBOR_REPOSITORY is required}"
  : "${EXPECTED_DIGEST:?DEPLOYMENT_DENIED: EXPECTED_DIGEST is required}"
  : "${CONTAINER_NAME:?DEPLOYMENT_FAILURE: CONTAINER_NAME is required}"
  : "${CONTAINER_PORT:?DEPLOYMENT_FAILURE: CONTAINER_PORT is required}"
  : "${HOST_PORT:?DEPLOYMENT_FAILURE: HOST_PORT is required}"
  : "${HEALTHCHECK_URL:?DEPLOYMENT_FAILURE: HEALTHCHECK_URL is required}"
  : "${DEPLOYMENT_ENVIRONMENT:?DEPLOYMENT_FAILURE: DEPLOYMENT_ENVIRONMENT is required}"
  valid_digest "$EXPECTED_DIGEST" || deny_deployment 'EXPECTED_DIGEST is not a valid sha256 digest'
  [[ "$HARBOR_REPOSITORY" != *:* && "$HARBOR_REPOSITORY" != *@* ]] || deny_deployment 'HARBOR_REPOSITORY must not contain a tag or digest'
  [[ "$HARBOR_REGISTRY" != *//* && "$HARBOR_PROJECT" != *[@:[:space:]]* ]] || deny_deployment 'registry/project is invalid'
  [[ "$CONTAINER_NAME" != *[/:@[:space:]]* ]] || fail_deployment 'CONTAINER_NAME is invalid'
  [[ "$CONTAINER_PORT" =~ ^[1-9][0-9]{0,4}$ && "$CONTAINER_PORT" -le 65535 ]] || fail_deployment 'CONTAINER_PORT is invalid'
  [[ "$HOST_PORT" =~ ^[1-9][0-9]{0,4}$ && "$HOST_PORT" -le 65535 ]] || fail_deployment 'HOST_PORT is invalid'
  [[ "$HEALTHCHECK_URL" =~ ^https?://[^[:space:]@]+$ ]] || fail_deployment 'HEALTHCHECK_URL must not contain credentials'
  validate_environment "$DEPLOYMENT_ENVIRONMENT" || fail_deployment 'DEPLOYMENT_ENVIRONMENT is invalid'
}

artifact_reference() { printf '%s/%s/%s@%s\n' "$HARBOR_REGISTRY" "$HARBOR_PROJECT" "$HARBOR_REPOSITORY" "$EXPECTED_DIGEST"; }

actual_digest() {
  "$docker_bin" image inspect --format '{{index .RepoDigests 0}}' "$1" 2>/dev/null | sed 's/.*@//'
}

state_value() {
  node -e 'const x=require(process.argv[1]); const v=x[process.argv[2]]; if(v!==undefined&&v!==null) process.stdout.write(String(v));' "$1" "$2" 2>/dev/null || true
}

write_state() {
  export DEPLOY_STATE_FILE="$1" DEPLOY_STATUS="$2" DEPLOY_ID="$3" DEPLOY_ENV="$4" DEPLOY_CONTAINER="$5" DEPLOY_CURRENT="$6" DEPLOY_CURRENT_DIGEST="$7" DEPLOY_CURRENT_AUTH="$8" DEPLOY_PREVIOUS="$9" DEPLOY_PREVIOUS_DIGEST="${10}" DEPLOY_PREVIOUS_AUTH="${11}" DEPLOY_HOST_PORT="${12}" DEPLOY_CONTAINER_PORT="${13}" DEPLOY_HEALTH_URL="${14}" DEPLOY_HEALTH_TIMEOUT="${15}" DEPLOY_HEALTH_RETRIES="${16}" DEPLOY_NETWORK="${17}" DEPLOY_RESTART="${18}" DEPLOY_ENV_FILE="${19}"
  node <<'NODE'
const fs=require('fs'),path=require('path');
const state={schema_version:'1.0',status:process.env.DEPLOY_STATUS,deployment_id:process.env.DEPLOY_ID,environment:process.env.DEPLOY_ENV,container_name:process.env.DEPLOY_CONTAINER,current_reference:process.env.DEPLOY_CURRENT,current_digest:process.env.DEPLOY_CURRENT_DIGEST,current_authorization_evidence:process.env.DEPLOY_CURRENT_AUTH||null,previous_reference:process.env.DEPLOY_PREVIOUS||null,previous_digest:process.env.DEPLOY_PREVIOUS_DIGEST||null,previous_authorization_evidence:process.env.DEPLOY_PREVIOUS_AUTH||null,host_port:Number(process.env.DEPLOY_HOST_PORT),container_port:Number(process.env.DEPLOY_CONTAINER_PORT),healthcheck_url:process.env.DEPLOY_HEALTH_URL,healthcheck_timeout:Number(process.env.DEPLOY_HEALTH_TIMEOUT),healthcheck_retries:Number(process.env.DEPLOY_HEALTH_RETRIES),runtime_network:process.env.DEPLOY_NETWORK||null,restart_policy:process.env.DEPLOY_RESTART,container_env_file:process.env.DEPLOY_ENV_FILE||null,updated_at:new Date().toISOString()};
fs.mkdirSync(path.dirname(process.env.DEPLOY_STATE_FILE),{recursive:true});
fs.writeFileSync(process.env.DEPLOY_STATE_FILE,JSON.stringify(state,null,2)+'\n',{mode:0o600});
NODE
}

container_run_args() {
  run_args=(run -d --name "$CONTAINER_NAME" --restart "${RESTART_POLICY:-unless-stopped}" --cap-drop ALL --security-opt no-new-privileges:true --init -p "${HOST_PORT}:${CONTAINER_PORT}")

  if [[ -n "${RUNTIME_NETWORK:-}" ]]; then
    run_args+=(--network "$RUNTIME_NETWORK")
  fi

  if [[ -n "${CONTAINER_ENV_FILE:-}" ]]; then
    run_args+=(--env-file "$CONTAINER_ENV_FILE")
  fi

  return 0
}
