#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
source_path="${1:-.}"
report_dir="${DEVSHIELD_REPORT_DIR:-reports}"
mkdir -p "$repo_root/$report_dir"
report_path="$report_dir/semgrep.json"
metadata_path="$repo_root/$report_dir/semgrep-metadata.json"

cd "$repo_root"
scan_args=(
  semgrep scan
  --config security/sast/semgrep/semgrep.yml
  --json
  --output "$report_path"
  --error
  --exclude .git
  --exclude node_modules
  --exclude dist
  --exclude build
  --exclude coverage
  --exclude reports
)
case "$source_path" in
  tests/security/fixtures/*) ;;
  *) scan_args+=(--exclude tests/security/fixtures) ;;
esac

set +e
docker run --rm \
  --user "$(id -u):$(id -g)" \
  -v "$repo_root:/src" \
  -w /src \
  semgrep/semgrep:1.172.0 \
  "${scan_args[@]}" \
  "$source_path"
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
  scanner: 'Semgrep',
  scanner_version: '1.172.0',
  scan_time: new Date().toISOString(),
  result: process.env.DEVSHIELD_RESULT,
};
fs.writeFileSync(process.env.DEVSHIELD_REPORT, `${JSON.stringify(metadata, null, 2)}\n`);
NODE

echo "Semgrep result: $result"
exit "$scan_exit"
