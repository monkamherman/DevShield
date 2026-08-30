#!/usr/bin/env bash
set -euo pipefail
repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
source_path="${1:-.}"
report_dir="${DEVSHIELD_REPORT_DIR:-reports}"
mkdir -p "$repo_root/$report_dir"
report_path="$report_dir/trivy-sca.json"
metadata_path="$repo_root/$report_dir/trivy-sca-metadata.json"
cache_dir="${DEVSHIELD_TRIVY_CACHE:-$repo_root/.trivy-cache}"
mkdir -p "$cache_dir"
cd "$repo_root"
args=(fs --scanners vuln --format json --output "/src/$report_path" --cache-dir /tmp/trivy-cache --skip-dirs .git --skip-dirs node_modules --skip-dirs dist --skip-dirs build --skip-dirs coverage --skip-dirs reports)
case "$source_path" in tests/security/fixtures/*) ;; *) args+=(--skip-dirs tests/security/fixtures) ;; esac
set +e
docker run --rm --user "$(id -u):$(id -g)" -v "$repo_root:/src" -v "$cache_dir:/tmp/trivy-cache" -w /src aquasec/trivy:0.73.0 "${args[@]}" "/src/$source_path"
scan_exit=$?
set -e
if [ ! -s "$repo_root/$report_path" ]; then printf '{"Results":[]}\n' > "$repo_root/$report_path"; fi
export DEVSHIELD_RESULT=$([ "$scan_exit" -eq 0 ] && echo PASS || echo TOOL_FAILURE)
export DEVSHIELD_COMMIT="$(git rev-parse HEAD 2>/dev/null || echo unknown)" DEVSHIELD_REPORT="$metadata_path" DEVSHIELD_SCA_REPORT="$repo_root/$report_path"
node <<'NODE'
const fs=require('fs'); let report;
try { report=JSON.parse(fs.readFileSync(process.env.DEVSHIELD_SCA_REPORT,'utf8')); } catch(e) { console.error(`Trivy evidence error: ${e.message}`); process.exit(2); }
const vulnerabilities=(report.Results||[]).flatMap(r=>(r.Vulnerabilities||[]).map(v=>({dependency:r.Target,package:v.PkgName,installed_version:v.InstalledVersion,vulnerability_id:v.VulnerabilityID,severity:v.Severity||'UNKNOWN',fixed_version:v.FixedVersion||null,status:v.Status||(v.FixedVersion?'fixed_available':'no_fix_available'),dependency_path:v.PkgPath||null})));
const counts=Object.fromEntries(['CRITICAL','HIGH','MEDIUM','LOW','UNKNOWN'].map(s=>[s,0])); for(const v of vulnerabilities) counts[v.severity]=(counts[v.severity]||0)+1;
const blocking=vulnerabilities.filter(v=>['CRITICAL','HIGH','UNKNOWN'].includes(v.severity)); const result=process.env.DEVSHIELD_RESULT==='TOOL_FAILURE'?'TOOL_FAILURE':blocking.length?'SECURITY_FAILURE':'PASS';
fs.writeFileSync(process.env.DEVSHIELD_REPORT,JSON.stringify({repository:process.env.GITHUB_REPOSITORY||'local',commit:process.env.GITHUB_SHA||process.env.DEVSHIELD_COMMIT,workflow_run:process.env.GITHUB_RUN_ID||'local',workflow:process.env.GITHUB_WORKFLOW||'local',scanner:'Trivy',scanner_version:'0.73.0',scan_time:new Date().toISOString(),result,dependency_manifests:(report.Results||[]).map(r=>r.Target),vulnerability_counts:counts,vulnerabilities,blocking_vulnerabilities:blocking},null,2)+'\n');
console.log(`Trivy SCA result: ${result}`); process.exit(result==='PASS'?0:1);
NODE
