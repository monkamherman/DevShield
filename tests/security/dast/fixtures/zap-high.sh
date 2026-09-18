#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' '{"site":[{"@name":"http://127.0.0.1:18080","alerts":[{"name":"Missing security header","riskdesc":"High (Medium)","confidence":"High","url":"http://127.0.0.1:18080/"}]}]}' > "$2"
printf '%s\n' '<html><body>ZAP baseline high finding fixture</body></html>' > "$3"
