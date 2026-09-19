#!/usr/bin/env bash
set -euo pipefail
root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
fake_dir="$(mktemp -d)"
report_dir="$(mktemp -d)"
trap 'rm -rf "$fake_dir" "$report_dir"' EXIT
cat > "$fake_dir/docker" <<'DOCKER'
#!/usr/bin/env bash
set -euo pipefail
case "$1" in
  login|tag|push) exit 0 ;;
  image)
    if [[ " $* " == *" --format "* ]]; then
      printf 'sha256:%064d\n' 1
    fi
    exit 0
    ;;
  *) exit 0 ;;
esac
DOCKER
chmod +x "$fake_dir/docker"
cat > "$report_dir/container-build-metadata.json" <<'JSON'
{"image_digest":"sha256:0000000000000000000000000000000000000000000000000000000000000002"}
JSON
if PATH="$fake_dir:$PATH" DEVSHIELD_SKIP_SECURITY_GATE=1 DEVSHIELD_GATE_CONFIRMED=1 DEVSHIELD_REPORT_DIR="$report_dir" DEVSHIELD_BUILD_METADATA="$report_dir/container-build-metadata.json" HARBOR_REGISTRY=harbor.example.test HARBOR_USERNAME=publisher HARBOR_PASSWORD=placeholder security/registry/push.sh; then
  echo 'Expected registry digest mismatch to fail.' >&2
  exit 1
fi
echo 'Registry/build digest mismatch test: PASS'
