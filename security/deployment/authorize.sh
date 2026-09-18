#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

artifact=""
environment=""
policy_input=""
output="${DEVSHIELD_DEPLOYMENT_AUTHORIZATION:-$repo_root/reports/deployment-authorization-evidence.json}"
policy_evidence=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --artifact) artifact="$2"; shift 2 ;;
    --environment) environment="$2"; shift 2 ;;
    --policy-input) policy_input="$2"; shift 2 ;;
    --output) output="$2"; shift 2 ;;
    *) echo "TOOL_FAILURE: unknown authorization option $1" >&2; exit 2 ;;
  esac
done
[[ -n "$artifact" && -n "$environment" && -n "$policy_input" ]] || { echo 'TOOL_FAILURE: --artifact, --environment and --policy-input are required' >&2; exit 2; }
validate_environment "$environment"
validate_artifact_reference "$artifact"
[[ -s "$policy_input" ]] || { echo "TOOL_FAILURE: policy input not found at ${policy_input}" >&2; exit 2; }
policy_input="$(realpath "$policy_input")"
mkdir -p "$(dirname "$output")"
policy_evidence="$(mktemp "${TMPDIR:-/tmp}/devshield-policy-evidence.XXXXXX.json")"
cleanup() { rm -f "$policy_evidence"; }
trap cleanup EXIT

input_reference="$(json_field "$policy_input" artifact reference 2>/dev/null || true)"
input_digest="$(json_field "$policy_input" artifact digest 2>/dev/null || true)"
requested_digest="${artifact##*@}"
if [[ "$input_reference" != "$artifact" || "$input_digest" != "$requested_digest" ]]; then
  echo 'VERIFICATION_FAILURE: policy input artifact does not match the requested deployment artifact' >&2
  node - "$output" "$artifact" "$environment" "$input_reference" <<'NODE'
const fs=require('fs'), path=require('path');
const [file, artifact, environment, inputReference] = process.argv.slice(2);
fs.mkdirSync(path.dirname(file), {recursive:true});
fs.writeFileSync(file, JSON.stringify({schema_version:'1.0', artifact:{reference:artifact, digest:artifact.slice(artifact.indexOf('@')+1)}, environment, policy:{decision:'DENY'}, authorization:{authorized:false,status:'BLOCKED'}, reasons:['policy input artifact does not match requested deployment artifact', `input reference: ${inputReference}`], timestamp:new Date().toISOString()}, null, 2)+'\n');
NODE
  exit 1
fi
input_environment="$(json_field "$policy_input" environment 2>/dev/null || true)"
[[ "$input_environment" == "$environment" ]] || { echo "VERIFICATION_FAILURE: policy input environment ${input_environment} does not match ${environment}" >&2; exit 1; }

set +e
"$repo_root/security/policies/opa/evaluate.sh" --input "$policy_input" --output "$policy_evidence" --environment "$environment"
policy_exit=$?
set -e

node - "$policy_evidence" "$output" "$artifact" "$environment" "$policy_exit" <<'NODE'
const fs=require('fs'), path=require('path');
const [policyFile, output, artifact, environment, exitText] = process.argv.slice(2);
const policyExit=Number(exitText);
let policy={};
try { policy=JSON.parse(fs.readFileSync(policyFile,'utf8')); } catch {}
const decision=policy.decision === 'ALLOW' && policy.artifact?.reference === artifact && policy.artifact?.digest === artifact.slice(artifact.indexOf('@')+1) ? 'ALLOW' : 'DENY';
const authorized=policyExit === 0 && decision === 'ALLOW';
const reasons=authorized ? [] : (policy.reasons || [policyExit === 2 ? 'policy evaluation failed' : 'policy denied deployment']);
const evidence={schema_version:'1.0', artifact:{repository:artifact.slice(0,artifact.indexOf('@')), reference:artifact, digest:artifact.slice(artifact.indexOf('@')+1)}, environment, policy:{decision, version:policy.policy_version || 'unknown', policy_hash:policy.policy_hash || null, input_hash:policy.input_hash || null}, authorization:{authorized, status:authorized?'AUTHORIZED':'BLOCKED'}, source:{repository:policy.repository || 'unknown', commit:policy.source_commit || 'unknown'}, reasons, timestamp:new Date().toISOString()};
fs.mkdirSync(path.dirname(output), {recursive:true});
fs.writeFileSync(output, JSON.stringify(evidence,null,2)+'\n');
console.log(authorized ? `AUTHORIZED: ${artifact}` : `BLOCKED: ${artifact}`);
if (!authorized) process.exit(policyExit === 2 ? 2 : 1);
NODE
