#!/usr/bin/env bash
set -euo pipefail
endpoint="${HARBOR_URL:-https://harbor.local:8443}"
registry="${HARBOR_REGISTRY:-harbor.local:8443}"
: "${HARBOR_USERNAME:?Set HARBOR_USERNAME for registry integration tests}"
: "${HARBOR_PASSWORD:?Set HARBOR_PASSWORD for registry integration tests}"
curl --fail --silent --show-error --connect-timeout 5 "$endpoint/api/v2.0/systeminfo" >/dev/null || { echo "INFRASTRUCTURE_FAILURE: Harbor unavailable at $endpoint" >&2; exit 2; }
if ! printf '%s\n' "$HARBOR_PASSWORD" | docker login "$registry" --username "$HARBOR_USERNAME" --password-stdin >/dev/null 2>&1; then
  echo 'SECURITY_FAILURE: Harbor authentication failed' >&2; exit 1
fi
echo 'Registry availability/authentication: PASS'
echo 'Registry push/pull, RBAC and tag immutability tests require a provisioned non-admin test project.'
echo 'Set REGISTRY_FULL_TESTS=1 to enable the destructive-free push/pull checks described in docs/02-security/registry.md.'
if [[ "${REGISTRY_FULL_TESTS:-0}" == 1 ]]; then
  : "${HARBOR_PROJECT:?Set HARBOR_PROJECT}"; : "${HARBOR_REPOSITORY:?Set HARBOR_REPOSITORY}"
  tag="registry-test-${GITHUB_RUN_ID:-local}-$(date +%s)"; image="${REGISTRY_TEST_IMAGE:-alpine:3.21}"
  remote="$registry/$HARBOR_PROJECT/$HARBOR_REPOSITORY:$tag"
  docker image inspect "$image" >/dev/null || docker pull "$image" >/dev/null
  docker tag "$image" "$remote"; docker push "$remote" >/dev/null
  pushed="$(docker image inspect "$remote" --format '{{index .RepoDigests 0}}' | sed 's/.*@//')"
  docker rmi "$remote" >/dev/null; docker pull "$remote" >/dev/null
  pulled="$(docker image inspect "$remote" --format '{{index .RepoDigests 0}}' | sed 's/.*@//')"
  [[ "$pushed" == "$pulled" ]] || { echo 'SECURITY_FAILURE: Harbor digest changed across pull' >&2; exit 1; }
  echo "Registry push/pull digest consistency: PASS ($pulled)"
fi
