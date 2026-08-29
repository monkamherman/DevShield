#!/usr/bin/env bash
set -euo pipefail

test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT

if DEVSHIELD_REPORT_DIR="$test_dir/fake-secret" security/secrets/gitleaks/run.sh tests/security/fixtures/secrets/fake-secret.env; then
  echo 'Expected Gitleaks to reject the fake-secret fixture.'
  exit 1
else
  fake_secret_exit=$?
fi
[ "$fake_secret_exit" -eq 1 ]

DEVSHIELD_REPORT_DIR="$test_dir/clean" security/secrets/gitleaks/run.sh security/secrets/gitleaks/README.md
echo 'Gitleaks positive and negative fixture tests: PASS'
