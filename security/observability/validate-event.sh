#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"
observability_node

input="${1:-}"
[[ -n "$input" && -f "$input" ]] || { echo 'EVENT_INVALID: event JSON file is required' >&2; exit 4; }
export DEVSHIELD_EVENT_INPUT="$input"
node <<'NODE'
const fs = require('fs');
const allowedTypes = new Set([
  'pipeline.started','pipeline.completed','pipeline.failed','security.scan.started','security.scan.completed','security.scan.failed',
  'security.sast.finding','security.sast.completed','security.secret.detected','security.secret.scan.completed','security.sca.finding',
  'security.sca.completed','security.container.finding','security.container.scan.completed','security.sbom.generated','security.sbom.validation.failed',
  'artifact.pushed','artifact.digest.resolved','artifact.signed','artifact.verification.completed','artifact.verification.failed',
  'security.policy.allow','security.policy.deny','security.policy.evaluation.failed','deployment.authorization.allowed',
  'deployment.authorization.denied','deployment.started','deployment.completed','deployment.failed','dast.scan.started','dast.finding.detected',
  'dast.scan.completed','dast.scan.failed','waf.request.detected','waf.request.blocked','waf.configuration.failed','waf.health.failed',
  'runtime.alert','runtime.security.failure','runtime.monitoring.unavailable'
]);
const severities = new Set(['DEBUG','INFO','WARNING','ERROR','CRITICAL']);
const statuses = new Set(['PASS','FAIL','WARN','WARNING','UNKNOWN','ALLOW','DENY','STARTED','COMPLETED','DETECTED','BLOCKED','AUTHORIZED','UNAVAILABLE','ERROR']);
let value;
try { value = JSON.parse(fs.readFileSync(process.env.DEVSHIELD_EVENT_INPUT, 'utf8')); }
catch (e) { console.error(`EVENT_INVALID: invalid JSON: ${e.message}`); process.exit(4); }
const errors=[];
for (const key of ['schema_version','event_id','timestamp','event_type','severity','component','environment','status']) {
  if (typeof value[key] !== 'string' || value[key].length === 0) errors.push(`missing or invalid ${key}`);
}
if (value.schema_version !== '1.0') errors.push('unsupported schema_version');
if (value.event_type && !allowedTypes.has(value.event_type)) errors.push(`unknown event_type ${value.event_type}`);
if (value.severity && !severities.has(value.severity)) errors.push(`invalid severity ${value.severity}`);
if (value.status && !statuses.has(value.status)) errors.push(`invalid status ${value.status}`);
if (value.timestamp && Number.isNaN(Date.parse(value.timestamp))) errors.push('invalid timestamp');
const digest = value.artifact?.digest || value.artifact_digest;
if (digest !== undefined && digest !== null && !/^sha256:[0-9a-f]{64}$/.test(String(digest))) errors.push('malformed artifact digest');
if (value.artifact?.digest && value.artifact_digest && value.artifact.digest !== value.artifact_digest) errors.push('artifact digest fields disagree');
if (errors.length) { console.error(`EVENT_INVALID: ${errors.join('; ')}`); process.exit(4); }
console.log('EVENT_VALID');
NODE

