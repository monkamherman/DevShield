#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

mode="${WAF_MODE:-blocking}"
upstream="${TARGET_UPSTREAM:-}"
paranoia="${CRS_PARANOIA_LEVEL:-1}"
threshold="${ANOMALY_THRESHOLD:-5}"
environment="${WAF_ENVIRONMENT:-production}"
[[ -n "$upstream" ]] || { echo 'WAF_UPSTREAM_FAILURE: TARGET_UPSTREAM is required' >&2; exit 3; }
case "$environment" in development|staging|production) ;; *) echo 'WAF_CONFIG_FAILURE: invalid WAF_ENVIRONMENT' >&2; exit 4 ;; esac
validate_configuration "$mode" "$upstream" "$paranoia" "$threshold" || exit 4
echo "WAF_CONFIG_VALID: environment=${environment} mode=${mode} paranoia=${paranoia} threshold=${threshold} upstream=${upstream} crs=${WAF_CRS_VERSION} config_hash=$(config_hash)"
