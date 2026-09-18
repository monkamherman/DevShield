#!/usr/bin/env bash
set -euo pipefail

COSIGN_VERSION="3.1.3"
COSIGN_IMAGE="ghcr.io/sigstore/cosign/cosign:v${COSIGN_VERSION}"
repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

cosign_run() {
  command -v docker >/dev/null || { echo 'TOOL_FAILURE: Docker is required for the pinned Cosign wrapper' >&2; return 2; }
  local docker_config="${DOCKER_CONFIG:-${HOME:-}/.docker}"
  local mounts=(-v "$repo_root:/work:rw")
  local env_args=()
  for variable in COSIGN_PASSWORD ACTIONS_ID_TOKEN_REQUEST_URL ACTIONS_ID_TOKEN_REQUEST_TOKEN GITHUB_ACTIONS GITHUB_REPOSITORY GITHUB_WORKFLOW GITHUB_REF GITHUB_SHA; do
    if [[ -n "${!variable+x}" ]]; then
      env_args+=(-e "$variable")
    fi
  done
  if [[ -f "$docker_config/config.json" ]]; then
    mounts+=(-v "$docker_config:/root/.docker:ro")
  fi
  docker run --rm --user 0:0 "${env_args[@]}" "${mounts[@]}" -w /work "$COSIGN_IMAGE" "$@"
}

require_cosign_version() {
  local version_output
  version_output="$(cosign_run version 2>&1)" || { echo 'TOOL_FAILURE: unable to execute pinned Cosign' >&2; return 2; }
  grep -Eq "(^|[^0-9])v?${COSIGN_VERSION}([^0-9]|$)" <<<"$version_output" || {
    echo "TOOL_FAILURE: expected Cosign ${COSIGN_VERSION}, got: ${version_output//$'\n'/ }" >&2
    return 2
  }
}

validate_digest_reference() {
  local reference="$1"
  [[ "$reference" == *@sha256:* ]] || { echo 'SECURITY_FAILURE: signing requires an immutable @sha256 digest reference' >&2; return 1; }
  local name="${reference%@*}" digest="${reference##*@}"
  [[ "$name" == */* ]] || { echo 'SECURITY_FAILURE: image reference must include a registry and repository' >&2; return 1; }
  [[ "$digest" =~ ^sha256:[0-9a-f]{64}$ ]] || { echo 'SECURITY_FAILURE: invalid image digest' >&2; return 1; }
  local last_component="${name##*/}"
  [[ "$last_component" != *:* ]] || { echo 'SECURITY_FAILURE: mutable image tags are not accepted as trust identity' >&2; return 1; }
}

validate_approved_registry() {
  local reference="$1" registry="${HARBOR_REGISTRY:?Set HARBOR_REGISTRY}"
  [[ "$reference" == "$registry/"* ]] || { echo "SECURITY_FAILURE: image is outside approved registry ${registry}" >&2; return 1; }
}

registry_reachable() {
  local endpoint="${HARBOR_URL:-https://${HARBOR_REGISTRY}/api/v2.0/systeminfo}"
  local ca="${HARBOR_CA_CERT:-$repo_root/infrastructure/registry/secrets/ca.crt}"
  local ca_args=()
  [[ -f "$ca" ]] && ca_args+=(--cacert "$ca")
  local status
  status="$(curl --silent --show-error --connect-timeout 5 --output /dev/null --write-out '%{http_code}' "${ca_args[@]}" "$endpoint" 2>/dev/null)" || {
    echo "INFRASTRUCTURE_FAILURE: Harbor unavailable at ${endpoint}" >&2
    return 2
  }
  case "$status" in
    2*|401|403|404) ;;
    *) echo "INFRASTRUCTURE_FAILURE: Harbor returned HTTP ${status} at ${endpoint}" >&2; return 2 ;;
  esac
}

registry_login() {
  : "${HARBOR_REGISTRY:?Set HARBOR_REGISTRY}"
  : "${HARBOR_USERNAME:?Set HARBOR_USERNAME}"
  : "${HARBOR_PASSWORD:?Set HARBOR_PASSWORD}"
  command -v curl >/dev/null || { echo 'TOOL_FAILURE: curl is required to classify Harbor availability' >&2; return 2; }
  registry_reachable
  if ! printf '%s\n' "$HARBOR_PASSWORD" | docker login "$HARBOR_REGISTRY" --username "$HARBOR_USERNAME" --password-stdin >/dev/null 2>&1; then
    echo 'AUTHENTICATION_FAILURE: Harbor authentication failed' >&2
    return 1
  fi
}

write_json_evidence() {
  local output="$1" result="$2" reference="$3" mode="$4" signer="$5" verified="$6"
  mkdir -p "$(dirname "$output")"
  export DEVSHIELD_EVIDENCE_OUTPUT="$output" DEVSHIELD_EVIDENCE_RESULT="$result" DEVSHIELD_EVIDENCE_REFERENCE="$reference" DEVSHIELD_EVIDENCE_MODE="$mode" DEVSHIELD_EVIDENCE_SIGNER="$signer" DEVSHIELD_EVIDENCE_VERIFIED="$verified" DEVSHIELD_COSIGN_VERSION="$COSIGN_VERSION" DEVSHIELD_COMMIT="${GITHUB_SHA:-$(git rev-parse HEAD 2>/dev/null || echo unknown)}"
  node <<'NODE'
const fs = require('fs');
const output = process.env.DEVSHIELD_EVIDENCE_OUTPUT;
const evidence = {
  schema_version: '1.0',
  repository: process.env.GITHUB_REPOSITORY || 'local',
  commit: process.env.DEVSHIELD_COMMIT,
  image_reference: process.env.DEVSHIELD_EVIDENCE_REFERENCE,
  digest: process.env.DEVSHIELD_EVIDENCE_REFERENCE.split('@')[1],
  signing_tool: 'Cosign',
  cosign_version: process.env.DEVSHIELD_COSIGN_VERSION,
  signing_mode: process.env.DEVSHIELD_EVIDENCE_MODE,
  signer_identity: process.env.DEVSHIELD_EVIDENCE_SIGNER,
  signature_status: process.env.DEVSHIELD_EVIDENCE_RESULT,
  verification_status: process.env.DEVSHIELD_EVIDENCE_VERIFIED === 'true' ? 'VERIFIED' : 'NOT_VERIFIED',
  verified: process.env.DEVSHIELD_EVIDENCE_VERIFIED === 'true',
  timestamp: new Date().toISOString(),
};
fs.writeFileSync(output, `${JSON.stringify(evidence, null, 2)}\n`);
NODE
}
