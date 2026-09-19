#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

mode="${WAF_MODE:-blocking}"
upstream="${TARGET_UPSTREAM:-}"
environment="${WAF_ENVIRONMENT:-production}"
port="${WAF_PORT:-8080}"
name="${WAF_CONTAINER_NAME:-$WAF_DEFAULT_NAME}"
network="${WAF_NETWORK:-}"
paranoia="${CRS_PARANOIA_LEVEL:-1}"
threshold="${ANOMALY_THRESHOLD:-5}"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode) mode="$2"; shift 2 ;;
    --upstream) upstream="$2"; shift 2 ;;
    --environment) environment="$2"; shift 2 ;;
    --port) port="$2"; shift 2 ;;
    --name) name="$2"; shift 2 ;;
    --network) network="$2"; shift 2 ;;
    *) echo "WAF_CONFIG_FAILURE: unknown WAF option $1" >&2; exit 4 ;;
  esac
done
[[ "$port" =~ ^[1-9][0-9]{0,4}$ && "$port" -le 65535 ]] || { echo 'WAF_CONFIG_FAILURE: invalid listen port' >&2; exit 4; }
WAF_MODE="$mode" TARGET_UPSTREAM="$upstream" WAF_ENVIRONMENT="$environment" CRS_PARANOIA_LEVEL="$paranoia" ANOMALY_THRESHOLD="$threshold" "$repo_root/security/waf/validate-config.sh"
command -v docker >/dev/null 2>&1 || { echo 'WAF_STARTUP_FAILURE: Docker is required' >&2; exit 2; }
backend="$(backend_hostport "$upstream")"
docker rm -f "$name" >/dev/null 2>&1 || true
engine='On'
[[ "$mode" == detection ]] && engine='DetectionOnly'
args=(run -d --name "$name" -p "127.0.0.1:${port}:8080" -e "BACKEND=${backend}" -e "CORAZA_RULE_ENGINE=${engine}" -e "PARANOIA=${paranoia}" -e "BLOCKING_PARANOIA=${paranoia}" -e "ANOMALY_INBOUND=${threshold}" -e "CORAZA_AUDIT_ENGINE=RelevantOnly" -e "CORAZA_AUDIT_LOG=/dev/stdout" -e "CORAZA_AUDIT_LOG_FORMAT=JSON" -e "SERVER_TOKENS=off" -v "$repo_root/security/waf/config/coraza.conf:/opt/coraza/config.d/99-devshield.conf:ro" -v "$repo_root/security/waf/config/crs-setup.conf:/opt/coraza/config.d/98-devshield-crs.conf:ro" -v "$repo_root/security/waf/config/exclusions.conf:/opt/coraza/overrides/99-devshield-exclusions.conf:ro")
[[ -n "$network" ]] && args+=(--network "$network")
args+=("$WAF_IMAGE")
container_id="$(docker "${args[@]}")" || { echo 'WAF_STARTUP_FAILURE: unable to start Coraza CRS container' >&2; exit 2; }
printf 'WAF_STARTED: name=%s id=%s mode=%s upstream=%s port=%s config_hash=%s\n' "$name" "$container_id" "$mode" "$upstream" "$port" "$(config_hash)"
