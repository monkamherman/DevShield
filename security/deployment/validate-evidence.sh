#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

evidence=""
artifact=""
environment=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --evidence) evidence="$2"; shift 2 ;;
    --artifact) artifact="$2"; shift 2 ;;
    --environment) environment="$2"; shift 2 ;;
    *) echo "TOOL_FAILURE: unknown evidence option $1" >&2; exit 2 ;;
  esac
done
[[ -s "$evidence" && -n "$artifact" && -n "$environment" ]] || { echo 'TOOL_FAILURE: --evidence, --artifact and --environment are required' >&2; exit 2; }
validate_environment "$environment"
validate_artifact_reference "$artifact"
node - "$evidence" "$artifact" "$environment" <<'NODE'
const fs = require('fs');
const [file, artifact, environment] = process.argv.slice(2);
const evidence = JSON.parse(fs.readFileSync(file, 'utf8'));
const ok = evidence.environment === environment &&
  evidence.artifact?.reference === artifact &&
  evidence.artifact?.digest === artifact.slice(artifact.indexOf('@') + 1) &&
  evidence.policy?.decision === 'ALLOW' &&
  evidence.authorization?.authorized === true &&
  evidence.authorization?.status === 'AUTHORIZED';
if (!ok) {
  console.error('VERIFICATION_FAILURE: deployment authorization evidence is invalid or not bound to the requested artifact');
  process.exit(1);
}
console.log(`Deployment authorization evidence is valid for ${artifact}`);
NODE
