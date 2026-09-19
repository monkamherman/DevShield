#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

environment=""
artifact=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --artifact) artifact="$2"; shift 2 ;;
    --environment) environment="$2"; shift 2 ;;
    *) echo "TOOL_FAILURE: unknown artifact option $1" >&2; exit 2 ;;
  esac
done
[[ -n "$artifact" && -n "$environment" ]] || { echo 'TOOL_FAILURE: --artifact and --environment are required' >&2; exit 2; }
validate_environment "$environment"
validate_artifact_reference "$artifact"
echo "Artifact reference valid for ${environment}: ${artifact}"
