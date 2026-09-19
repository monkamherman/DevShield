#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/../signing/cosign/common.sh"

reference=""
output="${DEVSHIELD_PROVENANCE_OUTPUT:-$repo_root/reports/provenance.json}"
expected_commit="${DEVSHIELD_EXPECTED_COMMIT:-}"
expected_sbom_digest="${DEVSHIELD_EXPECTED_SBOM_DIGEST:-}"
predicate_type="${DEVSHIELD_PROVENANCE_PREDICATE_TYPE:-https://devshield.dev/provenance/v1}"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --artifact) reference="$2"; shift 2 ;;
    --output) output="$2"; shift 2 ;;
    --expected-commit) expected_commit="$2"; shift 2 ;;
    --expected-sbom-digest) expected_sbom_digest="$2"; shift 2 ;;
    *) echo "TOOL_FAILURE: unknown provenance verification option $1" >&2; exit 2 ;;
  esac
done
[[ -n "$reference" ]] || { echo 'TOOL_FAILURE: --artifact is required' >&2; exit 2; }
validate_digest_reference "$reference"
validate_approved_registry "$reference"
require_cosign_version
export DEVSHIELD_VERIFY_ONLY=1
registry_login

identity="${COSIGN_CERTIFICATE_IDENTITY:?Set COSIGN_CERTIFICATE_IDENTITY for keyless verification}"
issuer="${COSIGN_CERTIFICATE_OIDC_ISSUER:-https://token.actions.githubusercontent.com}"
raw="$(mktemp "${TMPDIR:-/tmp}/devshield-provenance.XXXXXX.json")"
trap 'rm -f "$raw"' EXIT
if ! cosign_run verify-attestation --type "$predicate_type" --certificate-identity "$identity" --certificate-oidc-issuer "$issuer" --output=json "$reference" >"$raw" 2>/dev/null; then
  echo 'VERIFICATION_FAILURE: Cosign provenance attestation is missing, invalid or bound to another digest' >&2
  exit 1
fi

export DEVSHIELD_PROVENANCE_RAW="$raw" DEVSHIELD_PROVENANCE_OUTPUT="$output" \
  DEVSHIELD_PROVENANCE_REFERENCE="$reference" DEVSHIELD_PROVENANCE_EXPECTED_COMMIT="$expected_commit" \
  DEVSHIELD_PROVENANCE_EXPECTED_SBOM_DIGEST="$expected_sbom_digest" DEVSHIELD_PROVENANCE_SIGNER="$identity" \
  DEVSHIELD_PROVENANCE_PREDICATE_TYPE="$predicate_type"
node <<'NODE'
const fs = require('fs');
const path = require('path');
const reference = process.env.DEVSHIELD_PROVENANCE_REFERENCE;
const digest = reference.slice(reference.indexOf('@') + 1);
const expectedCommit = process.env.DEVSHIELD_PROVENANCE_EXPECTED_COMMIT;
const expectedSbomDigest = process.env.DEVSHIELD_PROVENANCE_EXPECTED_SBOM_DIGEST;
const raw = JSON.parse(fs.readFileSync(process.env.DEVSHIELD_PROVENANCE_RAW, 'utf8'));
const entries = Array.isArray(raw) ? raw : [raw];
let statement;
for (const entry of entries) {
  try {
    const payload = JSON.parse(Buffer.from(entry.payload, 'base64').toString('utf8'));
    if (payload.predicateType === process.env.DEVSHIELD_PROVENANCE_PREDICATE_TYPE) { statement = payload; break; }
  } catch (_) {}
}
const subject = statement?.subject?.find(x => x.digest?.sha256 === digest.slice('sha256:'.length));
const predicate = statement?.predicate;
const commit = predicate?.source?.commit;
const artifactDigest = predicate?.artifact?.digest;
const sbomDigest = predicate?.sbom?.digest;
if (!subject || artifactDigest !== digest || !commit || !/^[0-9a-f]{40}$/.test(commit)) throw new Error('attested provenance is not bound to the requested digest');
if (expectedCommit && commit !== expectedCommit) throw new Error('attested provenance commit does not match the expected commit');
if (expectedSbomDigest && sbomDigest !== expectedSbomDigest) throw new Error('attested provenance SBOM digest does not match the expected digest');
const evidence = {
  schema_version: '1.0', present: true, trusted: true,
  source_repository: predicate.source.repository, source_commit: commit,
  workflow: predicate.workflow?.name, workflow_run: predicate.workflow?.run_id,
  artifact_reference: reference, digest, sbom: predicate.sbom,
  predicate_type: process.env.DEVSHIELD_PROVENANCE_PREDICATE_TYPE,
  signer_identity: process.env.DEVSHIELD_PROVENANCE_SIGNER,
  verification: 'VERIFIED', verified_at: new Date().toISOString(),
};
fs.mkdirSync(path.dirname(process.env.DEVSHIELD_PROVENANCE_OUTPUT), {recursive: true});
fs.writeFileSync(process.env.DEVSHIELD_PROVENANCE_OUTPUT, `${JSON.stringify(evidence, null, 2)}\n`, {mode: 0o600});
console.log(`Provenance verification: PASS (${reference})`);
NODE
