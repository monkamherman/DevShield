#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../../.." && pwd)"
waf="$repo_root/security/waf"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/devshield-waf.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT

expect_failure() {
  local label="$1"; shift
  set +e
  "$@" >"$tmp/${label}.out" 2>&1
  local status=$?
  set -e
  [[ "$status" -ne 0 ]] || { cat "$tmp/${label}.out"; echo "FAIL: ${label} unexpectedly succeeded" >&2; exit 1; }
  echo "PASS: ${label} rejected"
}

WAF_ENVIRONMENT=staging WAF_MODE=blocking TARGET_UPSTREAM=http://backend:3000 CRS_PARANOIA_LEVEL=1 ANOMALY_THRESHOLD=5 "$waf/validate-config.sh"
WAF_ENVIRONMENT=development WAF_MODE=detection TARGET_UPSTREAM=http://127.0.0.1:8080 "$waf/validate-config.sh"
expect_failure 'invalid-mode' env WAF_MODE=disabled TARGET_UPSTREAM=http://backend:3000 "$waf/validate-config.sh"
expect_failure 'missing-upstream' env WAF_MODE=blocking "$waf/validate-config.sh"
expect_failure 'invalid-upstream' env WAF_MODE=blocking TARGET_UPSTREAM=backend:3000 "$waf/validate-config.sh"
echo 'PASS: WAF configuration validation'

WAF_ENVIRONMENT=staging WAF_MODE=blocking "$waf/evidence.sh" --audit-log "$repo_root/tests/security/waf/fixtures/audit.jsonl" --output "$tmp/waf-events.json"
node - "$tmp/waf-events.json" <<'NODE'
const fs=require('fs'); const x=JSON.parse(fs.readFileSync(process.argv[2])); if(x.product!=='coraza' || x.crs_version!=='4.25.0' || x.summary.blocked!==1 || x.summary.allowed!==1) process.exit(1);
NODE
echo 'PASS: WAF security event evidence'

if ! docker info >/dev/null 2>&1; then
  echo 'WAF_TEST_FAILURE: Docker daemon unavailable; configuration/evidence tests passed but runtime integration is unvalidated' >&2
  exit 2
fi

network="devshield-waf-test-$$"
backend="devshield-waf-backend-$$"
waf_name="devshield-waf-$$"
image="devshield-waf-backend:$$"
cleanup_docker() { docker rm -f "$waf_name" "$backend" >/dev/null 2>&1 || true; docker network rm "$network" >/dev/null 2>&1 || true; docker image rm "$image" >/dev/null 2>&1 || true; }
trap 'cleanup_docker; rm -rf "$tmp"' EXIT
docker network create "$network" >/dev/null
docker build --quiet -t "$image" -f "$repo_root/apps/fixture/Dockerfile" "$repo_root" >/dev/null
docker run -d --rm --name "$backend" --network "$network" --network-alias backend "$image" >/dev/null
WAF_CONTAINER_NAME="$waf_name" WAF_NETWORK="$network" WAF_PORT=18081 WAF_ENVIRONMENT=staging "$waf/run.sh" --mode blocking --upstream http://backend:3000
for _ in {1..30}; do if curl --silent --fail http://127.0.0.1:18081/health >/dev/null; then break; fi; sleep 1; done
curl --silent --fail http://127.0.0.1:18081/health >/dev/null
normal_status="$(curl --silent --output /dev/null --write-out '%{http_code}' http://127.0.0.1:18081/health)"
sql_status="$(curl --silent --output /dev/null --write-out '%{http_code}' 'http://127.0.0.1:18081/?id=1%20AND%201=1')"
xss_status="$(curl --silent --output /dev/null --write-out '%{http_code}' 'http://127.0.0.1:18081/?q=%3Cscript%3Ealert(1)%3C%2Fscript%3E')"
[[ "$normal_status" == 200 && "$sql_status" == 403 && "$xss_status" == 403 ]] || { echo "FAIL: WAF blocking statuses normal=${normal_status} sql=${sql_status} xss=${xss_status}" >&2; exit 1; }
echo 'PASS: blocking mode normal request allowed and attack requests blocked'
docker logs "$waf_name" > "$tmp/live-audit.log" 2>&1 || true
WAF_ENVIRONMENT=staging WAF_MODE=blocking "$waf/evidence.sh" --audit-log "$tmp/live-audit.log" --output "$tmp/live-waf-events.json"
WAF_CONTAINER_NAME="$waf_name" docker rm -f "$waf_name" >/dev/null
WAF_CONTAINER_NAME=devshield-waf-detection-$$ WAF_NETWORK="$network" WAF_PORT=18082 WAF_ENVIRONMENT=staging "$waf/run.sh" --name "devshield-waf-detection-$$" --mode detection --upstream http://backend:3000
detection_status="$(curl --silent --output /dev/null --write-out '%{http_code}' 'http://127.0.0.1:18082/?id=1%20AND%201=1')"
[[ "$detection_status" == 200 ]] || { echo "FAIL: detection mode did not forward request (status=${detection_status})" >&2; exit 1; }
echo 'PASS: detection mode forwards the attack request and does not claim blocking'
echo 'WAF integration tests: PASS'
