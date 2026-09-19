#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

json_report=""
html_report=""
output=""
target=""
environment=""
artifact="${DEVSHIELD_DAST_ARTIFACT:-}"
scan_started="${DEVSHIELD_DAST_STARTED_AT:-}"
scanner_exit="${DEVSHIELD_DAST_SCANNER_EXIT:-0}"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --json) json_report="$2"; shift 2 ;;
    --html) html_report="$2"; shift 2 ;;
    --output) output="$2"; shift 2 ;;
    --target) target="$2"; shift 2 ;;
    --environment) environment="$2"; shift 2 ;;
    --artifact) artifact="$2"; shift 2 ;;
    --started-at) scan_started="$2"; shift 2 ;;
    --scanner-exit) scanner_exit="$2"; shift 2 ;;
    *) echo "CONFIGURATION_FAILURE: unknown result option $1" >&2; exit 4 ;;
  esac
done
[[ -n "$json_report" && -n "$html_report" && -n "$output" && -n "$target" && -n "$environment" ]] || { echo 'CONFIGURATION_FAILURE: report, target, environment and output options are required' >&2; exit 4; }
[[ -s "$json_report" && -s "$html_report" ]] || { echo 'TOOL_FAILURE: expected ZAP reports are missing' >&2; exit 2; }

export DAST_JSON="$json_report" DAST_HTML="$html_report" DAST_OUTPUT="$output" DAST_TARGET="$target" DAST_ENVIRONMENT="$environment" DAST_ARTIFACT="$artifact" DAST_STARTED="$scan_started" DAST_SCANNER_EXIT="$scanner_exit" DAST_ZAP_VERSION="${DEVSHIELD_ZAP_VERSION:-2.15.0}"
node <<'NODE'
const fs=require('fs'), crypto=require('crypto'), path=require('path');
let report;
try { report=JSON.parse(fs.readFileSync(process.env.DAST_JSON,'utf8')); }
catch (error) { console.error(`TOOL_FAILURE: invalid ZAP JSON report: ${error.message}`); process.exit(2); }
const sites=report.site || report.sites || [];
const alerts=[];
for (const site of (Array.isArray(sites) ? sites : [sites])) for (const alert of (site.alerts || [])) alerts.push(alert);
const severity=(alert) => {
  const value=String(alert.riskdesc || alert.risk || alert.riskcode || '').toLowerCase();
  if (value.includes('high') || value === '3') return 'high';
  if (value.includes('medium') || value.includes('med') || value === '2') return 'medium';
  if (value.includes('low') || value === '1') return 'low';
  return 'informational';
};
const findings=alerts.map(a=>({name:a.name || a.alert || 'unknown', risk:severity(a), confidence:a.confidence || null, url:a.url || null, description:a.desc || a.description || null}));
const counts=Object.fromEntries(['high','medium','low','informational'].map(k=>[k,findings.filter(f=>f.risk===k).length]));
const result=Number(process.env.DAST_SCANNER_EXIT)!==0 && findings.length===0 ? 'TOOL_FAILURE' : counts.high>0 ? 'SECURITY_FAILURE' : 'PASS';
const finished=new Date().toISOString();
const evidence={schema_version:'1.0',scanner:'owasp-zap',scanner_version:process.env.DAST_ZAP_VERSION,scan_type:'baseline',target:process.env.DAST_TARGET,environment:process.env.DAST_ENVIRONMENT,artifact_reference:process.env.DAST_ARTIFACT || null,status:result,findings:counts,alerts:findings,started_at:process.env.DAST_STARTED || finished,finished_at:finished,reports:{json:process.env.DAST_JSON,html:process.env.DAST_HTML},report_sha256:crypto.createHash('sha256').update(fs.readFileSync(process.env.DAST_JSON)).digest('hex'),policy:{high:'SECURITY_FAILURE',medium:'WARNING',low:'INFORMATIONAL',informational:'INFORMATIONAL'}};
fs.mkdirSync(path.dirname(process.env.DAST_OUTPUT),{recursive:true});
fs.writeFileSync(process.env.DAST_OUTPUT,JSON.stringify(evidence,null,2)+'\n');
console.log(`DAST result: ${result} (high=${counts.high}, medium=${counts.medium}, low=${counts.low}, informational=${counts.informational})`);
if (result==='SECURITY_FAILURE') process.exit(1);
if (result==='TOOL_FAILURE') process.exit(2);
NODE
