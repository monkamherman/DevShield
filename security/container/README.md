# Container security

Phase 05 builds the foundation Node.js fixture with Docker and scans the resulting local image with Trivy `0.73.0`. The image scan enables only vulnerability analysis for OS and application packages. A separate Trivy config scan evaluates the Dockerfile; CRITICAL, HIGH and UNKNOWN configuration findings block, while MEDIUM and LOW remain visible without blocking.

The build and scan are deliberately local/CI-only. Images are not pushed to Harbor, GHCR or Docker Hub. Since no registry reference exists, evidence records the local image ID and leaves `image_digest` null rather than fabricating a digest. Future registry/provenance phases will associate a registry digest and signature.
