#!/usr/bin/env bash
set -euo pipefail
root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"; cd "$root"
if [[ "${DEVSHIELD_SKIP_SECURITY_GATE:-0}" != 1 ]]; then
  make security
else
  [[ "${DEVSHIELD_GATE_CONFIRMED:-0}" == 1 ]] || { echo 'SECURITY_FAILURE: refusing ungated registry push' >&2; exit 1; }
fi
: "${HARBOR_REGISTRY:?Set HARBOR_REGISTRY}"
: "${HARBOR_USERNAME:?Set HARBOR_USERNAME}"
: "${HARBOR_PASSWORD:?Set HARBOR_PASSWORD}"
commit="${GITHUB_SHA:-$(git rev-parse HEAD)}"
local_image="${DEVSHIELD_IMAGE:-devshield:phase05-${commit}}"
project="${HARBOR_PROJECT:-devshield}"; repository="${HARBOR_REPOSITORY:-fixture}"
remote="${HARBOR_REGISTRY}/${project}/${repository}:sha-${commit}"
docker image inspect "$local_image" >/dev/null || { echo 'TOOL_FAILURE: approved local image is missing' >&2; exit 2; }
printf '%s\n' "$HARBOR_PASSWORD" | docker login "$HARBOR_REGISTRY" --username "$HARBOR_USERNAME" --password-stdin >/dev/null
docker tag "$local_image" "$remote"; docker push "$remote" >/dev/null
digest="$(docker image inspect "$remote" --format '{{index .RepoDigests 0}}' 2>/dev/null | sed 's/.*@//')"
[[ "$digest" =~ ^sha256:[0-9a-f]{64}$ ]] || { echo 'TOOL_FAILURE: registry did not return a valid digest' >&2; exit 2; }
report_dir="${DEVSHIELD_REPORT_DIR:-reports}"; mkdir -p "$report_dir"
printf '{"schema_version":"1.0","result":"PASS","registry":"%s","repository":"%s","tag":"sha-%s","digest":"%s","source_commit":"%s"}\n' "$HARBOR_REGISTRY" "$project/$repository" "$commit" "$digest" "$commit" > "$report_dir/registry-push-evidence.json"
echo "Registry push: PASS ($remote@$digest)"
