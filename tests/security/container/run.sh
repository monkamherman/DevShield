#!/usr/bin/env bash
set -euo pipefail
image="devshield:test-$$"; vulnerable_image="devshield:vulnerable-$$"; report_dir=".tmp-container-test-$$"; trap 'rm -rf "$report_dir"; docker image rm "$image" "$vulnerable_image" >/dev/null 2>&1 || true' EXIT
DEVSHIELD_IMAGE="$image" security/container/build.sh
test "$(docker run --rm "$image" id -u)" = 1000
docker run --rm "$image" sh -c '! grep -R "DEVSHIELD_TEST_SECRET" /app 2>/dev/null'
DEVSHIELD_IMAGE="$image" DEVSHIELD_REPORT_DIR="$report_dir" security/container/scan.sh
grep -q '"result": "PASS"' "$report_dir/trivy-container-metadata.json"
vulnerable_image=devshield:vulnerable-$$
DEVSHIELD_IMAGE="$vulnerable_image" DEVSHIELD_DOCKERFILE=tests/security/fixtures/container/vulnerable/Dockerfile security/container/build.sh
if DEVSHIELD_IMAGE="$vulnerable_image" DEVSHIELD_REPORT_DIR="$report_dir/vulnerable" security/container/scan.sh; then echo 'Expected vulnerable image to fail.' >&2; exit 1; fi
grep -q 'SECURITY_FAILURE' "$report_dir/vulnerable/trivy-container-metadata.json"
docker image rm "$vulnerable_image" >/dev/null
echo 'Container clean, vulnerable, non-root and no-secret tests: PASS'
