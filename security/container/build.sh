#!/usr/bin/env bash
set -euo pipefail
repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$repo_root"
commit="${GITHUB_SHA:-$(git rev-parse HEAD 2>/dev/null || echo local)}"
image_ref="${DEVSHIELD_IMAGE:-devshield:phase05-${commit}}"
dockerfile="${DEVSHIELD_DOCKERFILE:-apps/fixture/Dockerfile}"
echo "Building container image: $image_ref"
docker build --progress=plain -f "$dockerfile" -t "$image_ref" .
echo "Container build: PASS ($image_ref)"
