# CI Foundation

## Purpose

The Phase 02 workflow provides a small, reproducible entry point for validating repository changes. It is designed to accept future security stages without mixing them into the foundation prematurely.

## Trigger model

The workflow runs for:

- pushes to `main`;
- pull requests targeting any branch.

Obsolete runs for the same workflow and ref are cancelled. The workflow requests only `contents: read` permission.

## Job model

```text
Developer
   │
   ▼
Pull Request / Push
   │
   ▼
GitHub Actions
   │
   ├── Foundation
   ├── Quality
   ├── Tests
   └── Build
```

The Foundation job checks the tracked repository contract and verifies the Makefile entry point. Quality, Tests and Build run after Foundation and call `make lint`, `make test` and `make build` respectively.

The repository currently has no application code, package manager, lockfile, linter, test framework or build system. The three application-aware Make targets therefore emit an explicit limitation and exit successfully; they do not claim that those checks are operational. When an application is introduced, these targets must be replaced or extended with its native commands, while preserving failure propagation.

## Failure model

Required shell commands use normal failure behavior. A missing foundation file, failed Make target or future application command causes its job to fail. The workflow does not use ignored failures, `|| true`, credentials or privileged execution.

## Local parity

From the repository root, run:

```bash
make help
make lint
make test
make build
make clean
```

These commands currently report that no application checks are configured. They are the local entry points that future application checks will replace or call.

## Security review and accepted limitations

The workflow uses the official checkout action at a pinned major version, read-only repository permissions, no secrets and no remote installation scripts. The action reference is not commit-SHA pinned yet; this is an accepted Phase 02 limitation to be reviewed as the supply-chain controls mature. No security scanner, artifact publishing, signing, provenance, policy gate or deployment is included.

## Future evolution

Future phases will insert SAST, secret detection, SCA, container, SBOM, signing, provenance, policy, DAST, WAF and runtime stages progressively. Those stages must keep explicit job boundaries, least privilege and fail-closed behavior.
