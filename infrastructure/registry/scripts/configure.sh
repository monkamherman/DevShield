#!/usr/bin/env bash
set -euo pipefail
root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"; cd "$root"
environment="${1:-dev}"
[[ "$environment" =~ ^[a-z0-9-]+$ ]] || { echo 'Configuration failure: environment must contain lowercase letters, digits or hyphens' >&2; exit 1; }
command -v openssl >/dev/null || { echo 'TOOL_FAILURE: openssl is required' >&2; exit 2; }
config_dir="$root/infrastructure/registry"; secret_dir="$config_dir/secrets"
mkdir -p "$secret_dir" "$root/infrastructure/registry/runtime/data" "$root/infrastructure/registry/runtime/log"
previous_env="$config_dir/.env"
requested_checksum="${HARBOR_INSTALLER_SHA256:-}"
requested_admin="${HARBOR_ADMIN_PASSWORD:-}"
requested_database="${HARBOR_DATABASE_PASSWORD:-}"
if [[ -f "$previous_env" ]] && ! grep -q "<" "$previous_env"; then set -a; source "$previous_env"; set +a; fi
HARBOR_INSTALLER_SHA256="${requested_checksum:-${HARBOR_INSTALLER_SHA256:-}}"
HARBOR_ADMIN_PASSWORD="${requested_admin:-${HARBOR_ADMIN_PASSWORD:-}}"
HARBOR_DATABASE_PASSWORD="${requested_database:-${HARBOR_DATABASE_PASSWORD:-}}"
: "${HARBOR_INSTALLER_SHA256:?Set HARBOR_INSTALLER_SHA256 before generating configuration}"
hostname="${REGISTRY_HOSTNAME:-harbor-${environment}.local}"
port="${REGISTRY_PORT:-8443}"
admin="${HARBOR_ADMIN_PASSWORD:-}"
database="${HARBOR_DATABASE_PASSWORD:-}"
if [[ -z "$admin" ]]; then admin="$(openssl rand -hex 24)"; fi
if [[ -z "$database" ]]; then database="$(openssl rand -hex 24)"; fi
if [[ "$environment" == production || "$environment" == prod ]]; then
  [[ -n "${HARBOR_ADMIN_PASSWORD:-}" && -n "${HARBOR_DATABASE_PASSWORD:-}" ]] || { echo 'SECURITY_FAILURE: production passwords must be supplied by a secret manager/environment' >&2; exit 1; }
fi
if [[ ! -f "$secret_dir/ca.crt" || ! -f "$secret_dir/server.crt" || ! -f "$secret_dir/server.key" ]]; then
  openssl req -x509 -newkey rsa:4096 -sha256 -days 365 -nodes -keyout "$secret_dir/ca.key" -out "$secret_dir/ca.crt" -subj "/CN=DevShield ${environment} Local CA" >/dev/null 2>&1
  openssl req -newkey rsa:4096 -nodes -keyout "$secret_dir/server.key" -out "$secret_dir/server.csr" -subj "/CN=$hostname" >/dev/null 2>&1
  ext="$(mktemp)"; trap 'rm -f "$ext"' EXIT
  printf 'subjectAltName=DNS:%s,DNS:localhost,IP:127.0.0.1\n' "$hostname" > "$ext"
  openssl x509 -req -sha256 -days 365 -in "$secret_dir/server.csr" -CA "$secret_dir/ca.crt" -CAkey "$secret_dir/ca.key" -CAcreateserial -extfile "$ext" -out "$secret_dir/server.crt" >/dev/null 2>&1
  rm -f "$secret_dir/server.csr" "$secret_dir/ca.srl"
fi
cat > "$config_dir/.env" <<EOF
# Generated for profile: $environment. Do not commit.
HARBOR_VERSION=${HARBOR_VERSION:-2.14.4}
HARBOR_INSTALLER_SHA256=$HARBOR_INSTALLER_SHA256
HARBOR_HOSTNAME=$hostname
HARBOR_PORT=$port
HARBOR_ADMIN_PASSWORD=$admin
HARBOR_DATABASE_PASSWORD=$database
HARBOR_PROJECT=${HARBOR_PROJECT:-devshield}
HARBOR_REPOSITORY=${HARBOR_REPOSITORY:-fixture}
EOF
cat > "$config_dir/harbor.yml" <<EOF
# Generated profile: $environment. Local HTTPS configuration.
hostname: $hostname
http:
  port: ${REGISTRY_HTTP_PORT:-18080}
https:
  port: $port
  certificate: $secret_dir/server.crt
  private_key: $secret_dir/server.key
harbor_admin_password: $admin
database:
  password: $database
  max_idle_conns: 100
  max_open_conns: 900
data_volume: $root/infrastructure/registry/runtime/data
trivy:
  ignore_unfixed: false
  vuln_type: "os,library"
  severity: "UNKNOWN,LOW,MEDIUM,HIGH,CRITICAL"
jobservice:
  max_job_workers: 10
  max_job_duration_hours: 24
  job_loggers:
    - STD_OUTPUT
    - FILE
  logger_sweeper_duration: 1
notification:
  webhook_job_max_retry: 3
  webhook_job_http_client_timeout: 3
log:
  level: info
  local:
    rotate_count: 50
    rotate_size: 200M
    location: $root/infrastructure/registry/runtime/log
EOF
chmod 600 "$config_dir/.env" "$config_dir/harbor.yml" "$secret_dir"/* 2>/dev/null || true
echo "Harbor configuration: PASS (profile=$environment, host=$hostname:$port)"
echo 'Run make registry-up to verify the installer and deploy the official Harbor distribution.'
