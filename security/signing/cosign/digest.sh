#!/usr/bin/env bash
set -euo pipefail
root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
evidence="${DEVSHIELD_REGISTRY_EVIDENCE:-$root/reports/registry-push-evidence.json}"
[[ -s "$evidence" ]] || { echo "TOOL_FAILURE: missing registry evidence ${evidence}" >&2; exit 2; }
export DEVSHIELD_REGISTRY_EVIDENCE_FILE="$evidence"
node <<'NODE'
const fs = require('fs');
const x = JSON.parse(fs.readFileSync(process.env.DEVSHIELD_REGISTRY_EVIDENCE_FILE, 'utf8'));
if (x.result !== 'PASS' || !x.registry || !x.repository || !/^sha256:[0-9a-f]{64}$/.test(x.digest || '')) {
  console.error('TOOL_FAILURE: registry evidence does not contain a verified digest');
  process.exit(2);
}
process.stdout.write(`${x.registry}/${x.repository}@${x.digest}\n`);
NODE
