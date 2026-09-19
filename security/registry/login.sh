#!/usr/bin/env bash
set -euo pipefail
: "${HARBOR_REGISTRY:?Set HARBOR_REGISTRY, e.g. harbor.local:8443}"
: "${HARBOR_USERNAME:?Set HARBOR_USERNAME}"
: "${HARBOR_PASSWORD:?Set HARBOR_PASSWORD}"
printf '%s\n' "$HARBOR_PASSWORD" | docker login "$HARBOR_REGISTRY" --username "$HARBOR_USERNAME" --password-stdin >/dev/null
echo "Registry login: PASS ($HARBOR_REGISTRY)"
