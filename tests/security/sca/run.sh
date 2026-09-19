#!/usr/bin/env bash
set -euo pipefail
report_dir=".tmp-sca-test-$$"
trap 'rm -rf "$report_dir"' EXIT
if DEVSHIELD_REPORT_DIR="$report_dir/vulnerable" security/sca/trivy/run.sh tests/security/fixtures/sca/vulnerable; then echo 'Expected vulnerable fixture to fail.' >&2; exit 1; fi
grep -q SECURITY_FAILURE "$report_dir/vulnerable/trivy-sca-metadata.json"
DEVSHIELD_REPORT_DIR="$report_dir/clean" security/sca/trivy/run.sh tests/security/fixtures/sca/clean
grep -q '"result": "PASS"' "$report_dir/clean/trivy-sca-metadata.json"
echo 'Trivy SCA fixture tests: PASS'
