#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"
observability_node

event_file=""
event_type=""
component=""
severity=""
environment=""
status=""
reason=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --event-json) event_file="$2"; shift 2 ;;
    --event-type) event_type="$2"; shift 2 ;;
    --component) component="$2"; shift 2 ;;
    --severity) severity="$2"; shift 2 ;;
    --environment) environment="$2"; shift 2 ;;
    --status) status="$2"; shift 2 ;;
    --reason) reason="$2"; shift 2 ;;
    *) echo "EVENT_INVALID: unknown logger option $1" >&2; exit 4 ;;
  esac
done
if [[ -z "$event_file" ]]; then
  event_file="$(mktemp)"
  trap 'rm -f "$event_file"' EXIT
  export DEVSHIELD_EVENT_TYPE="$event_type" DEVSHIELD_COMPONENT="$component" DEVSHIELD_SEVERITY="${severity:-INFO}" DEVSHIELD_ENVIRONMENT="${environment:-ci}" DEVSHIELD_STATUS="${status:-UNKNOWN}" DEVSHIELD_REASON="$reason"
  node >"$event_file" <<'NODE'
const event = {event_type:process.env.DEVSHIELD_EVENT_TYPE,component:process.env.DEVSHIELD_COMPONENT,severity:process.env.DEVSHIELD_SEVERITY,environment:process.env.DEVSHIELD_ENVIRONMENT,status:process.env.DEVSHIELD_STATUS,reason:process.env.DEVSHIELD_REASON||null};
process.stdout.write(JSON.stringify(event));
NODE
fi
[[ -s "$event_file" ]] || { echo 'EVENT_INVALID: --event-json file is empty' >&2; exit 4; }
export DEVSHIELD_EVENT_INPUT="$event_file" DEVSHIELD_OUTPUT_FILE="$OBSERVABILITY_LOG_FILE" DEVSHIELD_MAX_BYTES="$OBSERVABILITY_MAX_BYTES"
node <<'NODE'
const fs=require('fs'), crypto=require('crypto'), path=require('path');
const allowedTypes=new Set(['pipeline.started','pipeline.completed','pipeline.failed','security.scan.started','security.scan.completed','security.scan.failed','security.sast.finding','security.sast.completed','security.secret.detected','security.secret.scan.completed','security.sca.finding','security.sca.completed','security.container.finding','security.container.scan.completed','security.sbom.generated','security.sbom.validation.failed','artifact.pushed','artifact.digest.resolved','artifact.signed','artifact.verification.completed','artifact.verification.failed','security.policy.allow','security.policy.deny','security.policy.evaluation.failed','deployment.authorization.allowed','deployment.authorization.denied','deployment.started','deployment.completed','deployment.failed','dast.scan.started','dast.finding.detected','dast.scan.completed','dast.scan.failed','waf.request.detected','waf.request.blocked','waf.configuration.failed','waf.health.failed','runtime.alert','runtime.security.failure','runtime.monitoring.unavailable']);
const severitySet=new Set(['DEBUG','INFO','WARNING','ERROR','CRITICAL']);
const statusSet=new Set(['PASS','FAIL','WARN','WARNING','UNKNOWN','ALLOW','DENY','STARTED','COMPLETED','DETECTED','BLOCKED','AUTHORIZED','UNAVAILABLE','ERROR']);
const secretKey=/(password|passwd|token|secret|api[_-]?key|private[_-]?key|authorization|cookie|credential)/i;
const sensitiveText=/((?:bearer\s+|token|password|passwd|secret|api[_-]?key)\s*[=:]?\s*)([^\s,'";]+)/gi;
function redact(value,key=''){if(secretKey.test(key))return '[REDACTED]';if(typeof value==='string')return value.replace(sensitiveText,'$1[REDACTED]');if(Array.isArray(value))return value.map(v=>redact(v,key));if(value&&typeof value==='object')return Object.fromEntries(Object.entries(value).map(([k,v])=>[k,redact(v,k)]));return value;}
let event; try{event=redact(JSON.parse(fs.readFileSync(process.env.DEVSHIELD_EVENT_INPUT,'utf8')));}catch(e){console.error(`EVENT_INVALID: invalid JSON: ${e.message}`);process.exit(4);}
event.schema_version='1.0'; event.event_id ||= crypto.randomUUID(); event.timestamp ||= new Date().toISOString(); event.severity=String(event.severity||'INFO').toUpperCase(); event.environment ||= 'ci'; event.status=String(event.status||'UNKNOWN').toUpperCase();
if(!event.event_type||!allowedTypes.has(event.event_type)){console.error('EVENT_INVALID: event_type is missing or unsupported');process.exit(4);} if(!event.component||typeof event.component!=='string'){console.error('EVENT_INVALID: component is required');process.exit(4);} if(!event.environment||typeof event.environment!=='string'){console.error('EVENT_INVALID: environment is required');process.exit(4);} if(!severitySet.has(event.severity)){console.error('EVENT_INVALID: invalid severity');process.exit(4);} if(!statusSet.has(event.status)){console.error('EVENT_INVALID: invalid status');process.exit(4);} if(Number.isNaN(Date.parse(event.timestamp))){console.error('EVENT_INVALID: invalid timestamp');process.exit(4);}
const digest=event.artifact?.digest||event.artifact_digest; if(digest!==undefined&&digest!==null&&!/^sha256:[0-9a-f]{64}$/.test(String(digest))){console.error('EVENT_INVALID: malformed artifact digest');process.exit(4);} if(event.artifact?.digest&&event.artifact_digest&&event.artifact.digest!==event.artifact_digest){console.error('EVENT_INVALID: artifact digest fields disagree');process.exit(4);}
try{const output=process.env.DEVSHIELD_OUTPUT_FILE;const line=JSON.stringify(event)+'\n';fs.mkdirSync(path.dirname(output),{recursive:true});const max=Number(process.env.DEVSHIELD_MAX_BYTES||10485760);if(fs.existsSync(output)&&fs.statSync(output).size+Buffer.byteLength(line)>max){fs.renameSync(output,`${output}.1`);}fs.appendFileSync(output,line,{encoding:'utf8'});}catch(e){console.error(`LOCAL_LOGGING_FAILURE: ${e.message}`);process.exit(5);}
console.log(`EVENT_VALID: ${event.event_type}`);
NODE
