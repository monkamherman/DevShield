.PHONY: help test lint build clean security-sast security-secrets security-sca container-build security-container sbom sbom-validate artifact-inventory security-sbom registry-config registry-up registry-down registry-status registry-login registry-test registry-push registry-pull security-registry cosign-version cosign-keygen security-sign security-verify-signature security-inspect-signature security-signing test-signing security

help:
	@printf '%s\n' 'Available targets:' '  help            Show this message' '  test            Report that tests are not configured yet' '  lint            Report that linting is not configured yet' '  build           Report that no application build is configured yet' '  clean           Report that no generated files exist' '  security-sast   Run the pinned Semgrep scan' '  security-secrets Run the pinned Gitleaks scan' '  security-sca    Run the pinned Trivy dependency scan' '  container-build Build the deterministic container image' '  security-container Build and scan the container image' '  sbom            Generate the image CycloneDX SBOM' '  sbom-validate   Validate the generated SBOM' '  artifact-inventory Generate the artifact inventory' '  security-sbom   Generate, validate and inventory the image SBOM' '  cosign-version  Verify the pinned Cosign version' '  cosign-keygen   Generate a local Cosign key pair' '  security-sign   Sign the gated Harbor digest' '  security-verify-signature Verify the expected Cosign identity' '  security-inspect-signature Inspect stored Cosign signatures' '  security-signing Run gate, Harbor push, signing and verification' '  test-signing    Run deterministic signing policy tests' '  security         Run all scanners and the security gate'
	@printf '%s\n' '  registry-config Generate local .env, harbor.yml and HTTPS certificates' '  registry-up     Verify/extract and install the pinned local Harbor distribution' '  registry-down   Stop the local Harbor distribution' '  registry-status Check Harbor availability' '  registry-login  Login using environment-provided credentials' '  registry-test   Run Harbor integration tests' '  registry-push   Run the gate, then push the approved image' '  registry-pull   Pull and verify an artifact digest' '  security-registry Run registry integration checks (requires Harbor)'

test:
	@echo 'Tests are not configured yet; no application or test framework exists.'

lint:
	@echo 'Linting is not configured yet; no application or linter exists.'

build:
	@echo 'No application build is configured yet; no application code exists.'

clean:
	@echo 'Nothing to clean; no generated artifacts exist.'

security-sast:
	@security/sast/semgrep/run.sh

security-secrets:
	@security/secrets/gitleaks/run.sh

security-sca:
	@security/sca/trivy/run.sh

container-build:
	@security/container/build.sh

security-container:
	@security/container/build.sh
	@security/container/scan.sh

sbom:
	@security/sbom/generate.sh

sbom-validate:
	@security/sbom/validate.sh

artifact-inventory:
	@security/sbom/inventory.sh

security-sbom:
	@security/sbom/run.sh

cosign-version:
	@security/signing/cosign/install.sh

cosign-keygen:
	@security/signing/cosign/keygen.sh

security-sign:
	@security/signing/cosign/sign.sh $(IMAGE_REF)

security-verify-signature:
	@security/signing/cosign/verify.sh $(IMAGE_REF)

security-inspect-signature:
	@security/signing/cosign/inspect.sh $(IMAGE_REF)

security-signing:
	@security/signing/run.sh

test-signing:
	@tests/security/signing/run.sh

registry-config:
	@infrastructure/registry/scripts/configure.sh $(REGISTRY_ENV)

registry-up:
	@infrastructure/registry/scripts/up.sh

registry-down:
	@infrastructure/registry/scripts/down.sh

registry-status:
	@infrastructure/registry/scripts/status.sh

registry-login:
	@security/registry/login.sh

registry-test:
	@tests/security/registry/failure.sh
	@tests/security/registry/run.sh

registry-push:
	@security/registry/push.sh

registry-pull:
	@security/registry/pull.sh

security-registry:
	@tests/security/registry/run.sh

security:
	@security/run.sh
