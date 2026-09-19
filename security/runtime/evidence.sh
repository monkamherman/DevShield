#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

input=""
output=""
environment="${DEVSHIELD_RUNTIME_ENVIRONMENT:-development}"
artifact_digest="${DEVSHIELD_RUNTIME_ARTIFACT_DIGEST:-}"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --input) input="$2"; shift 2 ;;
    --output) output="$2"; shift 2 ;;
    --environment) environment="$2"; shift 2 ;;
    --artifact-digest) artifact_digest="$2"; shift 2 ;;
    *) echo "RUNTIME_SECURITY_TOOL_FAILURE: unknown evidence option $1" >&2; exit 2 ;;
  esac
done
[[ -f "$input" && -n "$output" ]] || { echo 'RUNTIME_SECURITY_TOOL_FAILURE: --input and --output are required' >&2; exit 2; }
case "$environment" in development|staging|production) ;; *) echo 'RUNTIME_SECURITY_TOOL_FAILURE: invalid runtime environment' >&2; exit 2 ;; esac
export RUNTIME_INPUT="$input" RUNTIME_OUTPUT="$output" RUNTIME_ENV="$environment" RUNTIME_ARTIFACT_DIGEST="$artifact_digest" RUNTIME_RULES_VERSION="$DEVSHIELD_RULES_VERSION" RUNTIME_FALCO_VERSION="$FALCO_VERSION" RUNTIME_RULES_HASH="$(rules_hash)"
node <<'NODE'
const fs=require('fs'), path=require('path');
const events=[];
for (const line of fs.readFileSync(process.env.RUNTIME_INPUT,'utf8').split(/\r?\n/).filter(Boolean)) {
  let item; try { item=JSON.parse(line); } catch (_) { continue; }
  const fields=item.output_fields || {};
  const priority=String(item.priority || fields.priority || 'WARNING').toUpperCase();
  const severity=['CRITICAL','ERROR','WARNING','NOTICE'].includes(priority) ? priority : 'WARNING';
  const container={id:fields['container.id'] || item.container_id || null,name:fields['container.name'] || item.container_name || null,image:fields['container.image.repository'] || item.image || null,digest:fields['container.image.digest'] || item.container_image_digest || process.env.RUNTIME_ARTIFACT_DIGEST || null};
  const proc={name:fields['proc.name'] || item.process || null,command:fields['proc.cmdline'] || item.command || null,user:fields['user.name'] || item.user || null};
  events.push({schema_version:'1.0',component:'runtime-security',engine:'falco',engine_version:process.env.RUNTIME_FALCO_VERSION,rules_version:process.env.RUNTIME_RULES_VERSION,environment:process.env.RUNTIME_ENV,severity,rule:item.rule || null,action:'DETECTED',container,process:proc,timestamp:item.time || item.timestamp || new Date().toISOString(),message:item.output || null});
}
const counts=Object.fromEntries(['NOTICE','WARNING','ERROR','CRITICAL'].map(k=>[k,events.filter(e=>e.severity===k).length]));
const evidence={schema_version:'1.0',component:'runtime-security',engine:'falco',engine_version:process.env.RUNTIME_FALCO_VERSION,rules_version:process.env.RUNTIME_RULES_VERSION,rules_hash:process.env.RUNTIME_RULES_HASH,environment:process.env.RUNTIME_ENV,artifact_digest:process.env.RUNTIME_ARTIFACT_DIGEST || null,status:'DETECTED_EVENTS',events,summary:{total:events.length,severity:counts},generated_at:new Date().toISOString()};
fs.mkdirSync(path.dirname(process.env.RUNTIME_OUTPUT),{recursive:true});
fs.writeFileSync(process.env.RUNTIME_OUTPUT,JSON.stringify(evidence,null,2)+'\n');
console.log(`Runtime evidence: ${events.length} event(s)`);
NODE
