#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

target=""
environment=""
timeout_seconds="${DEVSHIELD_DAST_TIMEOUT:-10}"
allowed_hosts="${DEVSHIELD_DAST_ALLOWED_HOSTS:-localhost,127.0.0.1,::1}"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --target) target="$2"; shift 2 ;;
    --environment) environment="$2"; shift 2 ;;
    --timeout) timeout_seconds="$2"; shift 2 ;;
    --allowed-host) allowed_hosts="$2"; shift 2 ;;
    *) echo "CONFIGURATION_FAILURE: unknown target option $1" >&2; exit 4 ;;
  esac
done
[[ -n "$target" && -n "$environment" ]] || { echo 'CONFIGURATION_FAILURE: --target and --environment are required' >&2; exit 4; }
validate_environment "$environment" || exit 4
validate_target_configuration "$target" "$allowed_hosts" >/dev/null || exit 4
check_target_reachable "$target" "$timeout_seconds" || exit $?
