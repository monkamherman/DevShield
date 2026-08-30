# Trivy SCA

The Trivy image is pinned to `aquasec/trivy:0.73.0`. Its vulnerability database is downloaded through the normal verified HTTPS registry mechanism and cached in `.trivy-cache/`, which is not committed. A database outage is a tool failure, never a clean scan.

When manifests exist, production and development dependencies remain in scope because build and test dependencies are part of the software supply-chain boundary. No install or dependency update is performed by the scanner.
