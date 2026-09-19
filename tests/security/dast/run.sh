#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../../.." && pwd)"
dast="$repo_root/security/dast/run.sh"
validate_evidence="$repo_root/security/dast/validate-evidence.sh"
fixture_dir="$repo_root/tests/security/dast/fixtures"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/devshield-dast.XXXXXX")"
server_pid=""
cleanup() { [[ -n "$server_pid" ]] && kill "$server_pid" 2>/dev/null || true; rm -rf "$tmp"; }
trap cleanup EXIT

node "$fixture_dir/server.js" 18080 >"$tmp/server.log" 2>&1 &
server_pid=$!

expect_code() {
  local label="$1" expected="$2"; shift 2
  set +e
  "$@" >"$tmp/${label}.out" 2>&1
  local actual=$?
  set -e
  [[ "$actual" -eq "$expected" ]] || { cat "$tmp/${label}.out"; echo "FAIL: ${label} expected ${expected}, got ${actual}" >&2; exit 1; }
  echo "PASS: ${label} (exit ${actual})"
}

clean_dir="$tmp/clean"
DEVSHIELD_DAST_TEST_MODE=1 DEVSHIELD_CURL_BIN="$fixture_dir/curl-reachable.sh" DEVSHIELD_ZAP_BIN="$fixture_dir/zap-clean.sh" "$dast" --target http://127.0.0.1:18080 --environment staging --output-dir "$clean_dir"
"$validate_evidence" --evidence "$clean_dir/dast-evidence.json"
echo 'PASS: clean baseline produces valid evidence'

high_dir="$tmp/high"
expect_code 'high-finding' 1 env DEVSHIELD_DAST_TEST_MODE=1 DEVSHIELD_CURL_BIN="$fixture_dir/curl-reachable.sh" DEVSHIELD_ZAP_BIN="$fixture_dir/zap-high.sh" "$dast" --target http://127.0.0.1:18080 --environment staging --output-dir "$high_dir"
"$validate_evidence" --evidence "$high_dir/dast-evidence.json"
echo 'PASS: high finding is SECURITY_FAILURE'

expect_code 'unreachable-target' 3 env DEVSHIELD_ZAP_BIN="$fixture_dir/zap-clean.sh" "$dast" --target http://127.0.0.1:59999 --environment staging --output-dir "$tmp/unreachable"
expect_code 'malformed-target' 4 "$dast" --target not-a-url --environment staging --output-dir "$tmp/malformed"
expect_code 'external-target-blocked' 4 "$dast" --target https://example.com --environment staging --output-dir "$tmp/external"
expect_code 'scanner-unavailable' 2 env DEVSHIELD_DAST_TEST_MODE=1 DEVSHIELD_CURL_BIN="$fixture_dir/curl-reachable.sh" DEVSHIELD_ZAP_BIN="$tmp/missing-zap" "$dast" --target http://127.0.0.1:18080 --environment staging --output-dir "$tmp/tool-failure"
expect_code 'report-missing' 2 env DEVSHIELD_DAST_TEST_MODE=1 DEVSHIELD_CURL_BIN="$fixture_dir/curl-reachable.sh" DEVSHIELD_ZAP_BIN="$fixture_dir/zap-missing-report.sh" "$dast" --target http://127.0.0.1:18080 --environment staging --output-dir "$tmp/missing-report"

node - "$clean_dir/dast-evidence.json" <<'NODE'
const fs=require('fs'); const file=process.argv[2]; const x=JSON.parse(fs.readFileSync(file)); x.findings.high=1; fs.writeFileSync(file, JSON.stringify(x));
NODE
expect_code 'tampered-evidence' 5 "$validate_evidence" --evidence "$clean_dir/dast-evidence.json"

echo 'DAST tests: PASS'
