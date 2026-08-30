#!/usr/bin/env bash
set -euo pipefail
repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"; cd "$repo_root"
report_dir="${DEVSHIELD_REPORT_DIR:-reports}"; sbom_path="${DEVSHIELD_SBOM:-$report_dir/image-sbom.cdx.json}"; build_path="${DEVSHIELD_BUILD_METADATA:-$repo_root/$report_dir/container-build-metadata.json}"; output="$repo_root/${DEVSHIELD_INVENTORY:-$report_dir/artifact-inventory.json}"
export DEVSHIELD_SBOM_ABS="$repo_root/$sbom_path" DEVSHIELD_BUILD_ABS="$build_path" DEVSHIELD_OUTPUT="$output"
node <<'NODE'
const fs=require('fs');
let bom,build; try { bom=JSON.parse(fs.readFileSync(process.env.DEVSHIELD_SBOM_ABS)); build=JSON.parse(fs.readFileSync(process.env.DEVSHIELD_BUILD_ABS)); } catch(e) { console.error(`Artifact inventory: TOOL_FAILURE (${e.message})`); process.exit(2); }
const digest=build.image_digest; if (!/^sha256:[0-9a-f]{64}$/.test(digest||'')) { console.error('Artifact inventory: TOOL_FAILURE (missing image digest)'); process.exit(2); }
const sbomDigest=(bom.metadata?.properties||[]).find(p=>p.name==='devshield:artifact-digest')?.value; if (sbomDigest!==digest) { console.error('Artifact inventory: SECURITY_FAILURE (SBOM digest mismatch)'); process.exit(1); }
if (bom.bomFormat!=='CycloneDX' || !bom.metadata || !Array.isArray(bom.components) || bom.components.length===0) { console.error('Artifact inventory: TOOL_FAILURE (invalid SBOM)'); process.exit(2); }
const inventory={schema_version:'1.0',artifact:{type:'container-image',reference:build.image,digest},source:{repository:build.repository,commit:build.commit},build:{workflow:build.workflow,workflow_run:build.workflow_run},sbom:{format:'CycloneDX JSON',generator:'Syft',generator_version:'1.51.0',location:process.env.DEVSHIELD_SBOM_ABS,component_count:bom.components.length,generation_timestamp:bom.metadata.timestamp||null},result:'PASS'};
fs.writeFileSync(process.env.DEVSHIELD_OUTPUT,JSON.stringify(inventory,null,2)+'\n'); console.log(`Artifact inventory: PASS (${digest})`);
NODE
