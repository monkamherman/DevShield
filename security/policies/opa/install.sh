#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

command -v curl >/dev/null || { echo 'TOOL_FAILURE: curl is required to install OPA' >&2; exit 2; }
command -v sha256sum >/dev/null || { echo 'TOOL_FAILURE: sha256sum is required to verify OPA' >&2; exit 2; }
[[ "$(uname -s)" == Linux && "$(uname -m)" == x86_64 ]] || { echo 'TOOL_FAILURE: pinned OPA installer currently supports Linux x86_64 only' >&2; exit 2; }

mkdir -p "$opa_dir"
download="$opa_dir/opa-${OPA_VERSION}.tmp"
url="https://openpolicyagent.org/downloads/v${OPA_VERSION}/opa_linux_amd64"
curl --fail --location --proto '=https' --tlsv1.2 --output "$download" "$url"
printf '%s  %s\n' "$OPA_SHA256_LINUX_AMD64" "$download" | sha256sum --check --status || { rm -f "$download"; echo 'TOOL_FAILURE: OPA checksum mismatch' >&2; exit 2; }
chmod 755 "$download"
mv "$download" "$opa_bin"
version_output="$($opa_bin version 2>&1)" || { echo 'TOOL_FAILURE: installed OPA cannot execute' >&2; exit 2; }
grep -Eq "Version: ${OPA_VERSION}([^0-9]|$)" <<<"$version_output" || { echo "TOOL_FAILURE: expected OPA ${OPA_VERSION}, got: ${version_output//$'\n'/ }" >&2; exit 2; }
echo "OPA installation: PASS (${OPA_VERSION})"
