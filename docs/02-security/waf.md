# Web Application Firewall

## Architecture

DevShield uses the official Coraza CRS Docker reverse-proxy integration:

```text
client → Coraza + OWASP CRS → configured upstream application
```

The repository has no existing reverse proxy or Kubernetes ingress, so Phase 12 provides an isolated Docker-compatible WAF wrapper. It does not add Kubernetes, GitOps or a direct-to-application fallback.

## Versions

The default image is:

```text
ghcr.io/coreruleset/coraza-crs:4.25.0-nginx-202509051009
```

The tracked integration identifies the connector as `coraza-nginx-0.21.0` and CRS as `4.25.0`. The image tag is a stable CRS/timestamp tag, not `latest`. Run `make waf-version` to display the versions and configuration hash.

## Configuration

Required setting:

```text
TARGET_UPSTREAM=http://backend:3000
```

Supported settings:

```text
WAF_MODE=detection|blocking
WAF_ENVIRONMENT=development|staging|production
CRS_PARANOIA_LEVEL=1..4
ANOMALY_THRESHOLD=positive integer
WAF_PORT=8080
WAF_CONTAINER_NAME=devshield-waf
WAF_NETWORK=<optional Docker network>
```

Defaults are conservative: blocking mode, paranoia level 1 and anomaly threshold 5. Development may explicitly use detection mode; production defaults to blocking. `make waf-validate` validates a development detection profile using `http://127.0.0.1:8080` as a placeholder upstream. It does not claim that the upstream is running.

The CRS rules are supplied by the pinned official image and are not copied into this repository. The versioned local files under `security/waf/config/` define the DevShield configuration contract and future exclusion boundary. No exclusions are enabled.

## Running

```bash
make waf-version
make waf-validate TARGET_UPSTREAM=http://backend:3000 WAF_ENVIRONMENT=staging WAF_MODE=blocking
make waf-up TARGET_UPSTREAM=http://backend:3000 WAF_ENVIRONMENT=staging WAF_MODE=blocking
make waf-down
```

`waf-up` fails closed if Docker, the upstream, the configuration or the image cannot be used. `healthcheck.sh` confirms that the container is running and that the WAF endpoint responds.

## Modes

Detection mode maps to Coraza `DetectionOnly`: requests are inspected and logged but may reach the upstream. It is not blocking protection. Blocking mode maps to Coraza `On`: a CRS intervention must return a block response and the upstream must not receive that request.

Recommended profiles:

| Environment | Mode | Purpose |
|---|---|---|
| Development | Detection | tune and observe |
| Staging | Detection then Blocking | validate false positives, then enforce |
| Production | Blocking | protected entry point |

These profiles require explicit operational configuration; staging and production are not automatically created by this repository.

## Events and evidence

Coraza audit output is JSON-oriented and is emitted to the container log. `security/waf/evidence.sh` normalizes an audit JSON-lines file into `reports/waf/waf-events.json`, including product/CRS versions, mode, environment, configuration hash, action, rule ID, method, path, status and summary counts. Sensitive request content is not copied into the normalized event.

```bash
docker logs devshield-waf > reports/waf-audit.jsonl
WAF_ENVIRONMENT=staging security/waf/evidence.sh \
  --audit-log reports/waf-audit.jsonl \
  --output reports/waf/waf-events.json
```

The WAF event is runtime evidence, not an OPA artifact authorization. It does not replace DAST, OPA, Cosign or runtime security.

## Testing

`make waf-test` validates configuration and evidence deterministically. If Docker is available, it also builds the existing application fixture, starts Coraza in front of it and checks normal traffic, SQLi/XSS blocking, audit collection and detection-mode forwarding. In an environment without Docker, the command returns `2` with `WAF_TEST_FAILURE`; configuration/evidence checks may pass, but runtime integration is not represented as successful.

The intended requests include:

```text
GET /health                         → allowed
GET /?id=1 AND 1=1                 → blocked in blocking mode
GET /?q=<script>alert(1)</script>  → blocked in blocking mode
```

CRS coverage is broad but not universal. A WAF does not prove that the application is secure.

## False positives and TLS

There is no global CRS disable or bypass. Future exclusions must identify the rule, path, owner, reason and review date in version control. TLS termination and upstream TLS are deployment decisions; certificate verification must not be globally disabled and private certificates do not belong in Git. Rate limiting is deferred to a reverse proxy, gateway or application layer.
