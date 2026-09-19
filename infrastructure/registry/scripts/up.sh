#!/usr/bin/env bash
set -euo pipefail
root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"; cd "$root"
if [[ -f infrastructure/registry/.env ]]; then set -a; source infrastructure/registry/.env; set +a; fi
version="${HARBOR_VERSION:-2.14.4}"; runtime="$root/infrastructure/registry/runtime"
installer="$runtime/harbor-offline-installer-v${version}.tgz"
url="https://github.com/goharbor/harbor/releases/download/v${version}/harbor-offline-installer-v${version}.tgz"
mkdir -p "$runtime"
[[ -n "${HARBOR_INSTALLER_SHA256:-}" ]] || { echo 'INFRASTRUCTURE_FAILURE: set HARBOR_INSTALLER_SHA256 before downloading Harbor' >&2; exit 2; }
  if [[ ! -f "$installer" ]]; then
    command -v curl >/dev/null || { echo 'TOOL_FAILURE: curl is required' >&2; exit 2; }
    curl --fail --location --proto '=https' --tlsv1.2 --output "$installer" "$url"
  fi
  printf '%s  %s\n' "$HARBOR_INSTALLER_SHA256" "$installer" | sha256sum --check --status || { echo 'TOOL_FAILURE: Harbor installer checksum mismatch' >&2; exit 2; }
installer_dir="$runtime/harbor"
if [[ ! -x "$installer_dir/install.sh" ]]; then
  rm -rf "$installer_dir"
  mkdir -p "$installer_dir"
  tar -xzf "$installer" -C "$installer_dir" --strip-components=1
fi
config="${HARBOR_CONFIG:-$root/infrastructure/registry/harbor.yml}"
[[ -f "$config" ]] || { echo "INFRASTRUCTURE_FAILURE: create $config from harbor.yml.example and set local secrets" >&2; exit 2; }
cp "$config" "$installer_dir/harbor.yml"
( cd "$installer_dir" && ./prepare && sudo ./install.sh --with-trivy )
echo "Harbor ${version}: PASS (official installer)" 
echo 'The official installer owns Harbor’s generated Docker Compose topology; this script does not reproduce internal services.'
