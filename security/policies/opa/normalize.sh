#!/usr/bin/env bash
set -euo pipefail
root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
environment="${DEVSHIELD_POLICY_ENVIRONMENT:-development}"
output="$root/${DEVSHIELD_POLICY_INPUT:-reports/policy-input.json}"
evidence_root="$root/${DEVSHIELD_POLICY_EVIDENCE_ROOT:-reports}"
trusted_registry="${DEVSHIELD_TRUSTED_REGISTRY:-${HARBOR_REGISTRY:-}}"
trusted_repository="${DEVSHIELD_TRUSTED_REPOSITORY:-}"
trusted_signer="${DEVSHIELD_TRUSTED_SIGNER:-}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --environment) environment="$2"; shift 2 ;;
    --output) output="$2"; shift 2 ;;
    --evidence-root) evidence_root="$2"; shift 2 ;;
    --trusted-registry) trusted_registry="$2"; shift 2 ;;
    --trusted-repository) trusted_repository="$2"; shift 2 ;;
    --trusted-signer) trusted_signer="$2"; shift 2 ;;
    *) echo "TOOL_FAILURE: unknown normalize option $1" >&2; exit 2 ;;
  esac
done

export DEVSHIELD_POLICY_ENVIRONMENT="$environment" DEVSHIELD_POLICY_OUTPUT="$output" DEVSHIELD_POLICY_EVIDENCE_ROOT="$evidence_root" DEVSHIELD_TRUSTED_REGISTRY="$trusted_registry" DEVSHIELD_TRUSTED_REPOSITORY="$trusted_repository" DEVSHIELD_TRUSTED_SIGNER="$trusted_signer"
node <<'NODE'
const fs = require('fs');
const path = require('path');
const root = process.env.DEVSHIELD_POLICY_EVIDENCE_ROOT;
const output = process.env.DEVSHIELD_POLICY_OUTPUT;
const read = (name) => {
  const walk = (dir) => {
    if (!fs.existsSync(dir)) return null;
    for (const entry of fs.readdirSync(dir, {withFileTypes: true})) {
      const p = path.join(dir, entry.name);
      if (entry.isFile() && entry.name === name) return p;
      if (entry.isDirectory()) { const found = walk(p); if (found) return found; }
    }
    return null;
  };
  const file = walk(root);
  if (!file) return {data: null, path: null};
  try { return {data: JSON.parse(fs.readFileSync(file, 'utf8')), path: file}; }
  catch (error) { throw new Error(`invalid ${name}: ${error.message}`); }
};
const csv = (value) => value ? value.split(',').map(x => x.trim()).filter(Boolean) : [];
const semgrep = read('semgrep-metadata.json');
const secrets = read('gitleaks-metadata.json');
const sca = read('trivy-sca-metadata.json');
const container = read('trivy-container-metadata.json');
const inventory = read('artifact-inventory.json');
const build = read('container-build-metadata.json');
const registry = read('registry-push-evidence.json');
const signature = read('cosign-signing-evidence.json');
const provenance = read('provenance.json');
const first = (...values) => values.find(value => value !== undefined && value !== null && value !== '');
const digest = first(registry.data?.digest, inventory.data?.artifact?.digest, build.data?.image_digest, signature.data?.digest, null);
const repository = first(registry.data?.registry && registry.data?.repository ? `${registry.data.registry}/${registry.data.repository}` : null, inventory.data?.artifact?.reference, build.data?.image, 'unknown');
const reference = first(registry.data?.image_reference, digest && repository !== 'unknown' ? `${repository}@${digest}` : null, build.data?.image, 'unknown');
const sourceCommit = first(registry.data?.source_commit, inventory.data?.source?.commit, build.data?.commit, semgrep.data?.commit, process.env.GITHUB_SHA, 'unknown');
const count = (obj, key) => Number(obj?.[key] ?? 0);
const containerFindings = [...(container.data?.image_findings || []), ...(container.data?.configuration_findings || [])];
const containerCounts = Object.fromEntries(['CRITICAL','HIGH','MEDIUM','LOW','UNKNOWN'].map(s => [s, containerFindings.filter(v => v.severity === s).length]));
const input = {
  schema_version: '1.0',
  policy: {version: '1.0.0', trusted_registries: csv(process.env.DEVSHIELD_TRUSTED_REGISTRY), trusted_repositories: csv(process.env.DEVSHIELD_TRUSTED_REPOSITORY), trusted_signers: csv(process.env.DEVSHIELD_TRUSTED_SIGNER)},
  environment: process.env.DEVSHIELD_POLICY_ENVIRONMENT,
  artifact: {repository, reference, digest, tag: registry.data?.tag || null},
  source: {repository: first(build.data?.repository, semgrep.data?.repository, process.env.GITHUB_REPOSITORY, 'unknown'), commit: sourceCommit, branch: process.env.GITHUB_REF_NAME || null},
  security: {
    sast: {status: semgrep.data?.result || 'MISSING'},
    secrets: {status: secrets.data?.result || 'MISSING'},
    sca: {status: sca.data?.result || 'MISSING', ...Object.fromEntries(['CRITICAL','HIGH','MEDIUM','LOW','UNKNOWN'].map(s => [s.toLowerCase(), count(sca.data?.vulnerability_counts, s)]))},
    container: {status: container.data?.result || 'MISSING', ...Object.fromEntries(['CRITICAL','HIGH','MEDIUM','LOW','UNKNOWN'].map(s => [s.toLowerCase(), containerCounts[s]]))},
  },
  sbom: {present: inventory.data?.result === 'PASS', format: inventory.data?.sbom?.format || null, digest: inventory.data?.artifact?.digest || null},
  registry: {name: registry.data?.registry ? 'harbor' : 'local', host: registry.data?.registry || null, repository: registry.data?.repository || null, trusted: registry.data?.result === 'PASS' && csv(process.env.DEVSHIELD_TRUSTED_REGISTRY).includes(registry.data.registry), digest: registry.data?.digest || null},
  signature: {signed: signature.data?.signature_status === 'SIGNED', verified: signature.data?.verified === true, digest: signature.data?.digest || null, signer: signature.data?.signer_identity || null},
  provenance: {present: provenance.data?.present === true, trusted: provenance.data?.trusted === true, digest: provenance.data?.digest || null, source_commit: provenance.data?.source_commit || null},
  evidence: {semgrep: semgrep.path, secrets: secrets.path, sca: sca.path, container: container.path, sbom: inventory.path, registry: registry.path, signature: signature.path},
};
fs.mkdirSync(path.dirname(output), {recursive: true});
fs.writeFileSync(output, `${JSON.stringify(input, null, 2)}\n`);
console.log(`Policy input: PASS (${output})`);
NODE
