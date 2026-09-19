#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

state_file="${DEVSHIELD_DEPLOYMENT_STATE_FILE:-}"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --state-file) state_file="$2"; shift 2 ;;
    *) echo 'TOOL_FAILURE: rollback.sh accepts only --state-file' >&2; exit 2 ;;
  esac
done
[[ -s "$state_file" ]] || fail_rollback 'deployment state is missing'
state_value() { node -e 'const x=require(process.argv[1]); const v=x[process.argv[2]]; if(v!==undefined&&v!==null) process.stdout.write(String(v));' "$state_file" "$1" 2>/dev/null || true; }
CONTAINER_NAME="$(state_value container_name)"
DEPLOYMENT_ENVIRONMENT="$(state_value environment)"
CONTAINER_PORT="$(state_value container_port)"
HOST_PORT="$(state_value host_port)"
HEALTHCHECK_URL="$(state_value healthcheck_url)"
HEALTHCHECK_TIMEOUT="$(state_value healthcheck_timeout)"
HEALTHCHECK_RETRIES="$(state_value healthcheck_retries)"
RUNTIME_NETWORK="$(state_value runtime_network)"
RESTART_POLICY="$(state_value restart_policy)"
CONTAINER_ENV_FILE="$(state_value container_env_file)"
previous_reference="$(state_value previous_reference)"
current_reference="$(state_value current_reference)"
previous_auth="$(state_value previous_authorization_evidence)"
[[ -n "$CONTAINER_NAME" && -n "$previous_reference" ]] || fail_rollback 'no previous immutable version is recorded'
validate_environment "$DEPLOYMENT_ENVIRONMENT" || fail_rollback 'invalid deployment environment'
validate_artifact_reference "$previous_reference" || fail_rollback 'previous reference is not immutable'
if [[ -n "$previous_auth" && -s "$previous_auth" ]]; then
  "$repo_root/security/deployment/validate-evidence.sh" --evidence "$previous_auth" --artifact "$previous_reference" --environment "$DEPLOYMENT_ENVIRONMENT" >/dev/null || fail_rollback 'previous authorization evidence is invalid'
fi
command -v "$docker_bin" >/dev/null 2>&1 || fail_rollback 'Docker executable is unavailable'
"$docker_bin" info >/dev/null 2>&1 || fail_rollback 'Docker daemon is unavailable'
"$docker_bin" pull "$previous_reference" >/dev/null || fail_rollback 'unable to pull previous digest'
actual="$(actual_digest "$previous_reference" || true)"
valid_digest "$actual" || fail_rollback 'previous image has no valid local digest'
previous_digest="${previous_reference##*@}"
[[ "$actual" == "$previous_digest" ]] || fail_rollback 'previous image digest mismatch'

"$docker_bin" rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
container_run_args
"$docker_bin" "${run_args[@]}" "$previous_reference" >/dev/null || fail_rollback 'previous container failed to start'
if ! DEVSHIELD_DOCKER_BIN="$docker_bin" CONTAINER_NAME="$CONTAINER_NAME" HEALTHCHECK_URL="$HEALTHCHECK_URL" HEALTHCHECK_TIMEOUT="${HEALTHCHECK_TIMEOUT:-5}" HEALTHCHECK_RETRIES="${HEALTHCHECK_RETRIES:-10}" "$deploy_root/healthcheck.sh"; then
  node - "$state_file" <<'NODE'
const fs=require('fs'); const file=process.argv[2]; const x=JSON.parse(fs.readFileSync(file,'utf8')); x.status='rollback_failed'; x.updated_at=new Date().toISOString(); fs.writeFileSync(file,JSON.stringify(x,null,2)+'\n',{mode:0o600});
NODE
  fail_rollback 'previous version did not pass healthcheck'
fi
node - "$state_file" "$previous_reference" "$current_reference" <<'NODE'
const fs=require('fs'); const [file,restored,failed]=process.argv.slice(2); const x=JSON.parse(fs.readFileSync(file,'utf8')); x.status='rollback_success'; x.previous_reference=failed||null; x.previous_digest=failed?failed.slice(failed.indexOf('@')+1):null; x.current_reference=restored; x.current_digest=restored.slice(restored.indexOf('@')+1); x.updated_at=new Date().toISOString(); fs.writeFileSync(file,JSON.stringify(x,null,2)+'\n',{mode:0o600});
NODE
echo "ROLLBACK_SUCCESS: ${previous_reference}"

