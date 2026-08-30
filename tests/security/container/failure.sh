#!/usr/bin/env bash
set -euo pipefail
bad_dir="$(mktemp -d)"; report_dir=".tmp-container-failure-$$"; trap 'rm -rf "$bad_dir" "$report_dir"' EXIT
cat > "$bad_dir/docker" <<'DOCKER'
#!/usr/bin/env bash
exit 42
DOCKER
chmod +x "$bad_dir/docker"
if PATH="$bad_dir:$PATH" DEVSHIELD_IMAGE=devshield:missing DEVSHIELD_REPORT_DIR="$report_dir" security/container/scan.sh; then echo 'Expected scanner failure.' >&2; exit 1; fi
grep -q '"result": "TOOL_FAILURE"' "$report_dir/trivy-container-metadata.json"
echo 'Container scanner-failure test: PASS'
