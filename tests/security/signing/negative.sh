#!/usr/bin/env bash
set -euo pipefail
root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$root"

digest="harbor.example.test/devshield/fixture@sha256:$(printf 'c%.0s' {1..64})"
if HARBOR_REGISTRY=harbor.example.test security/signing/cosign/verify.sh "$digest"; then
  echo 'Expected verification without a trusted key and Cosign execution to fail.' >&2
  exit 1
fi
if security/signing/cosign/digest.sh >/dev/null 2>&1; then
  echo 'Expected digest resolution without registry evidence to fail.' >&2
  exit 1
fi
echo 'Cosign negative precondition tests: PASS'

fake_dir="$(mktemp -d)"
trap 'rm -rf "$fake_dir"' EXIT
cat > "$fake_dir/curl" <<'CURL'
#!/usr/bin/env bash
printf '200'
CURL
cat > "$fake_dir/docker" <<'DOCKER'
#!/usr/bin/env bash
exit 1
DOCKER
chmod +x "$fake_dir/curl" "$fake_dir/docker"
if PATH="$fake_dir:$PATH" HARBOR_REGISTRY=harbor.example.test HARBOR_USERNAME=publisher HARBOR_PASSWORD=placeholder bash -c 'source security/signing/cosign/common.sh; registry_login' 2>"$fake_dir/auth.err"; then
  echo 'Expected invalid Harbor credentials to fail.' >&2
  exit 1
fi
grep -q AUTHENTICATION_FAILURE "$fake_dir/auth.err"
cat > "$fake_dir/curl" <<'CURL'
#!/usr/bin/env bash
exit 7
CURL
if PATH="$fake_dir:$PATH" HARBOR_REGISTRY=harbor.example.test HARBOR_USERNAME=publisher HARBOR_PASSWORD=placeholder bash -c 'source security/signing/cosign/common.sh; registry_login' 2>"$fake_dir/outage.err"; then
  echo 'Expected Harbor outage to fail.' >&2
  exit 1
fi
grep -q INFRASTRUCTURE_FAILURE "$fake_dir/outage.err"
echo 'Cosign Harbor authentication/outage tests: PASS'
