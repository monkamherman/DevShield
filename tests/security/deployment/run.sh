#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../../.." && pwd)"
fixture="$repo_root/tests/security/fixtures/policy/valid-production.json"
critical="$repo_root/tests/security/fixtures/policy/critical.json"
authorize="$repo_root/security/deployment/authorize.sh"
validate="$repo_root/security/deployment/validate-evidence.sh"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/devshield-deployment.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT

reference="$(node -e 'const x=require(process.argv[1]); process.stdout.write(x.artifact.reference)' "$fixture")"
expect_blocked() {
  local label="$1"; shift
  set +e
  "$@" >"$tmp/${label}.out" 2>&1
  local status=$?
  set -e
  [[ "$status" -ne 0 ]] || { cat "$tmp/${label}.out"; echo "FAIL: ${label} unexpectedly authorized" >&2; exit 1; }
  echo "PASS: ${label} (blocked)"
}

"$authorize" --artifact "$reference" --environment production --policy-input "$fixture" --output "$tmp/authorized.json"
"$validate" --evidence "$tmp/authorized.json" --artifact "$reference" --environment production
node -e 'const x=require(process.argv[1]); if(!x.authorization.authorized || x.policy.decision!=="ALLOW") process.exit(1)' "$tmp/authorized.json"
echo 'PASS: valid signed artifact is authorized'

expect_blocked 'critical-vulnerability' "$authorize" --artifact "$reference" --environment production --policy-input "$critical" --output "$tmp/critical.json"
expect_blocked 'wrong-digest' "$authorize" --artifact "${reference%?}b" --environment production --policy-input "$fixture" --output "$tmp/wrong-digest.json"
expect_blocked 'mutable-tag' "$authorize" --artifact "harbor.example.test/devshield/fixture:production" --environment production --policy-input "$fixture" --output "$tmp/mutable.json"

node - "$fixture" "$tmp/untrusted.json" <<'NODE'
const fs=require('fs'); const x=JSON.parse(fs.readFileSync(process.argv[2])); x.registry.trusted=false; fs.writeFileSync(process.argv[3], JSON.stringify(x));
NODE
expect_blocked 'untrusted-registry' "$authorize" --artifact "$reference" --environment production --policy-input "$tmp/untrusted.json" --output "$tmp/untrusted-evidence.json"

node - "$fixture" "$tmp/missing-sbom.json" <<'NODE'
const fs=require('fs'); const x=JSON.parse(fs.readFileSync(process.argv[2])); x.sbom.present=false; fs.writeFileSync(process.argv[3], JSON.stringify(x));
NODE
expect_blocked 'missing-sbom' "$authorize" --artifact "$reference" --environment production --policy-input "$tmp/missing-sbom.json" --output "$tmp/missing-sbom-evidence.json"

node - "$fixture" "$tmp/missing-signature.json" <<'NODE'
const fs=require('fs'); const x=JSON.parse(fs.readFileSync(process.argv[2])); x.signature.verified=false; fs.writeFileSync(process.argv[3], JSON.stringify(x));
NODE
expect_blocked 'missing-verification' "$authorize" --artifact "$reference" --environment production --policy-input "$tmp/missing-signature.json" --output "$tmp/missing-signature-evidence.json"

node - "$fixture" "$tmp/wrong-signer.json" <<'NODE'
const fs=require('fs'); const x=JSON.parse(fs.readFileSync(process.argv[2])); x.signature.signer='oidc:untrusted'; fs.writeFileSync(process.argv[3], JSON.stringify(x));
NODE
expect_blocked 'wrong-signer' "$authorize" --artifact "$reference" --environment production --policy-input "$tmp/wrong-signer.json" --output "$tmp/wrong-signer-evidence.json"

node - "$fixture" "$tmp/invalid-provenance.json" <<'NODE'
const fs=require('fs'); const x=JSON.parse(fs.readFileSync(process.argv[2])); x.provenance.source_commit='tampered'; fs.writeFileSync(process.argv[3], JSON.stringify(x));
NODE
expect_blocked 'invalid-provenance' "$authorize" --artifact "$reference" --environment production --policy-input "$tmp/invalid-provenance.json" --output "$tmp/invalid-provenance-evidence.json"

node - "$tmp/authorized.json" <<'NODE'
const fs=require('fs'); const file=process.argv[2]; const x=JSON.parse(fs.readFileSync(file)); x.artifact.digest='sha256:'+'b'.repeat(64); fs.writeFileSync(file, JSON.stringify(x));
NODE
expect_blocked 'tampered-authorization' "$validate" --evidence "$tmp/authorized.json" --artifact "$reference" --environment production

set +e
DEVSHIELD_OPA_BIN="$tmp/missing-opa" "$authorize" --artifact "$reference" --environment production --policy-input "$fixture" --output "$tmp/opa-failure.json" >"$tmp/opa-failure.out" 2>&1
opa_status=$?
set -e
[[ "$opa_status" -eq 2 ]] || { cat "$tmp/opa-failure.out"; echo 'FAIL: OPA failure did not return tool failure' >&2; exit 1; }
echo 'PASS: OPA unavailable blocks with TOOL_FAILURE'

echo 'Deployment authorization tests: PASS'
