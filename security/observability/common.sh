#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OBSERVABILITY_SCHEMA_VERSION="1.0"
OBSERVABILITY_VERSION="1.0.0"
OBSERVABILITY_LOG_DIR="${DEVSHIELD_LOG_DIR:-$repo_root/reports/logs}"
OBSERVABILITY_LOG_FILE="${DEVSHIELD_LOG_FILE:-$OBSERVABILITY_LOG_DIR/security-events.jsonl}"
OBSERVABILITY_MAX_BYTES="${DEVSHIELD_LOG_MAX_BYTES:-10485760}"

observability_error() {
  echo "$1: $2" >&2
  return 1
}

observability_node() {
  command -v node >/dev/null 2>&1 || observability_error OBSERVABILITY_TOOL_FAILURE "node is required"
}
