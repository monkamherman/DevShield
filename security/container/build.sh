#!/usr/bin/env bash
set -euo pipefail
repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$repo_root"
commit="${GITHUB_SHA:-$(git rev-parse HEAD 2>/dev/null || echo local)}"
image_ref="${DEVSHIELD_IMAGE:-devshield:phase05-${commit}}"
dockerfile="${DEVSHIELD_DOCKERFILE:-apps/fixture/Dockerfile}"
report_dir="${DEVSHIELD_REPORT_DIR:-reports}"
mkdir -p "$repo_root/$report_dir"
metadata_file="$repo_root/$report_dir/container-build-metadata.json"
raw_metadata="$repo_root/$report_dir/.buildx-metadata.json"
rm -f "$metadata_file" "$raw_metadata"
echo "Building container image: $image_ref"
docker buildx build --load --progress=plain --metadata-file "$raw_metadata" -f "$dockerfile" -t "$image_ref" .
export DEVSHIELD_RAW_METADATA="$raw_metadata" DEVSHIELD_BUILD_METADATA="$metadata_file" DEVSHIELD_IMAGE_REF="$image_ref" DEVSHIELD_COMMIT="$commit"
node <<'NODE'
const fs=require("fs");
const raw=JSON.parse(fs.readFileSync(process.env.DEVSHIELD_RAW_METADATA,"utf8"));
const digest=raw["containerimage.digest"];
if (typeof digest !== "string" || !/^sha256:[0-9a-f]{64}$/.test(digest)) { console.error("BuildKit did not provide a valid image digest"); process.exit(2); }
fs.writeFileSync(process.env.DEVSHIELD_BUILD_METADATA, JSON.stringify({repository:process.env.GITHUB_REPOSITORY||"local",commit:process.env.GITHUB_SHA||process.env.DEVSHIELD_COMMIT,workflow:process.env.GITHUB_WORKFLOW||"local",workflow_run:process.env.GITHUB_RUN_ID||"local",image:process.env.DEVSHIELD_IMAGE_REF,image_digest:digest,build_tool:"Docker BuildKit",build_time:new Date().toISOString()},null,2)+"\n");
NODE
rm -f "$raw_metadata"
echo "Container build: PASS ($image_ref)"
