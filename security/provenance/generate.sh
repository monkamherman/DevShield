#!/usr/bin/env bash
set -euo pipefail

root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$root"

output="${DEVSHIELD_PROVENANCE_OUTPUT:-$root/reports/provenance.json}"
predicate="${DEVSHIELD_PROVENANCE_PREDICATE:-$root/reports/provenance-predicate.json}"
build_metadata="${DEVSHIELD_BUILD_METADATA:-$root/reports/container-build-metadata.json}"
inventory="${DEVSHIELD_INVENTORY:-$root/reports/artifact-inventory.json}"
registry_evidence="${DEVSHIELD_REGISTRY_EVIDENCE:-$root/reports/registry-push-evidence.json}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --output) output="$2"; shift 2 ;;
    --predicate) predicate="$2"; shift 2 ;;
    --build-metadata) build_metadata="$2"; shift 2 ;;
    --inventory) inventory="$2"; shift 2 ;;
    --registry-evidence) registry_evidence="$2"; shift 2 ;;
    *) echo "TOOL_FAILURE: unknown provenance option $1" >&2; exit 2 ;;
  esac
done

[[ -s "$build_metadata" ]] || { echo "TOOL_FAILURE: build metadata is missing at $build_metadata" >&2; exit 2; }
[[ -s "$inventory" ]] || { echo "TOOL_FAILURE: artifact inventory is missing at $inventory" >&2; exit 2; }
[[ -s "$registry_evidence" ]] || { echo "TOOL_FAILURE: Harbor evidence is missing at $registry_evidence" >&2; exit 2; }

export DEVSHIELD_PROVENANCE_OUTPUT="$output" DEVSHIELD_PROVENANCE_PREDICATE="$predicate" \
  DEVSHIELD_BUILD_METADATA="$build_metadata" DEVSHIELD_INVENTORY="$inventory" \
  DEVSHIELD_REGISTRY_EVIDENCE="$registry_evidence"
node <<'NODE'
const fs = require('fs');
const path = require('path');
const read = (name) => JSON.parse(fs.readFileSync(name, 'utf8'));
const build = read(process.env.DEVSHIELD_BUILD_METADATA);
const inventory = read(process.env.DEVSHIELD_INVENTORY);
const registry = read(process.env.DEVSHIELD_REGISTRY_EVIDENCE);
const digestPattern = /^sha256:[0-9a-f]{64}$/;
const commitPattern = /^[0-9a-f]{40}$/;
if (registry.result !== 'PASS' || !digestPattern.test(registry.digest || '')) throw new Error('Harbor evidence is not a verified PASS with a valid digest');
if (!digestPattern.test(build.image_digest || '') || build.image_digest !== registry.digest) throw new Error('build digest and Harbor digest differ');
if (inventory.result !== 'PASS' || inventory.artifact?.digest !== registry.digest) throw new Error('artifact inventory is not bound to the Harbor digest');
const commit = process.env.GITHUB_SHA || build.commit || inventory.source?.commit || '';
if (!commitPattern.test(commit)) throw new Error('provenance requires the 40-character Git commit SHA from CI');
const reference = registry.image_reference;
if (reference !== `${registry.registry}/${registry.repository}@${registry.digest}`) throw new Error('Harbor evidence has an inconsistent immutable reference');
const sourceRepository = process.env.GITHUB_REPOSITORY || build.repository;
if (!sourceRepository || sourceRepository === 'local' || sourceRepository === 'unknown') throw new Error('provenance requires the CI source repository');
const workflow = process.env.GITHUB_WORKFLOW || build.workflow;
const workflowRun = process.env.GITHUB_RUN_ID || build.workflow_run;
if (!workflow || !workflowRun) throw new Error('provenance requires the CI workflow and run');
const generatedAt = new Date().toISOString();
const evidence = {
  schema_version: '1.0', present: true, trusted: false, verification: 'NOT_VERIFIED',
  source_repository: sourceRepository, source_commit: commit,
  workflow, workflow_run: String(workflowRun), artifact_reference: reference,
  digest: registry.digest,
  sbom: {format: inventory.sbom?.format || 'CycloneDX JSON', digest: inventory.sbom?.digest || registry.digest},
  predicate_type: 'https://devshield.dev/provenance/v1', generated_at: generatedAt,
};
if (evidence.sbom.digest !== registry.digest) throw new Error('SBOM digest is not bound to the Harbor digest');
const statement = {
  _type: 'https://in-toto.io/Statement/v1',
  subject: [{name: reference.slice(0, reference.indexOf('@')), digest: {sha256: registry.digest.slice('sha256:'.length)}}],
  predicateType: evidence.predicate_type,
  predicate: {schema_version: evidence.schema_version, source: {repository: sourceRepository, commit}, workflow: {name: workflow, run_id: String(workflowRun)}, artifact: {reference, digest: registry.digest}, sbom: evidence.sbom, generated_at: generatedAt},
};
fs.mkdirSync(path.dirname(process.env.DEVSHIELD_PROVENANCE_OUTPUT), {recursive: true});
fs.mkdirSync(path.dirname(process.env.DEVSHIELD_PROVENANCE_PREDICATE), {recursive: true});
fs.writeFileSync(process.env.DEVSHIELD_PROVENANCE_OUTPUT, `${JSON.stringify(evidence, null, 2)}\n`, {mode: 0o600});
fs.writeFileSync(process.env.DEVSHIELD_PROVENANCE_PREDICATE, `${JSON.stringify(statement, null, 2)}\n`, {mode: 0o600});
console.log(`Provenance generation: PASS (${registry.digest})`);
NODE
