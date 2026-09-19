#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

input="${DEVSHIELD_POLICY_INPUT:-$repo_root/reports/policy-input.json}"
output="${DEVSHIELD_POLICY_EVIDENCE:-$repo_root/reports/policy-decision-evidence.json}"
environment="${DEVSHIELD_POLICY_ENVIRONMENT:-}"
policy_dir="$repo_root/security/policies/opa"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --input) input="$2"; shift 2 ;;
    --output) output="$2"; shift 2 ;;
    --environment) environment="$2"; shift 2 ;;
    *) echo "TOOL_FAILURE: unknown policy option $1" >&2; exit 2 ;;
  esac
done
[[ -s "$input" ]] || { echo "TOOL_FAILURE: policy input not found at ${input}" >&2; exit 2; }
require_opa
input="$(realpath "$input")"
if [[ -n "$environment" ]]; then
  input_environment="$(node -e 'const x=require(process.argv[1]); process.stdout.write(x.environment||"")' "$input")"
  [[ "$input_environment" == "$environment" ]] || { echo "TOOL_FAILURE: requested environment ${environment} does not match policy input ${input_environment}" >&2; exit 2; }
fi
raw="$(mktemp)"
trap 'rm -f "$raw"' EXIT
set +e
"$opa_bin" eval --format json --data "$policy_dir" --input "$input" 'data.devshield.policy.decision' >"$raw"
opa_exit=$?
set -e
if [[ "$opa_exit" -ne 0 ]]; then
  echo 'TOOL_FAILURE: OPA evaluation failed' >&2
  exit 2
fi
export DEVSHIELD_POLICY_RAW="$raw" DEVSHIELD_POLICY_INPUT_FILE="$input" DEVSHIELD_POLICY_OUTPUT="$output" DEVSHIELD_POLICY_ENVIRONMENT="$environment" DEVSHIELD_POLICY_HASH="$(policy_files_hash "$policy_dir")" DEVSHIELD_OPA_VERSION="$OPA_VERSION" DEVSHIELD_COMMIT="${GITHUB_SHA:-$(git rev-parse HEAD 2>/dev/null || echo unknown)}"
node <<'NODE'
const fs = require('fs');
const crypto = require('crypto');
const path = require('path');
const result = JSON.parse(fs.readFileSync(process.env.DEVSHIELD_POLICY_RAW, 'utf8'));
const decision = result.result?.[0]?.expressions?.[0]?.value;
if (!decision || !['ALLOW', 'DENY'].includes(decision.decision)) { console.error('TOOL_FAILURE: OPA returned no valid decision'); process.exit(2); }
const inputBytes = fs.readFileSync(process.env.DEVSHIELD_POLICY_INPUT_FILE);
const evidence = {
  schema_version: '1.0',
  policy_version: decision.policy_version || 'unknown',
  opa_version: process.env.DEVSHIELD_OPA_VERSION,
  policy_hash: process.env.DEVSHIELD_POLICY_HASH,
  input_hash: crypto.createHash('sha256').update(inputBytes).digest('hex'),
  repository: process.env.GITHUB_REPOSITORY || 'local',
  source_commit: process.env.DEVSHIELD_COMMIT,
  environment: decision.environment || process.env.DEVSHIELD_POLICY_ENVIRONMENT || null,
  artifact: decision.artifact || {},
  decision: decision.decision,
  reasons: decision.reasons || [],
  evaluated_at: new Date().toISOString(),
};
fs.mkdirSync(path.dirname(process.env.DEVSHIELD_POLICY_OUTPUT), {recursive: true});
fs.writeFileSync(process.env.DEVSHIELD_POLICY_OUTPUT, `${JSON.stringify(evidence, null, 2)}\n`);
console.log(`Policy decision: ${evidence.decision}`);
if (evidence.decision === 'DENY') process.exit(1);
NODE
