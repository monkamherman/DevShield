#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
source_path="${1:-.}"
report_dir="${DEVSHIELD_REPORT_DIR:-reports}"
mkdir -p "$repo_root/$report_dir"
report_path="$report_dir/gitleaks.json"
metadata_path="$repo_root/$report_dir/gitleaks-metadata.json"
config_path="security/secrets/gitleaks/gitleaks.toml"

case "$source_path" in
  tests/security/fixtures/*) config_path="security/secrets/gitleaks/gitleaks-test.toml" ;;
esac

cd "$repo_root"
set +e
docker run --rm \
  --user "$(id -u):$(id -g)" \
  -v "$repo_root:/src" \
  -w /src \
  ghcr.io/gitleaks/gitleaks:v8.30.1 \
  detect \
  --source "$source_path" \
  --config "$config_path" \
  --report-format json \
  --report-path "$report_path" \
  --redact \
  --exit-code 1
scan_exit=$?
set -e

result=PASS
if [ "$scan_exit" -eq 1 ]; then
  result=SECURITY_FAILURE
elif [ "$scan_exit" -ne 0 ]; then
  result=TOOL_FAILURE
fi

export DEVSHIELD_RESULT="$result"
export DEVSHIELD_COMMIT="$(git rev-parse HEAD 2>/dev/null || echo unknown)"
export DEVSHIELD_REPORT="$metadata_path"
node <<'NODE'
const fs = require('fs');
const metadata = {
  repository: process.env.GITHUB_REPOSITORY || 'local',
  commit: process.env.GITHUB_SHA || process.env.DEVSHIELD_COMMIT,
  workflow_run: process.env.GITHUB_RUN_ID || 'local',
  scanner: 'Gitleaks',
  scanner_version: '8.30.1',
  scan_time: new Date().toISOString(),
  result: process.env.DEVSHIELD_RESULT,
  redacted: true,
};
fs.writeFileSync(process.env.DEVSHIELD_REPORT, `${JSON.stringify(metadata, null, 2)}\n`);
NODE

echo "Gitleaks result: $result"
exit "$scan_exit"
