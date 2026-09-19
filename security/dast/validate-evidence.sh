#!/usr/bin/env bash
set -euo pipefail

evidence=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --evidence) evidence="$2"; shift 2 ;;
    *) echo "CONFIGURATION_FAILURE: unknown evidence option $1" >&2; exit 4 ;;
  esac
done
[[ -s "$evidence" ]] || { echo 'TOOL_FAILURE: DAST evidence not found' >&2; exit 2; }
node - "$evidence" <<'NODE'
const fs=require('fs'), crypto=require('crypto');
const file=process.argv[2];
let evidence;
try { evidence=JSON.parse(fs.readFileSync(file,'utf8')); } catch (error) { console.error(`TOOL_FAILURE: invalid DAST evidence: ${error.message}`); process.exit(2); }
if (!evidence.reports?.json || !evidence.reports?.html || !fs.existsSync(evidence.reports.json) || !fs.existsSync(evidence.reports.html)) { console.error('TOOL_FAILURE: DAST evidence reports are missing'); process.exit(2); }
const hash=crypto.createHash('sha256').update(fs.readFileSync(evidence.reports.json)).digest('hex');
if (hash !== evidence.report_sha256) { console.error('INVALID_EVIDENCE: DAST JSON report hash does not match evidence'); process.exit(5); }
let report;
try { report=JSON.parse(fs.readFileSync(evidence.reports.json,'utf8')); } catch (error) { console.error(`INVALID_EVIDENCE: invalid DAST JSON report: ${error.message}`); process.exit(5); }
const alerts=(report.site || report.sites || []).flatMap(site=>site.alerts || []);
const risk=a=>{ const v=String(a.riskdesc || a.risk || a.riskcode || '').toLowerCase(); return v.includes('high') || v==='3' ? 'high' : v.includes('medium') || v.includes('med') || v==='2' ? 'medium' : v.includes('low') || v==='1' ? 'low' : 'informational'; };
const counts=Object.fromEntries(['high','medium','low','informational'].map(k=>[k,alerts.filter(a=>risk(a)===k).length]));
if (JSON.stringify(counts) !== JSON.stringify(evidence.findings)) { console.error('INVALID_EVIDENCE: DAST finding counts do not match the report'); process.exit(5); }
const expected=counts.high>0?'SECURITY_FAILURE':'PASS';
if (evidence.status !== expected) { console.error(`INVALID_EVIDENCE: DAST status does not match report (${expected})`); process.exit(5); }
console.log(`DAST evidence is valid: ${evidence.status}`);
NODE
