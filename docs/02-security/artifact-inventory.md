# Artifact inventory

The primary Phase 06 artifact is a container image. Its identity hierarchy is:

```text
repository → commit → build/run → image reference → image digest → SBOM
```

`reports/artifact-inventory.json` is intentionally separate from the SBOM and vulnerability reports. It records schema version, artifact type/reference/digest, source commit, workflow/run, SBOM format/generator/version/location, component count and result. The digest is sourced from BuildKit metadata (`containerimage.digest`); Git SHA and image digest are different fields.

The inventory correlates identity and observed contents. It does not by itself claim authenticity, provenance or builder trust. The current registry digest is retained as the artifact identity, and Phase 08 attaches Cosign signing and verification evidence to that same digest.
