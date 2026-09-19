# Phase 05 Container Security Policy

The image and Dockerfile configuration use the Phase 04 severity baseline: CRITICAL, HIGH and UNKNOWN findings produce `SECURITY_FAILURE`; MEDIUM findings warn and pass; LOW findings are informational. Build failures and Trivy/configuration execution failures produce `TOOL_FAILURE` and block CI.

The baseline requires a non-root image user, no privileged execution in examples, no added Linux capabilities, no secret build arguments or environment values, and no mutable `latest` base image tag. No vulnerability exceptions are configured. Future exceptions require vulnerability/check ID, image or package, reason, risk assessment, owner and expiration/review date.
