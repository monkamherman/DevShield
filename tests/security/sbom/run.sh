#!/usr/bin/env bash
set -euo pipefail
report_dir=".tmp-sbom-test-$$"; trap 'rm -rf "$report_dir"' EXIT
DEVSHIELD_REPORT_DIR="$report_dir" make container-build >/dev/null
DEVSHIELD_REPORT_DIR="$report_dir" security/sbom/generate.sh
DEVSHIELD_REPORT_DIR="$report_dir" security/sbom/validate.sh
DEVSHIELD_REPORT_DIR="$report_dir" security/sbom/inventory.sh
grep -q '"result": "PASS"' "$report_dir/artifact-inventory.json"
! grep -R -q 'DEVSHIELD_TEST_SECRET' "$report_dir"
cp "$report_dir/image-sbom.cdx.json" "$report_dir/corrupt.json"; printf '{bad json' > "$report_dir/corrupt.json"
if DEVSHIELD_SBOM="$report_dir/corrupt.json" security/sbom/validate.sh; then exit 1; fi
cp "$report_dir/image-sbom.cdx.json" "$report_dir/mismatch.json"
node - "$report_dir/mismatch.json" <<'NODE'
const fs=require('fs'); const p=process.argv[2]; const x=JSON.parse(fs.readFileSync(p)); const q=x.metadata.properties.find(v=>v.name==='devshield:artifact-digest'); q.value='sha256:'+'0'.repeat(64); fs.writeFileSync(p,JSON.stringify(x));
NODE
if DEVSHIELD_SBOM="$report_dir/mismatch.json" DEVSHIELD_INVENTORY="$report_dir/mismatch-inventory.json" security/sbom/inventory.sh; then exit 1; fi
echo 'SBOM valid/corrupt/mismatch/no-secret tests: PASS'
