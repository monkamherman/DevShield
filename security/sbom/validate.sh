#!/usr/bin/env bash
set -euo pipefail
repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"; cd "$repo_root"
sbom_path="${DEVSHIELD_SBOM:-${DEVSHIELD_REPORT_DIR:-reports}/image-sbom.cdx.json}"
node - "$repo_root/$sbom_path" <<'NODE'
const fs=require('fs'); const path=process.argv[2];
let bom; try { if (!fs.statSync(path).size) throw Error('empty file'); bom=JSON.parse(fs.readFileSync(path,'utf8')); } catch(e) { console.error(`SBOM validation: TOOL_FAILURE (${e.message})`); process.exit(2); }
if (bom.bomFormat !== 'CycloneDX' || !bom.specVersion || !bom.metadata || !bom.metadata.tools || !Array.isArray(bom.components) || bom.components.length === 0) { console.error('SBOM validation: TOOL_FAILURE (invalid or empty CycloneDX inventory)'); process.exit(2); }
console.log(`SBOM validation: PASS (${bom.components.length} components, CycloneDX ${bom.specVersion})`);
NODE
