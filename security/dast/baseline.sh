#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

target=""
environment=""
artifact="${DEVSHIELD_DAST_ARTIFACT:-}"
output_dir="${DEVSHIELD_DAST_REPORT_DIR:-$repo_root/reports/dast}"
timeout_seconds="${DEVSHIELD_DAST_TIMEOUT:-10}"
allowed_hosts="${DEVSHIELD_DAST_ALLOWED_HOSTS:-localhost,127.0.0.1,::1}"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --target) target="$2"; shift 2 ;;
    --environment) environment="$2"; shift 2 ;;
    --artifact) artifact="$2"; shift 2 ;;
    --output-dir) output_dir="$2"; shift 2 ;;
    --timeout) timeout_seconds="$2"; shift 2 ;;
    --allowed-host) allowed_hosts="$2"; shift 2 ;;
    *) echo "CONFIGURATION_FAILURE: unknown baseline option $1" >&2; exit 4 ;;
  esac
done
[[ -n "$target" && -n "$environment" ]] || { echo 'CONFIGURATION_FAILURE: --target and --environment are required' >&2; exit 4; }
validate_environment "$environment" || exit 4
validate_target_configuration "$target" "$allowed_hosts" >/dev/null || exit 4
set +e
check_target_reachable "$target" "$timeout_seconds"
target_status=$?
set -e
[[ "$target_status" -eq 0 ]] || exit "$target_status"

mkdir -p "$output_dir"
json_report="$output_dir/zap-report.json"
html_report="$output_dir/zap-report.html"
evidence="$output_dir/dast-evidence.json"
started="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
scanner_exit=0
if [[ "${DEVSHIELD_DAST_TEST_MODE:-0}" == "1" && -n "${DEVSHIELD_ZAP_BIN:-}" ]]; then
  set +e
  "$DEVSHIELD_ZAP_BIN" "$target" "$json_report" "$html_report"
  scanner_exit=$?
  set -e
else
  command -v docker >/dev/null 2>&1 || { echo 'TOOL_FAILURE: Docker is required for the pinned OWASP ZAP image' >&2; exit 2; }
  set +e
  docker run --rm --network host -v "$(realpath "$output_dir"):/zap/wrk:rw" "$ZAP_IMAGE" zap-baseline.py -t "$target" -J "$(basename "$json_report")" -r "$(basename "$html_report")" -I
  scanner_exit=$?
  set -e
fi
DEVSHIELD_ZAP_VERSION="$ZAP_VERSION" DEVSHIELD_DAST_STARTED_AT="$started" DEVSHIELD_DAST_SCANNER_EXIT="$scanner_exit" \
  "$repo_root/security/dast/parse-results.sh" --json "$json_report" --html "$html_report" --output "$evidence" --target "$target" --environment "$environment" --artifact "$artifact" --started-at "$started" --scanner-exit "$scanner_exit"
