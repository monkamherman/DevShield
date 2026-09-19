#!/usr/bin/env bash
set -euo pipefail
repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"; cd "$repo_root"
commit="${GITHUB_SHA:-$(git rev-parse HEAD 2>/dev/null || echo local)}"; image_ref="${DEVSHIELD_IMAGE:-devshield:phase05-${commit}}"
report_dir="${DEVSHIELD_REPORT_DIR:-reports}"; mkdir -p "$repo_root/$report_dir"
sbom_path="$report_dir/image-sbom.cdx.json"; build_path="$repo_root/$report_dir/container-build-metadata.json"; cache_dir="${DEVSHIELD_SYFT_CACHE:-$repo_root/.syft-cache}"; mkdir -p "$cache_dir"
if [ ! -s "$build_path" ]; then echo "SBOM generation: TOOL_FAILURE (missing build metadata)" >&2; exit 2; fi
image_digest="$(node -e 'const x=require(process.argv[1]); process.stdout.write(x.image_digest||"")' "$build_path")"
if ! [[ "$image_digest" =~ ^sha256:[0-9a-f]{64}$ ]]; then echo "SBOM generation: TOOL_FAILURE (missing image digest)" >&2; exit 2; fi
set +e
docker run --rm --user 0:0 -v /var/run/docker.sock:/var/run/docker.sock -v "$repo_root:/src" -v "$cache_dir:/tmp/syft-cache" -w /src ghcr.io/anchore/syft:v1.51.0 "docker:$image_ref" -o cyclonedx-json > "$repo_root/$sbom_path"
syft_exit=$?
set -e
if [ "$syft_exit" -ne 0 ] || [ ! -s "$repo_root/$sbom_path" ]; then echo 'SBOM generation: TOOL_FAILURE' >&2; exit 2; fi
export DEVSHIELD_SBOM_FILE="$repo_root/$sbom_path" DEVSHIELD_IMAGE_DIGEST="$image_digest"
node <<'NODE'
const fs=require("fs"); const p=process.env.DEVSHIELD_SBOM_FILE; const bom=JSON.parse(fs.readFileSync(p));
bom.metadata=bom.metadata||{}; bom.metadata.properties=bom.metadata.properties||[]; bom.metadata.properties.push({name:"devshield:artifact-digest",value:process.env.DEVSHIELD_IMAGE_DIGEST});
fs.writeFileSync(p,JSON.stringify(bom,null,2)+"\n");
NODE
echo "SBOM generation: PASS ($sbom_path)"
