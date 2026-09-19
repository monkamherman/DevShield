# Runtime Security with Falco

## Scope

Phase 13 adds runtime detection for the Docker runtime currently represented by DevShield. No Kubernetes DaemonSet, Falco Operator, Helm chart or admission controller is added because the repository has no Kubernetes runtime.

Falco observes kernel/container events. It is separate from Trivy, SBOM, Cosign, OPA, ZAP and Coraza:

```text
Falco → runtime behavior
OPA   → artifact/deployment policy
Coraza → HTTP filtering
ZAP   → dynamic application testing
```

## Version and backend

The pinned image is:

```text
docker.io/falcosecurity/falco:0.44.1
```

The configured backend is `modern_ebpf`; the DevShield rule version is `1.0.0`. `make runtime-version` prints the image, backend, rule version and hashes. Official Falco images are published with versioned tags and the project documents image signature verification; image verification remains part of the broader DevShield image trust process.

## Docker permissions

The wrapper uses the least-privilege profile documented by Falco for Modern eBPF:

```text
--cap-drop ALL
--cap-add SYS_ADMIN
--cap-add SYS_RESOURCE
--cap-add SYS_PTRACE
```

It mounts `/sys/kernel/tracing`, `/proc`, `/etc` and the Docker socket read-only. This is still host-sensitive access and must be reviewed before production use. `privileged: true` is not used by the DevShield wrapper. Some hosts may require an explicitly documented AppArmor or kernel adjustment; the wrapper does not silently add one.

## Rules

DevShield rules are separate from the upstream rules and detect:

- shells in containers;
- network tools such as `curl`, `wget`, `nc`, `ncat` and `socat`;
- reads of sensitive files;
- writes below `/etc`;
- execution from `/tmp`, `/var/tmp` or `/dev/shm`.

Rules generate events only. There is no `kill`, container termination, network isolation or global disable path. The rules are intentionally contextual because legitimate shells, file reads and network tools can exist in some applications.

## Lifecycle and failures

```bash
make runtime-validate
make runtime-up
make runtime-healthcheck
make runtime-down
```

The health check verifies the container, mounted DevShield rules and Falco usability, and searches startup logs for rule-loading failures. Missing rules, invalid configuration, missing Docker access or Falco startup failure produce explicit `RUNTIME_SECURITY_*` failures. Falco unavailability is reported as `UNKNOWN/FAILURE` runtime status; it is not automatically converted into an OPA deployment denial in this phase.

## Evidence

Falco JSON events can be normalized with:

```bash
docker logs devshield-falco > reports/runtime/falco-events.jsonl
security/runtime/evidence.sh \
  --input reports/runtime/falco-events.jsonl \
  --environment staging \
  --output reports/runtime/runtime-evidence.json
```

Evidence records engine/rules versions, hashes, environment, rule, severity, process, user, container name/id/image and image digest when present. Missing digest remains `null`; the normalizer never invents it. This prepares correlation with Harbor/Cosign/source evidence but does not claim that correlation when the runtime event does not provide it.

Severity is runtime-specific:

```text
NOTICE / WARNING / ERROR / CRITICAL
```

Detection does not imply remediation. Observability, alert routing and incident response are deferred to the next phase.

## Testing and limitations

`make runtime-test` validates rule/configuration presence, benign evidence, suspicious event normalization, missing-rule failure and Falco-unavailable failure. A host with Docker and Modern eBPF support is required for real syscall tests. The current environment does not provide that access, so shell/file/network detections have not been validated against a live Falco engine here.

The rules are not a complete runtime threat model. Falco does not replace image scanning, WAF, DAST or OPA.
