#!/usr/bin/env bash
set -euo pipefail

OPA_VERSION="1.20.2"
OPA_SHA256_LINUX_AMD64="ed3127751a4c786eb407d26a952c92f45fdcc4b97e0af25cd5d721a414fab244"
repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
opa_dir="${DEVSHIELD_OPA_DIR:-$repo_root/.local/opa}"
opa_bin="${DEVSHIELD_OPA_BIN:-$opa_dir/opa}"

require_opa() {
  [[ -x "$opa_bin" ]] || { echo "TOOL_FAILURE: OPA ${OPA_VERSION} is not installed at ${opa_bin}; run make opa-install" >&2; return 2; }
}

opa_version() {
  require_opa || return
  "$opa_bin" version
}

policy_files_hash() {
  local policy_dir="${1:-$repo_root/security/policies/opa}"
  find "$policy_dir" -maxdepth 1 -type f -name '*.rego' -print0 | sort -z | xargs -0 sha256sum | sha256sum | awk '{print $1}'
}
