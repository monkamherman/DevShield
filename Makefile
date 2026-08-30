.PHONY: help test lint build clean security-sast security-secrets security-sca container-build security-container sbom sbom-validate artifact-inventory security-sbom security

help:
	@printf '%s\n' 'Available targets:' '  help            Show this message' '  test            Report that tests are not configured yet' '  lint            Report that linting is not configured yet' '  build           Report that no application build is configured yet' '  clean           Report that no generated files exist' '  security-sast   Run the pinned Semgrep scan' '  security-secrets Run the pinned Gitleaks scan' '  security-sca    Run the pinned Trivy dependency scan' '  container-build Build the deterministic container image' '  security-container Build and scan the container image' '  sbom            Generate the image CycloneDX SBOM' '  sbom-validate   Validate the generated SBOM' '  artifact-inventory Generate the artifact inventory' '  security-sbom   Generate, validate and inventory the image SBOM' '  security         Run all scanners and the security gate'

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

security:
	@security/run.sh
