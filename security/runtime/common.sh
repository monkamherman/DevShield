#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FALCO_IMAGE="${DEVSHIELD_FALCO_IMAGE:-docker.io/falcosecurity/falco:0.44.1}"
FALCO_VERSION="0.44.1"
FALCO_DRIVER="modern_ebpf"
DEVSHIELD_RULES_VERSION="1.0.0"
RUNTIME_CONTAINER_NAME="${DEVSHIELD_RUNTIME_CONTAINER_NAME:-devshield-falco}"

runtime_error() {
  echo "$1: $2" >&2
  return 1
}

rules_file="${DEVSHIELD_RUNTIME_RULES_FILE:-$repo_root/security/runtime/rules/devshield-rules.yaml}"
config_file="${DEVSHIELD_RUNTIME_CONFIG_FILE:-$repo_root/security/runtime/config/falco.yaml}"

rules_hash() { sha256sum "$rules_file" | awk '{print $1}'; }
config_hash() { sha256sum "$config_file" | awk '{print $1}'; }

require_runtime_files() {
  [[ -s "$rules_file" ]] || { runtime_error RUNTIME_SECURITY_RULE_FAILURE "custom Falco rules are missing"; return 1; }
  [[ -s "$config_file" ]] || { runtime_error RUNTIME_SECURITY_RULE_FAILURE "Falco configuration is missing"; return 1; }
}

docker_available() {
  command -v "${DEVSHIELD_DOCKER_BIN:-docker}" >/dev/null 2>&1 && "${DEVSHIELD_DOCKER_BIN:-docker}" info >/dev/null 2>&1
}

docker_cmd() {
  "${DEVSHIELD_DOCKER_BIN:-docker}" "$@"
}
