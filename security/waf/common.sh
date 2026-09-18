#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WAF_IMAGE="${DEVSHIELD_WAF_IMAGE:-ghcr.io/coreruleset/coraza-crs:4.25.0-nginx-202509051009}"
WAF_PRODUCT_VERSION="coraza-nginx-0.21.0"
WAF_CRS_VERSION="4.25.0"
WAF_DEFAULT_NAME="devshield-waf"

waf_error() {
  echo "$1: $2" >&2
  return 1
}

validate_mode() {
  case "$1" in
    detection|blocking) return 0 ;;
    *) waf_error WAF_CONFIG_FAILURE "WAF_MODE must be detection or blocking" ;;
  esac
}

validate_upstream() {
  node - "$1" <<'NODE'
const value=process.argv[2];
try {
  const url=new URL(value);
  if (!['http:','https:'].includes(url.protocol) || !url.hostname || url.pathname !== '/' || url.search || url.hash || url.username || url.password) process.exit(1);
  if (url.port && (!/^\d+$/.test(url.port) || Number(url.port)<1 || Number(url.port)>65535)) process.exit(1);
} catch (_) { process.exit(1); }
NODE
}

validate_configuration() {
  local mode="$1" upstream="$2" paranoia="$3" threshold="$4"
  validate_mode "$mode" || return 1
  validate_upstream "$upstream" || { waf_error WAF_UPSTREAM_FAILURE "invalid upstream URL"; return 1; }
  [[ "$paranoia" =~ ^[1-4]$ ]] || { waf_error WAF_CONFIG_FAILURE "CRS paranoia level must be between 1 and 4"; return 1; }
  [[ "$threshold" =~ ^[1-9][0-9]*$ ]] || { waf_error WAF_CONFIG_FAILURE "anomaly threshold must be a positive integer"; return 1; }
  [[ -f "$repo_root/security/waf/config/coraza.conf" && -f "$repo_root/security/waf/config/crs-setup.conf" ]] || { waf_error WAF_CRS_FAILURE "versioned WAF configuration is incomplete"; return 1; }
}

config_hash() {
  sha256sum "$repo_root/security/waf/config/coraza.conf" "$repo_root/security/waf/config/crs-setup.conf" "$repo_root/security/waf/config/exclusions.conf" | sha256sum | awk '{print $1}'
}

backend_hostport() {
  node - "$1" <<'NODE'
const url=new URL(process.argv[2]); process.stdout.write(`${url.hostname}:${url.port || (url.protocol==='https:' ? 443 : 80)}`);
NODE
}
