#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../../.." && pwd)"
deploy="$repo_root/deploy/deploy.sh"
rollback="$repo_root/deploy/rollback.sh"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/devshield-adapter.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT
bin="$tmp/bin"; mkdir -p "$bin"
a="sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
b="sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
state="$tmp/docker-state"
auth_a="$tmp/auth-a.json"
auth_b="$tmp/auth-b.json"
runtime="$tmp/runtime.env"

cat >"$bin/docker" <<'DOCKER'
#!/usr/bin/env bash
set -euo pipefail
cmd="${1:-}"; shift || true
case "$cmd" in
  info|pull|stop|rename|rm) exit 0 ;;
  image)
    shift; format=""; [[ "${1:-}" == --format ]] && { format="$2"; shift 2; }; image="${1:-}"
    if [[ "$format" == *Config.User* ]]; then echo node; else
      digest="${FAKE_ACTUAL_DIGEST:-${image##*@}}"
      echo "harbor.example.test/devshield/fixture@${digest}"
    fi
    ;;
  inspect)
    format=""; [[ "${1:-}" == --format ]] && { format="$2"; shift 2; }
    if [[ "$format" == *Config.Image* ]]; then echo "${FAKE_CURRENT_IMAGE:?}"; elif [[ "$format" == *State.Running* ]]; then echo true; fi
    ;;
  run) echo fake-container ;;
  *) echo "unsupported fake docker command: $cmd" >&2; exit 2 ;;
esac
DOCKER
cat >"$bin/curl" <<'CURL'
#!/usr/bin/env bash
set -euo pipefail
if [[ -f "${FAKE_CURL_FAIL_ONCE:-}" ]]; then rm -f "$FAKE_CURL_FAIL_ONCE"; exit 1; fi
if [[ "${FAKE_CURL_ALWAYS_FAIL:-0}" == 1 ]]; then exit 1; fi
exit 0
CURL
chmod +x "$bin/docker" "$bin/curl"

write_auth() {
  local digest="$1" file="$2"
  cat >"$file" <<EOF
{"schema_version":"1.0","artifact":{"reference":"harbor.example.test/devshield/fixture@$digest","digest":"$digest"},"environment":"production","policy":{"decision":"ALLOW"},"authorization":{"authorized":true,"status":"AUTHORIZED"}}
EOF
}
write_auth "$a" "$auth_a"
write_auth "$b" "$auth_b"
cat >"$runtime" <<EOF
HARBOR_REGISTRY=harbor.example.test
HARBOR_PROJECT=devshield
HARBOR_REPOSITORY=fixture
EXPECTED_DIGEST=$a
CONTAINER_NAME=devshield-test
CONTAINER_PORT=3000
HOST_PORT=33000
HEALTHCHECK_URL=http://127.0.0.1:33000/health
HEALTHCHECK_TIMEOUT=1
HEALTHCHECK_RETRIES=1
DEPLOYMENT_ENVIRONMENT=production
ROLLBACK_ENABLED=1
DEVSHIELD_DEPLOYMENT_STATE_FILE=$tmp/state.json
DEVSHIELD_DEPLOYMENT_AUTHORIZATION=$auth_a
HARBOR_PASSWORD=synthetic-secret
EOF
base=(DEVSHIELD_RUNTIME_ENV_FILE="$runtime" DEVSHIELD_DOCKER_BIN="$bin/docker" DEVSHIELD_CURL_BIN="$bin/curl" FAKE_CURRENT_IMAGE="harbor.example.test/devshield/fixture@$a" PATH="$bin:$PATH")

env "${base[@]}" "$deploy" >"$tmp/first.out" 2>&1 || { cat "$tmp/first.out" >&2; exit 1; }
grep -q '"status": "success"' "$tmp/state.json"
! grep -q synthetic-secret "$tmp/state.json"
echo 'PASS: valid digest deployment and secret-safe state'

set +e
env "${base[@]}" EXPECTED_DIGEST= "$deploy" >"$tmp/missing.out" 2>&1; code=$?
set -e
[[ "$code" -ne 0 ]] && grep -q DEPLOYMENT_DENIED "$tmp/missing.out"
echo 'PASS: missing digest denied'

set +e
env "${base[@]}" HARBOR_REPOSITORY=fixture:latest "$deploy" >"$tmp/tag.out" 2>&1; code=$?
set -e
[[ "$code" -ne 0 ]] && grep -q DEPLOYMENT_DENIED "$tmp/tag.out"
echo 'PASS: mutable tag denied'

set +e
env "${base[@]}" FAKE_ACTUAL_DIGEST="$b" "$deploy" >"$tmp/mismatch.out" 2>&1; code=$?
set -e
[[ "$code" -ne 0 ]] && grep -q 'differs from EXPECTED_DIGEST' "$tmp/mismatch.out"
echo 'PASS: digest mismatch denied'

cat >"$tmp/denied.json" <<EOF
{"schema_version":"1.0","artifact":{"reference":"harbor.example.test/devshield/fixture@$a","digest":"$a"},"environment":"production","policy":{"decision":"DENY"},"authorization":{"authorized":false,"status":"BLOCKED"}}
EOF
set +e
env "${base[@]}" DEVSHIELD_DEPLOYMENT_AUTHORIZATION="$tmp/denied.json" "$deploy" >"$tmp/deny.out" 2>&1; code=$?
set -e
[[ "$code" -ne 0 ]] && grep -q DEPLOYMENT_DENIED "$tmp/deny.out"
echo 'PASS: authorization DENY prevents deployment'

cat >"$runtime" <<EOF
HARBOR_REGISTRY=harbor.example.test
HARBOR_PROJECT=devshield
HARBOR_REPOSITORY=fixture
EXPECTED_DIGEST=$b
CONTAINER_NAME=devshield-test
CONTAINER_PORT=3000
HOST_PORT=33000
HEALTHCHECK_URL=http://127.0.0.1:33000/health
HEALTHCHECK_TIMEOUT=1
HEALTHCHECK_RETRIES=1
DEPLOYMENT_ENVIRONMENT=production
ROLLBACK_ENABLED=1
DEVSHIELD_DEPLOYMENT_STATE_FILE=$tmp/state.json
DEVSHIELD_DEPLOYMENT_AUTHORIZATION=$auth_b
EOF
touch "$tmp/fail-once"
set +e
env "${base[@]}" FAKE_CURL_FAIL_ONCE="$tmp/fail-once" "$deploy" >"$tmp/second.out" 2>&1; code=$?
set -e
[[ "$code" -eq 3 ]] && grep -q 'DEPLOYMENT_FAILURE: healthcheck failed' "$tmp/second.out"
grep -q '"status": "rollback_success"' "$tmp/state.json"
echo 'PASS: healthcheck failure rolls back previous digest'

set +e
env "${base[@]}" FAKE_CURL_ALWAYS_FAIL=1 "$rollback" --state-file "$tmp/state.json" >"$tmp/rollback.out" 2>&1; code=$?
set -e
[[ "$code" -eq 5 ]] && grep -q ROLLBACK_FAILED "$tmp/rollback.out"
echo 'PASS: rollback failure is explicit'
echo 'Deployment adapter tests: PASS'
