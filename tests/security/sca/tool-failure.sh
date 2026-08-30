#!/usr/bin/env bash
set -euo pipefail
fake_dir="$(mktemp -d)"; report_dir=".tmp-sca-failure-$$"; trap 'rm -rf "$fake_dir" "$report_dir"' EXIT
cat > "$fake_dir/docker" <<'DOCKER'
#!/usr/bin/env bash
exit 42
DOCKER
chmod +x "$fake_dir/docker"
if PATH="$fake_dir:$PATH" DEVSHIELD_REPORT_DIR="$report_dir" security/sca/trivy/run.sh; then
  echo 'Expected Trivy tool failure.' >&2; exit 1
fi
grep -q '"result": "TOOL_FAILURE"' "$report_dir/trivy-sca-metadata.json"
echo 'Trivy SCA tool-failure test: PASS'
