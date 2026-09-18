# Local Harbor

## Generate a profile

Use the generator instead of editing paths by hand:

```bash
export HARBOR_INSTALLER_SHA256=<checksum-officiel>
make registry-config REGISTRY_ENV=dev
```

It creates the ignored `.env`, `harbor.yml`, local HTTPS certificates and runtime directories. Use another lowercase profile, for example `REGISTRY_ENV=staging`, to create a separate local naming profile. For production, provide passwords through the environment/secret manager; the generator refuses to invent production passwords.

This directory defines the Phase 07 local Harbor model. Harbor `2.14.4` is installed with the official offline installer; the generated Compose topology is intentionally not copied into this repository.

1. Obtain the release checksum from the official Harbor release page and export `HARBOR_INSTALLER_SHA256`.
2. Copy `.env.example` to `.env` and set local-only passwords.
3. Copy `harbor.yml.example` to `harbor.yml`, replace every placeholder with absolute paths, and configure a locally trusted certificate for `harbor.local`.
4. Add `harbor.local` to local DNS/hosts as appropriate.
5. Run `make registry-up`; the script verifies, extracts and runs the official `prepare` and `install.sh`.
6. Run `make registry-status`, then authenticate with `make registry-login`.

The CI publisher is a Harbor project-level identity, not the administrator. Configure the `devshield` project and `fixture` repository, enable immutability for `sha-*` and release tags, and retain release digests. Do not expose Harbor's database, Redis or internal services.

`make registry-test` requires `HARBOR_URL`, `HARBOR_REGISTRY`, `HARBOR_USERNAME` and `HARBOR_PASSWORD`; set `REGISTRY_FULL_TESTS=1` for push/pull validation. Without a reachable Harbor, the command returns `INFRASTRUCTURE_FAILURE` by design.

This profile is for isolated development. Production requires managed certificates, protected network access, secret management, backups and a reviewed retention policy. No registry credentials, generated runtime state or private keys belong in Git.
