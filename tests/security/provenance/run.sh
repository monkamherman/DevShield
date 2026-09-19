#!/usr/bin/env bash
set -euo pipefail

root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$root"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

digest="sha256:$(printf 'a%.0s' {1..64})"
commit="4f9c7b209b11c6e823eb62ebade15a274d1870dc"
cat > "$tmp/build.json" <<JSON
{"repository":"org/devshield","commit":"$commit","workflow":"DevShield Security","workflow_run":"123","image":"devshield:ci","image_digest":"$digest"}
JSON
cat > "$tmp/inventory.json" <<JSON
{"result":"PASS","artifact":{"digest":"$digest"},"source":{"commit":"$commit"},"sbom":{"format":"CycloneDX JSON","digest":"$digest"}}
JSON
cat > "$tmp/registry.json" <<JSON
{"result":"PASS","registry":"harbor.example.test","repository":"devshield/fixture","image_reference":"harbor.example.test/devshield/fixture@$digest","digest":"$digest","tag":"sha-$commit"}
JSON

GITHUB_REPOSITORY=org/devshield GITHUB_WORKFLOW='DevShield Security' GITHUB_RUN_ID=123 \
  security/provenance/generate.sh --output "$tmp/provenance.json" --predicate "$tmp/predicate.json" \
  --build-metadata "$tmp/build.json" --inventory "$tmp/inventory.json" --registry-evidence "$tmp/registry.json"

node - "$tmp/provenance.json" "$tmp/predicate.json" "$digest" "$commit" <<'NODE'
const fs=require('fs');
const [evidenceFile,predicateFile,digest,commit]=process.argv.slice(2);
const evidence=JSON.parse(fs.readFileSync(evidenceFile));
const statement=JSON.parse(fs.readFileSync(predicateFile));
if (!evidence.present || evidence.trusted || evidence.verification !== 'NOT_VERIFIED' || evidence.digest !== digest || evidence.source_commit !== commit) process.exit(1);
if (statement.subject[0].digest.sha256 !== digest.slice(7) || statement.predicate.artifact.digest !== digest) process.exit(1);
NODE

bad_digest="sha256:$(printf 'b%.0s' {1..64})"
if sed "s/$digest/$bad_digest/" "$tmp/registry.json" > "$tmp/bad-registry.json" && \
  security/provenance/generate.sh --output "$tmp/bad.json" --predicate "$tmp/bad-predicate.json" \
    --build-metadata "$tmp/build.json" --inventory "$tmp/inventory.json" --registry-evidence "$tmp/bad-registry.json"; then
  echo 'Expected inconsistent digest provenance generation to fail.' >&2
  exit 1
fi

fake="$tmp/bin"
mkdir -p "$fake" "$tmp/home/.docker"
printf '%s\n' '{}' > "$tmp/home/.docker/config.json"
cat > "$fake/curl" <<'CURL'
#!/usr/bin/env bash
printf '200'
CURL
cat > "$fake/docker" <<'DOCKER'
#!/usr/bin/env bash
set -euo pipefail
if [[ " $* " == *" version "* && " $* " != *" verify-attestation "* ]]; then
  echo 'v3.1.3'
  exit 0
fi
if [[ " $* " == *" verify-attestation "* ]]; then
  ref='harbor.example.test/devshield/fixture@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
  digest="${ref##*@}"
  payload=$(node -e 'const d=process.argv[1]; const x={_type:"https://in-toto.io/Statement/v1",subject:[{name:"harbor.example.test/devshield/fixture",digest:{sha256:d.slice(7)}}],predicateType:"https://devshield.dev/provenance/v1",predicate:{source:{repository:"org/devshield",commit:"4f9c7b209b11c6e823eb62ebade15a274d1870dc"},workflow:{name:"DevShield Security",run_id:"123"},artifact:{digest:d},sbom:{format:"CycloneDX JSON",digest:d}}}; process.stdout.write(Buffer.from(JSON.stringify(x)).toString("base64"))' "$digest")
  printf '[{"payload":"%s"}]\n' "$payload"
  exit 0
fi
exit 0
DOCKER
chmod +x "$fake/curl" "$fake/docker"

PATH="$fake:$PATH" HOME="$tmp/home" HARBOR_REGISTRY=harbor.example.test HARBOR_URL=https://harbor.example.test \
  COSIGN_CERTIFICATE_IDENTITY=https://github.com/org/devshield/.github/workflows/security.yml@refs/heads/main \
  DEVSHIELD_VERIFY_ONLY=1 security/provenance/verify.sh --artifact "harbor.example.test/devshield/fixture@$digest" \
  --expected-commit "$commit" --expected-sbom-digest "$digest" --output "$tmp/verified.json"

node - "$tmp/verified.json" "$digest" "$commit" <<'NODE'
const fs=require('fs'); const [file,digest,commit]=process.argv.slice(2); const x=JSON.parse(fs.readFileSync(file));
if (x.verification !== 'VERIFIED' || !x.trusted || x.digest !== digest || x.source_commit !== commit) process.exit(1);
NODE

echo 'Provenance positive and negative tests: PASS'
