# CI signing integration

The Phase 08 extension of the security workflow is:

```text
checkout → SAST/secrets/SCA → container/SBOM → security gate
         → Harbor push → digest resolution → Cosign sign → Cosign verify
```

Harbor publication remains optional and uses the existing project-scoped credentials. The signing steps are enabled only when `DEVSHIELD_COSIGN_ENABLED=true`, run only on a push to `main`, and use GitHub OIDC keyless signing. Pull requests therefore receive security validation but cannot create trusted main-branch signatures.

The publisher does not rebuild the image. It downloads the image tar produced by the container job, loads it, pushes it under `sha-<commit>`, reads the returned digest, and signs that digest. A registry digest mismatch with the BuildKit digest blocks the operation.

Required GitHub configuration for the optional path:

- repository variable `DEVSHIELD_HARBOR_ENABLED=true`;
- repository variable `DEVSHIELD_COSIGN_ENABLED=true`;
- `HARBOR_REGISTRY`, `HARBOR_PROJECT` and `HARBOR_REPOSITORY` variables;
- project-scoped `HARBOR_USERNAME` and `HARBOR_PASSWORD` secrets;
- a self-hosted runner with Docker access to Harbor;
- Harbor permissions that allow image and Cosign signature publication, without administrator credentials.

The workflow grants `id-token: write` only to the optional Harbor job. Cosign verifies the expected certificate identity for the `security.yml` workflow on `main` and the GitHub Actions OIDC issuer. The resulting JSON evidence is retained for 14 days.

This is not a deployment authorization gate. Future OPA/Rego policy will evaluate the digest, scan/SBOM evidence and verified signer before deployment.
