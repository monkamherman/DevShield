#!/usr/bin/env bash
set -euo pipefail
repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$repo_root"
commit="${GITHUB_SHA:-$(git rev-parse HEAD 2>/dev/null || echo local)}"
image_ref="${DEVSHIELD_IMAGE:-devshield:phase05-${commit}}"
report_dir="${DEVSHIELD_REPORT_DIR:-reports}"
mkdir -p "$repo_root/$report_dir"
image_report="$report_dir/trivy-container-image.json"
config_report="$report_dir/trivy-container-config.json"
metadata_report="$repo_root/$report_dir/trivy-container-metadata.json"
cache_dir="${DEVSHIELD_TRIVY_CACHE:-$repo_root/.trivy-cache}"
mkdir -p "$cache_dir"
set +e
docker run --rm --user 0:0 -v /var/run/docker.sock:/var/run/docker.sock -v "$repo_root:/src" -v "$cache_dir:/tmp/trivy-cache" aquasec/trivy:0.73.0 image --scanners vuln --format json --output "/src/$image_report" --cache-dir /tmp/trivy-cache "$image_ref"
image_exit=$?
docker run --rm --user "$(id -u):$(id -g)" -v "$repo_root:/src" -v "$cache_dir:/tmp/trivy-cache" aquasec/trivy:0.73.0 config --format json --output "/src/$config_report" --cache-dir /tmp/trivy-cache /src/apps/fixture/Dockerfile
config_exit=$?
set -e
[ -s "$repo_root/$image_report" ] || printf '{"Results":[]}\n' > "$repo_root/$image_report"
[ -s "$repo_root/$config_report" ] || printf '{"Results":[]}\n' > "$repo_root/$config_report"
export DEVSHIELD_IMAGE_REPORT="$repo_root/$image_report" DEVSHIELD_CONFIG_REPORT="$repo_root/$config_report" DEVSHIELD_METADATA="$metadata_report" DEVSHIELD_IMAGE_REF="$image_ref" DEVSHIELD_IMAGE_EXIT="$image_exit" DEVSHIELD_CONFIG_EXIT="$config_exit" DEVSHIELD_COMMIT="$commit"
node <<'NODE'
const fs=require('fs');
const read=p=>JSON.parse(fs.readFileSync(p,'utf8'));
let image,config; try { image=read(process.env.DEVSHIELD_IMAGE_REPORT); config=read(process.env.DEVSHIELD_CONFIG_REPORT); } catch(e) { console.error(e.message); process.exit(2); }
const imageFindings=(image.Results||[]).flatMap(r=>(r.Vulnerabilities||[]).map(v=>({source:'image',target:r.Target,package:v.PkgName,installed_version:v.InstalledVersion,vulnerability_id:v.VulnerabilityID,severity:v.Severity||'UNKNOWN',fixed_version:v.FixedVersion||null,status:v.Status||(v.FixedVersion?'fixed_available':'no_fix_available')})));
const configFindings=(config.Results||[]).flatMap(r=>(r.Misconfigurations||[]).map(v=>({source:'configuration',target:r.Target,check_id:v.ID,title:v.Title,severity:v.Severity||'UNKNOWN',status:v.Status||'FAIL',description:v.Description||null})));
const blocking=[...imageFindings,...configFindings].filter(v=>['CRITICAL','HIGH','UNKNOWN'].includes(v.severity));
const toolFailure=Number(process.env.DEVSHIELD_IMAGE_EXIT)!==0||Number(process.env.DEVSHIELD_CONFIG_EXIT)!==0;
const result=toolFailure?'TOOL_FAILURE':blocking.length?'SECURITY_FAILURE':'PASS';
let imageId=null; try { const {execFileSync}=require('child_process'); imageId=execFileSync('docker',['image','inspect','--format','{{.Id}}',process.env.DEVSHIELD_IMAGE_REF],{encoding:'utf8'}).trim(); } catch (_) {}
fs.writeFileSync(process.env.DEVSHIELD_METADATA,JSON.stringify({repository:process.env.GITHUB_REPOSITORY||'local',commit:process.env.DEVSHIELD_COMMIT,workflow:process.env.GITHUB_WORKFLOW||'local',workflow_run:process.env.GITHUB_RUN_ID||'local',image:process.env.DEVSHIELD_IMAGE_REF,image_id:imageId,image_digest:null,scanner:'Trivy',scanner_version:'0.73.0',scan_time:new Date().toISOString(),result,image_findings:imageFindings,configuration_findings:configFindings,blocking_findings:blocking},null,2)+'\n');
console.log(`Container security result: ${result}`); process.exit(result==='PASS'?0:1);
NODE
