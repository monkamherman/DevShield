#!/usr/bin/env bash
set -euo pipefail

security_sast_exit=0
security_secrets_exit=0

if make security-sast; then
  :
else
  security_sast_exit=$?
fi

if make security-secrets; then
  :
else
  security_secrets_exit=$?
fi

if [ "$security_sast_exit" -eq 0 ] && [ "$security_secrets_exit" -eq 0 ]; then
  echo 'Security gate: PASS'
  exit 0
fi

echo "Security gate: FAIL (Semgrep exit=$security_sast_exit, Gitleaks exit=$security_secrets_exit)"
exit 1
