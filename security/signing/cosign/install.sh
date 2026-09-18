#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"
require_cosign_version
echo "Cosign installation strategy: PASS (${COSIGN_IMAGE})"
