#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

deployment_error() {
  echo "$1: $2" >&2
  return 1
}

validate_environment() {
  case "$1" in
    development|staging|production) return 0 ;;
    *) deployment_error TOOL_FAILURE "unsupported deployment environment: $1" ;;
  esac
}

validate_artifact_reference() {
  local reference="$1"
  [[ "$reference" == *@sha256:* ]] || deployment_error VERIFICATION_FAILURE "deployment requires an immutable digest reference"
  [[ "$reference" =~ @sha256:[0-9a-f]{64}$ ]] || deployment_error VERIFICATION_FAILURE "artifact reference has an invalid sha256 digest"
  local repository="${reference%@sha256:*}"
  [[ "$repository" == */* ]] || deployment_error VERIFICATION_FAILURE "artifact reference must include a registry/repository"
  [[ "${repository##*/}" != *:* ]] || deployment_error VERIFICATION_FAILURE "mutable image tags are not accepted for deployment"
}

json_field() {
  node -e 'const fs=require("fs"); const x=JSON.parse(fs.readFileSync(process.argv[1], "utf8")); let v=x; for (const key of process.argv.slice(2)) v=v?.[key]; if (v === undefined || v === null) process.exit(1); process.stdout.write(typeof v === "string" ? v : JSON.stringify(v));' "$@"
}
