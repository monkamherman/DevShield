#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"
observability_node
[[ -s "$(dirname "$0")/schema.json" ]] || { echo 'OBSERVABILITY_CONFIG_FAILURE: schema.json is missing' >&2; exit 2; }
node -e 'JSON.parse(require("fs").readFileSync(process.argv[1], "utf8")); console.log("OBSERVABILITY_CONFIG_VALID")' "$(dirname "$0")/schema.json"

