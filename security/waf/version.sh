#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"
echo "WAF image: ${WAF_IMAGE}"
echo "Coraza connector: ${WAF_PRODUCT_VERSION}"
echo "OWASP CRS: ${WAF_CRS_VERSION}"
echo "Configuration hash: $(config_hash)"
