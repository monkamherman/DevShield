#!/usr/bin/env bash
set -euo pipefail
report_dir=".tmp-sbom-failure-$$"; fake_dir="$(mktemp -d)"; trap 'rm -rf "$report_dir" "$fake_dir"' EXIT
DEVSHIELD_REPORT_DIR="$report_dir" make container-build >/dev/null
cat > "$fake_dir/docker" <<'DOCKER'
#!/usr/bin/env bash
exit 42
DOCKER
chmod +x "$fake_dir/docker"
if PATH="$fake_dir:$PATH" DEVSHIELD_REPORT_DIR="$report_dir" security/sbom/generate.sh; then exit 1; fi
if DEVSHIELD_SBOM="$report_dir/missing.json" security/sbom/validate.sh; then exit 1; fi
cp reports/image-sbom.cdx.json "$report_dir/empty.json" 2>/dev/null || true
printf '{"bomFormat":"CycloneDX","specVersion":"1.6","metadata":{"tools":[]},"components":[]}' > "$report_dir/empty.json"
if DEVSHIELD_SBOM="$report_dir/empty.json" security/sbom/validate.sh; then exit 1; fi
cp reports/container-build-metadata.json "$report_dir/no-digest-build.json"
node - "$report_dir/no-digest-build.json" <<'NODE'
const fs=require('fs'); const p=process.argv[2]; const x=JSON.parse(fs.readFileSync(p)); delete x.image_digest; fs.writeFileSync(p,JSON.stringify(x));
NODE
if DEVSHIELD_SBOM=reports/image-sbom.cdx.json DEVSHIELD_BUILD_METADATA="$report_dir/no-digest-build.json" DEVSHIELD_INVENTORY="$report_dir/no-digest-inventory.json" security/sbom/inventory.sh; then exit 1; fi
echo 'SBOM Syft/invalid/empty/missing-digest tests: PASS'
