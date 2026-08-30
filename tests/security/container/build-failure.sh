#!/usr/bin/env bash
set -euo pipefail
if DEVSHIELD_IMAGE=devshield:build-failure-$$ DEVSHIELD_DOCKERFILE=tests/security/fixtures/container/does-not-exist.Dockerfile security/container/build.sh; then
  echo 'Expected Docker build failure.' >&2
  exit 1
fi
echo 'Container build-failure test: PASS'
