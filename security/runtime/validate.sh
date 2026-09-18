#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

require_runtime_files
for rule in \
  'DevShield Shell in Container' \
  'DevShield Network Tool in Container' \
  'DevShield Sensitive File Read in Container' \
  'DevShield Write Below Etc in Container' \
  'DevShield Execute From Temporary Directory'; do
  grep -Fq -- "- rule: ${rule}" "$rules_file" || { echo "RUNTIME_SECURITY_RULE_FAILURE: missing rule ${rule}" >&2; exit 2; }
done
grep -Fq 'modern_ebpf' "$config_file" || { echo 'RUNTIME_SECURITY_RULE_FAILURE: modern_ebpf backend is not configured' >&2; exit 2; }
grep -Fq 'devshield-rules.yaml' "$config_file" || { echo 'RUNTIME_SECURITY_RULE_FAILURE: custom rules are not configured for loading' >&2; exit 2; }
echo "RUNTIME_SECURITY_READY: falco=${FALCO_VERSION} driver=${FALCO_DRIVER} rules=${DEVSHIELD_RULES_VERSION} rules_hash=$(rules_hash) config_hash=$(config_hash)"
