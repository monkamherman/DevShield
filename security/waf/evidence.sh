#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

audit=""
output=""
environment="${WAF_ENVIRONMENT:-production}"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --audit-log) audit="$2"; shift 2 ;;
    --output) output="$2"; shift 2 ;;
    --environment) environment="$2"; shift 2 ;;
    *) echo "WAF_CONFIG_FAILURE: unknown evidence option $1" >&2; exit 4 ;;
  esac
done
[[ -s "$audit" && -n "$output" ]] || { echo 'WAF_CONFIG_FAILURE: --audit-log and --output are required' >&2; exit 4; }
case "$environment" in development|staging|production) ;; *) echo 'WAF_CONFIG_FAILURE: invalid WAF_ENVIRONMENT' >&2; exit 4 ;; esac
export WAF_AUDIT="$audit" WAF_OUTPUT="$output" WAF_ENVIRONMENT_VALUE="$environment" WAF_CONFIG_HASH="$(config_hash)" WAF_MODE_VALUE="${WAF_MODE:-blocking}" WAF_PRODUCT_VALUE="$WAF_PRODUCT_VERSION" WAF_CRS_VALUE="$WAF_CRS_VERSION"
node <<'NODE'
const fs=require('fs'), path=require('path');
const events=[];
for (const line of fs.readFileSync(process.env.WAF_AUDIT,'utf8').split(/\r?\n/).filter(Boolean)) {
  let item; try { item=JSON.parse(line); } catch (_) { continue; }
  const text=JSON.stringify(item).toLowerCase();
  const blocked=text.includes('intervention') || text.includes('disruptive') || item.status===403 || item.action==='BLOCK';
  const rule=(text.match(/(?:ruleid|rule_id|id)[^0-9]*([0-9]{3,6})/)||[])[1] || null;
  const method=item.method || item.request?.method || item.transaction?.request?.method || null;
  const pathValue=item.path || item.uri || item.request?.uri || item.transaction?.request?.uri || null;
  events.push({timestamp:item.timestamp || item.time || new Date().toISOString(), action:blocked?'BLOCK':'ALLOW', rule_id:rule, method, path:pathValue ? String(pathValue).split('?')[0] : null, status:item.status || null, message:item.message || item.msg || null});
}
const blocked=events.filter(e=>e.action==='BLOCK');
const evidence={schema_version:'1.0',component:'waf',product:'coraza',product_version:process.env.WAF_PRODUCT_VALUE,crs_version:process.env.WAF_CRS_VALUE,environment:process.env.WAF_ENVIRONMENT_VALUE,mode:process.env.WAF_MODE_VALUE,config_hash:process.env.WAF_CONFIG_HASH,events,summary:{total:events.length,blocked:blocked.length,allowed:events.length-blocked.length},generated_at:new Date().toISOString()};
fs.mkdirSync(path.dirname(process.env.WAF_OUTPUT),{recursive:true});
fs.writeFileSync(process.env.WAF_OUTPUT,JSON.stringify(evidence,null,2)+'\n');
console.log(`WAF evidence: ${blocked.length} blocked event(s), ${events.length-blocked.length} allowed event(s)`);
NODE
