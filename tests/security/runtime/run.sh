#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../../.." && pwd)"
runtime="$repo_root/security/runtime"
fixtures="$repo_root/tests/security/runtime/fixtures"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/devshield-runtime.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT

"$runtime/validate.sh"
"$runtime/version.sh"

DEVSHIELD_RUNTIME_ENVIRONMENT=development "$runtime/evidence.sh" --input "$fixtures/benign.jsonl" --output "$tmp/benign.json"
node - "$tmp/benign.json" <<'NODE'
const fs=require('fs'); const x=JSON.parse(fs.readFileSync(process.argv[2])); if(x.summary.total!==0 || x.status!=='DETECTED_EVENTS') process.exit(1);
NODE
echo 'PASS: benign runtime produces no events'

DEVSHIELD_RUNTIME_ENVIRONMENT=staging "$runtime/evidence.sh" --input "$fixtures/suspicious.jsonl" --output "$tmp/suspicious.json"
node - "$tmp/suspicious.json" <<'NODE'
const fs=require('fs'); const x=JSON.parse(fs.readFileSync(process.argv[2])); if(x.summary.total!==4 || x.summary.severity.WARNING!==3 || x.summary.severity.ERROR!==1) process.exit(1); if(x.events[1].container.digest!=='sha256:'+'a'.repeat(64)) process.exit(1); if(x.events.some(e=>e.container.digest==='invented')) process.exit(1);
NODE
echo 'PASS: suspicious runtime events normalized with container context'

missing_rules="$tmp/missing-rules.yaml"
if DEVSHIELD_RUNTIME_RULES_FILE="$missing_rules" "$runtime/validate.sh" >"$tmp/missing-rules.out" 2>&1; then
  cat "$tmp/missing-rules.out"; echo 'FAIL: missing rules were accepted' >&2; exit 1
else
  grep -Fq RUNTIME_SECURITY_RULE_FAILURE "$tmp/missing-rules.out"
  echo 'PASS: missing rules fail visibly'
fi

if DEVSHIELD_DOCKER_BIN="$tmp/missing-docker" "$runtime/run.sh" >"$tmp/falco-unavailable.out" 2>&1; then
  cat "$tmp/falco-unavailable.out"; echo 'FAIL: Falco unavailable was accepted' >&2; exit 1
else
  grep -Fq RUNTIME_SECURITY_STARTUP_FAILURE "$tmp/falco-unavailable.out"
  echo 'PASS: Falco/Docker unavailable fails visibly'
fi

if ! docker info >/dev/null 2>&1; then
  echo 'Runtime integration tests: BLOCKED (Docker daemon unavailable; static rules/evidence tests passed)' >&2
  exit 2
fi

echo 'Runtime integration tests require a host with Falco Modern eBPF support and are not run by this fixture-only path.'
