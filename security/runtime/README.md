# DevShield runtime security

This directory provides a Docker-oriented Falco integration for runtime detection. It does not implement Kubernetes, automatic remediation or a SIEM.

The default image is `docker.io/falcosecurity/falco:0.44.1` with the Modern eBPF backend. The container uses the documented least-privilege Docker profile: all capabilities are dropped and `SYS_ADMIN`, `SYS_RESOURCE` and `SYS_PTRACE` are added. Host tracing, `/proc`, `/etc` and the Docker socket are mounted read-only as required for this runtime model.

```bash
make runtime-version
make runtime-validate
make runtime-up
make runtime-healthcheck
docker logs devshield-falco
make runtime-down
```

Falco remains detection-only. DevShield rules do not kill processes, terminate containers or isolate networks. `evidence.sh` converts JSON Falco events into `reports/runtime/runtime-evidence.json`, retaining container/image context and an image digest only when the event supplies one.

The custom rules are additive and loaded from `security/runtime/rules/devshield-rules.yaml` after the image's default rules. A missing rules file, invalid configuration or unavailable Falco is surfaced as a runtime-security failure; it is never reported as a runtime pass.
