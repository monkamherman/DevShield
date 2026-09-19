#!/usr/bin/env bash
set -euo pipefail

test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT

if DEVSHIELD_REPORT_DIR="$test_dir/vulnerable" security/sast/semgrep/run.sh tests/security/fixtures/sast/vulnerable.js; then
  echo 'Expected Semgrep to reject the vulnerable fixture.'
  exit 1
else
  vulnerable_exit=$?
fi
[ "$vulnerable_exit" -eq 1 ]

DEVSHIELD_REPORT_DIR="$test_dir/safe" security/sast/semgrep/run.sh tests/security/fixtures/sast/safe.js
echo 'Semgrep positive and negative fixture tests: PASS'
