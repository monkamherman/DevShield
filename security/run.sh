#!/usr/bin/env bash
set -euo pipefail

security_sast_exit=0
security_secrets_exit=0
security_sca_exit=0
security_container_exit=0
security_sbom_exit=0

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

if make security-sca; then :; else security_sca_exit=$?; fi

if make security-container; then :; else security_container_exit=$?; fi

if make security-sbom; then :; else security_sbom_exit=$?; fi

if [ "$security_sast_exit" -eq 0 ] && [ "$security_secrets_exit" -eq 0 ] && [ "$security_sca_exit" -eq 0 ] && [ "$security_container_exit" -eq 0 ] && [ "$security_sbom_exit" -eq 0 ]; then
  echo 'Security gate: PASS'
  exit 0
fi

echo "Security gate: FAIL (Semgrep exit=$security_sast_exit, Gitleaks exit=$security_secrets_exit, Trivy SCA exit=$security_sca_exit, Container exit=$security_container_exit, SBOM exit=$security_sbom_exit)"
exit 1
