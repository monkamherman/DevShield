# DevShield registry policy

- Harbor is the approved private registry for Phase 07. Registry presence is not proof of authenticity.
- CI may push only after the centralized SAST, secret, SCA, container and SBOM checks pass. A failed gate performs no push.
- CI uses a dedicated project Developer/publisher identity, never the Harbor administrator. Human read access is Guest/Limited Guest unless write access is required.
- Images use `harbor-host:port/devshield/fixture:sha-<commit>`. `latest` is not a trusted identity; promotion uses the immutable digest.
- Trusted repositories must enable Harbor tag immutability for `sha-*`/release tags. A new commit receives a new tag.
- Harbor's Trivy scanner provides registry-side continuous visibility. It does not replace the pre-push DevShield Trivy gate.
- Harbor outage or authentication failure is `INFRASTRUCTURE_FAILURE`; command/scanner malfunction is `TOOL_FAILURE`; vulnerability or digest-integrity failure is `SECURITY_FAILURE`.
- Retention must preserve release tags and digests needed for reproducibility. Development cleanup may remove temporary tags only after an explicit tested policy.
- Credentials are supplied through environment/CI secrets and never logged or committed. TLS verification remains enabled.
- Cosign signatures, provenance and production deployment authorization are intentionally deferred to later phases.
