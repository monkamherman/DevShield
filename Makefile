.PHONY: help test lint build clean security-sast security-secrets security-sca container-build security-container sbom sbom-validate artifact-inventory security-sbom registry-config registry-up registry-down registry-status registry-login registry-test registry-push registry-pull security-registry cosign-version cosign-keygen security-sign security-verify-signature security-inspect-signature security-signing test-signing opa-install opa-version policy-input policy-test policy-check security-policy deployment-validate deployment-authorize deployment-test deployment-security dast-version dast-run dast-test dast-security waf-version waf-validate waf-test waf-security waf-up waf-down waf-healthcheck runtime-version runtime-validate runtime-test runtime-security runtime-up runtime-down runtime-healthcheck security

help:
	@printf '%s\n' 'Available targets:' '  help            Show this message' '  test            Report that tests are not configured yet' '  lint            Report that linting is not configured yet' '  build           Report that no application build is configured yet' '  clean           Report that no generated files exist' '  security-sast   Run the pinned Semgrep scan' '  security-secrets Run the pinned Gitleaks scan' '  security-sca    Run the pinned Trivy dependency scan' '  container-build Build the deterministic container image' '  security-container Build and scan the container image' '  sbom            Generate the image CycloneDX SBOM' '  sbom-validate   Validate the generated SBOM' '  artifact-inventory Generate the artifact inventory' '  security-sbom   Generate, validate and inventory the image SBOM' '  cosign-version  Verify the pinned Cosign version' '  cosign-keygen   Generate a local Cosign key pair' '  security-sign   Sign the gated Harbor digest' '  security-verify-signature Verify the expected Cosign identity' '  security-inspect-signature Inspect stored Cosign signatures' '  security-signing Run gate, Harbor push, signing and verification' '  test-signing    Run deterministic signing policy tests' '  opa-install     Install and checksum the pinned OPA binary' '  opa-version     Verify the pinned OPA version' '  policy-input    Normalize existing evidence for OPA' '  policy-test     Run OPA/Rego tests' '  policy-check    Evaluate a normalized policy input' '  security-policy  Normalize evidence and evaluate OPA' '  deployment-validate Validate an immutable deployment reference' '  deployment-authorize Authorize an exact artifact through OPA' '  deployment-test Run deployment authorization tests' '  deployment-security Run deployment trust tests' '  dast-version    Show the pinned OWASP ZAP version' '  dast-run        Run a ZAP baseline scan' '  dast-test       Run deterministic DAST tests' '  dast-security   Run the DAST security scan' '  waf-version     Show Coraza and CRS versions' '  waf-validate    Validate WAF configuration' '  waf-test        Run WAF tests' '  waf-security    Run the WAF security test suite' '  waf-up          Start the WAF reverse proxy' '  waf-down        Stop the WAF reverse proxy' '  waf-healthcheck Check WAF container and endpoint readiness' '  runtime-version Show the pinned Falco runtime' '  runtime-validate Validate Falco configuration and rules' '  runtime-test Run runtime security tests' '  runtime-security Run runtime security validation' '  runtime-up Start Falco runtime detection' '  runtime-down Stop Falco runtime detection' '  runtime-healthcheck Check Falco readiness and rule loading' '  security         Run all scanners and the security gate'
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

opa-install:
	@security/policies/opa/install.sh

opa-version:
	@security/policies/opa/version.sh

policy-input:
	@security/policies/opa/normalize.sh

policy-test:
	@tests/security/policy/run.sh

policy-check:
	@security/policies/opa/evaluate.sh $(if $(POLICY_INPUT),--input $(POLICY_INPUT),)

security-policy: policy-input
	@security/policies/opa/evaluate.sh

deployment-validate:
	@security/deployment/validate-artifact.sh --artifact "$(ARTIFACT_REF)" --environment "$(DEPLOYMENT_ENVIRONMENT)"

deployment-authorize:
	@security/deployment/authorize.sh --artifact "$(ARTIFACT_REF)" --environment "$(DEPLOYMENT_ENVIRONMENT)" --policy-input "$(POLICY_INPUT)"

deployment-test:
	@tests/security/deployment/run.sh

deployment-security: deployment-test

dast-version:
	@security/dast/version.sh

dast-run:
	@security/dast/run.sh --target "$(TARGET_URL)" --environment "$(DAST_ENVIRONMENT)" $(if $(DAST_ARTIFACT),--artifact "$(DAST_ARTIFACT)",) $(if $(DAST_ALLOWED_HOSTS),--allowed-host "$(DAST_ALLOWED_HOSTS)",)

dast-test:
	@tests/security/dast/run.sh

dast-security: dast-run

waf-version:
	@security/waf/version.sh

waf-validate:
	@TARGET_UPSTREAM="$(if $(TARGET_UPSTREAM),$(TARGET_UPSTREAM),http://127.0.0.1:8080)" WAF_ENVIRONMENT="$(if $(WAF_ENVIRONMENT),$(WAF_ENVIRONMENT),development)" WAF_MODE="$(if $(WAF_MODE),$(WAF_MODE),detection)" security/waf/validate-config.sh

waf-test:
	@tests/security/waf/run.sh

waf-security: waf-test

waf-up:
	@security/waf/run.sh --upstream "$(TARGET_UPSTREAM)" --environment "$(WAF_ENVIRONMENT)" --mode "$(WAF_MODE)"

waf-down:
	@docker rm -f "$(if $(WAF_CONTAINER_NAME),$(WAF_CONTAINER_NAME),devshield-waf)"

waf-healthcheck:
	@security/waf/healthcheck.sh

runtime-version:
	@security/runtime/version.sh

runtime-validate:
	@security/runtime/validate.sh

runtime-test:
	@tests/security/runtime/run.sh

runtime-security: runtime-test

runtime-up:
	@security/runtime/run.sh

runtime-down:
	@security/runtime/stop.sh

runtime-healthcheck:
	@security/runtime/healthcheck.sh

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
