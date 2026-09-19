#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"
echo "Falco image: ${FALCO_IMAGE}"
echo "Falco version: ${FALCO_VERSION}"
echo "Driver/backend: ${FALCO_DRIVER}"
echo "DevShield rules version: ${DEVSHIELD_RULES_VERSION}"
echo "Rules hash: $(rules_hash)"
echo "Configuration hash: $(config_hash)"
