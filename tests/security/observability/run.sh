#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../../.." && pwd)"
logger="$repo_root/security/observability/logger.sh"
validator="$repo_root/security/observability/validate-event.sh"
validate="$repo_root/security/observability/validate.sh"
health="$repo_root/security/observability/healthcheck.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
log="$tmp/security-events.jsonl"
digest="sha256:0000000000000000000000000000000000000000000000000000000000000000"

"$validate" >/dev/null
cat >"$tmp/valid.json" <<EOF
{"schema_version":"1.0","event_id":"event-valid","timestamp":"2026-09-18T10:20:30Z","event_type":"security.scan.completed","severity":"INFO","component":"trivy","environment":"ci","status":"PASS","source":{"repository":"example/repository","commit":"abcdef123456"},"pipeline":{"pipeline_id":"pipeline-123","build_id":"build-456"},"artifact":{"repository":"harbor.example.com/devshield/app","digest":"$digest"},"security":{"finding_count":0},"metadata":{"command":"curl -H 'Authorization: Bearer super-secret-value'"}}
EOF
"$validator" "$tmp/valid.json" | grep -qx EVENT_VALID
DEVSHIELD_LOG_FILE="$log" "$logger" --event-json "$tmp/valid.json" | grep -q EVENT_VALID

cat >"$tmp/deny.json" <<EOF
{"schema_version":"1.0","event_id":"event-deny","timestamp":"2026-09-18T10:21:30Z","event_type":"security.policy.deny","severity":"ERROR","component":"opa","environment":"production","status":"DENY","reason":"critical vulnerability","source":{"commit":"abcdef123456"},"artifact":{"digest":"$digest"},"pipeline":{"pipeline_id":"pipeline-123"}}
EOF
cat >"$tmp/waf.json" <<EOF
{"schema_version":"1.0","event_id":"event-waf","timestamp":"2026-09-18T10:22:30Z","event_type":"waf.request.blocked","severity":"WARNING","component":"coraza","environment":"staging","status":"BLOCKED","artifact":{"digest":"$digest"},"metadata":{"rule":"941160","path":"/search"}}
EOF
cat >"$tmp/falco.json" <<EOF
{"schema_version":"1.0","event_id":"event-falco","timestamp":"2026-09-18T10:23:30Z","event_type":"runtime.alert","severity":"WARNING","component":"falco","environment":"staging","status":"DETECTED","artifact":{"digest":"$digest"},"metadata":{"container_name":"app","rule":"DevShield Shell in Container"}}
EOF
cat >"$tmp/deploy.json" <<EOF
{"schema_version":"1.0","event_id":"event-deploy","timestamp":"2026-09-18T10:24:30Z","event_type":"deployment.authorization.denied","severity":"ERROR","component":"deployment-authorization","environment":"production","status":"DENY","reason":"OPA policy denied artifact","source":{"commit":"abcdef123456"},"artifact":{"digest":"$digest"},"deployment":{"deployment_id":"deployment-17","environment":"production"}}
EOF
for event in deny waf falco deploy; do DEVSHIELD_LOG_FILE="$log" "$logger" --event-json "$tmp/$event.json" >/dev/null; done

node - "$log" "$digest" <<'NODE'
const fs=require('fs');
const [file,digest]=process.argv.slice(2);
const events=fs.readFileSync(file,'utf8').trim().split(/\n/).map(JSON.parse);
if(events.length!==5) throw new Error(`expected 5 events, got ${events.length}`);
if(new Set(events.map(e=>e.event_id)).size!==5) throw new Error('event_id values are not unique');
if(events.filter(e=>e.artifact?.digest===digest).length!==5) throw new Error('digest correlation failed');
if(fs.readFileSync(file,'utf8').includes('super-secret-value')) throw new Error('secret leaked');
if(!events.some(e=>e.event_type==='runtime.alert')||!events.some(e=>e.event_type==='waf.request.blocked')) throw new Error('runtime/WAF events missing');
console.log('OBSERVABILITY_CORRELATION_PASS');
NODE

cat >"$tmp/missing.json" <<'EOF'
{"schema_version":"1.0","event_id":"missing-type","timestamp":"2026-09-18T10:20:30Z","severity":"INFO","component":"trivy","environment":"ci","status":"PASS"}
EOF
if "$validator" "$tmp/missing.json" >/dev/null 2>&1; then echo 'missing event_type was accepted' >&2; exit 1; fi
cat >"$tmp/bad-digest.json" <<'EOF'
{"schema_version":"1.0","event_id":"bad-digest","timestamp":"2026-09-18T10:20:30Z","event_type":"artifact.signed","severity":"INFO","component":"cosign","environment":"ci","status":"PASS","artifact":{"digest":"sha256:AAA"}}
EOF
if "$validator" "$tmp/bad-digest.json" >/dev/null 2>&1; then echo 'bad digest was accepted' >&2; exit 1; fi
cat >"$tmp/bad-severity.json" <<'EOF'
{"schema_version":"1.0","event_id":"bad-severity","timestamp":"2026-09-18T10:20:30Z","event_type":"security.scan.completed","severity":"UNKNOWN_LEVEL","component":"trivy","environment":"ci","status":"PASS"}
EOF
if "$validator" "$tmp/bad-severity.json" >/dev/null 2>&1; then echo 'bad severity was accepted' >&2; exit 1; fi
cat >"$tmp/bad-json.json" <<'EOF'
{"schema_version":"1.0"
EOF
if "$validator" "$tmp/bad-json.json" >/dev/null 2>&1; then echo 'invalid JSON was accepted' >&2; exit 1; fi

if DEVSHIELD_LOG_FILE="$tmp/no-parent/security-events.jsonl" "$logger" --event-json "$tmp/valid.json" >/dev/null 2>&1; then
  : # A writable missing parent is expected to be created.
else
  echo 'writable local log creation failed' >&2; exit 1
fi
touch "$tmp/not-a-directory"
if DEVSHIELD_LOG_FILE="$tmp/not-a-directory/security-events.jsonl" "$logger" --event-json "$tmp/valid.json" >/dev/null 2>&1; then
  echo 'unwritable local logging unexpectedly succeeded' >&2; exit 1
fi
DEVSHIELD_LOG_FILE="$tmp/concurrent.jsonl" "$logger" --event-json "$tmp/valid.json" >/dev/null 2>&1 &
p1=$!
DEVSHIELD_LOG_FILE="$tmp/concurrent.jsonl" "$logger" --event-json "$tmp/deny.json" >/dev/null 2>&1 &
p2=$!
wait "$p1" "$p2"
[[ "$(wc -l < "$tmp/concurrent.jsonl")" -eq 2 ]] || { echo 'concurrent JSONL writes failed' >&2; exit 1; }
DEVSHIELD_LOG_DIR="$tmp" "$health" >/dev/null
echo 'Observability tests: PASS'
