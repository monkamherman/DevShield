#!/usr/bin/env bash
set -euo pipefail
: "${HARBOR_REGISTRY:?Set HARBOR_REGISTRY}"
: "${HARBOR_PROJECT:?Set HARBOR_PROJECT}"
: "${HARBOR_REPOSITORY:?Set HARBOR_REPOSITORY}"
: "${HARBOR_TAG:?Set HARBOR_TAG}"
remote="$HARBOR_REGISTRY/$HARBOR_PROJECT/$HARBOR_REPOSITORY:$HARBOR_TAG"
docker pull "$remote" >/dev/null
digest="$(docker image inspect "$remote" --format '{{index .RepoDigests 0}}' | sed 's/.*@//')"
[[ "$digest" =~ ^sha256:[0-9a-f]{64}$ ]] || { echo 'TOOL_FAILURE: pulled artifact has no valid digest' >&2; exit 2; }
[[ -z "${EXPECTED_DIGEST:-}" || "$digest" == "$EXPECTED_DIGEST" ]] || { echo 'SECURITY_FAILURE: pulled digest mismatch' >&2; exit 1; }
echo "Registry pull: PASS ($remote@$digest)"
