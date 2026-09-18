#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"
if mkdir -p "$OBSERVABILITY_LOG_DIR" 2>/dev/null && [[ -d "$OBSERVABILITY_LOG_DIR" && -w "$OBSERVABILITY_LOG_DIR" ]]; then
  echo "OBSERVABILITY_HEALTHY: LOCAL_LOGGING=HEALTHY EXTERNAL_EXPORT=NOT_CONFIGURED"
else
  echo "OBSERVABILITY_FAILURE: local log directory is unavailable: $OBSERVABILITY_LOG_DIR" >&2
  exit 5
fi
