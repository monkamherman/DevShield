#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"
version_output="$(opa_version 2>&1)" || { echo "$version_output" >&2; exit 2; }
grep -Eq "Version: ${OPA_VERSION}([^0-9]|$)" <<<"$version_output" || { echo "TOOL_FAILURE: expected OPA ${OPA_VERSION}, got: ${version_output//$'\n'/ }" >&2; exit 2; }
printf '%s\n' "$version_output"
