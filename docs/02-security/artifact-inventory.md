# Artifact inventory

The primary Phase 06 artifact is a container image. Its identity hierarchy is:

```text
repository → commit → build/run → image reference → image digest → SBOM
```

`reports/artifact-inventory.json` is intentionally separate from the SBOM and vulnerability reports. It records schema version, artifact type/reference/digest, source commit, workflow/run, SBOM format/generator/version/location, component count and result. The digest is sourced from BuildKit metadata (`containerimage.digest`); Git SHA and image digest are different fields.

The inventory only correlates identity and observed contents. It does not claim authenticity, provenance, signing or builder trust. A future registry can replace the local image reference with a registry digest, while Cosign/provenance can attach additional evidence to the same digest.
