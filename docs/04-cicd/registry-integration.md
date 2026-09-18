# CI registry integration

The CI order is `checkout → scans/build/SBOM → centralized security gate → optional Harbor push`. The main workflow never assumes that `localhost` on a GitHub-hosted runner is a developer's Harbor instance. Harbor publication is therefore an explicitly enabled job on a runner with network access to the approved registry, using `HARBOR_USERNAME` and `HARBOR_PASSWORD` secrets for a project-scoped publisher.

The publisher must push the already-built, already-scanned image tagged `sha-<GITHUB_SHA>`; it must not rebuild after the gate. A registry outage fails the publication job. No registry credentials, signing keys or registry write permissions are present in the baseline security jobs.

Promotion is digest-based: build once, store one image in Harbor, then promote the same `image@sha256:<digest>` later. Phase 07 does not sign or authorize production deployment.
