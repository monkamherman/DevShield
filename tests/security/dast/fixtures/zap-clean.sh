#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' '{"site":[{"@name":"http://127.0.0.1:18080","alerts":[]}]}' > "$2"
printf '%s\n' '<html><body>ZAP baseline clean fixture</body></html>' > "$3"
