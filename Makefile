SHELL := /bin/bash
CI ?= false
IS_MACOS ?= $(shell [[ `uname` = 'Darwin' ]] && echo "true" || echo "false")
PROJECT_NAME ?= $(shell jq -r '.name' package.json)
GIT_COMMIT_SHA ?= $(shell git rev-parse --verify HEAD)
GIT_BRANCH ?= $(shell git rev-parse --abbrev-ref HEAD)
GIT_IS_DIRTY ?= $(shell git diff --quiet && echo "false" || echo "true")
GIT_COMMIT_AUTHOR ?= $(shell git log -1 --format="%ae")
DOCKER_SRC_DIR ?= /usr/src/app
DOCKER_BUILD_ARGS ?= $(addprefix --build-arg ,app_src_dir=$(DOCKER_SRC_DIR) git_branch=$(GIT_BRANCH) git_commit_sha=$(GIT_COMMIT_SHA) git_is_dirty=$(GIT_IS_DIRTY))
IMAGE_BASE_NAME ?= mattupstate/$(PROJECT_NAME)
DOCKER_BUILD_CHECKSUM ?= $(shell ./bin/md5 package-lock.json Dockerfile)
APP_SRC_CHECKSUM ?= $(shell ./bin/md5 $$(find ./src -type f))
TEST_IMAGE_TAG ?= test-$(DOCKER_BUILD_CHECKSUM)
TEST_IMAGE ?= $(IMAGE_BASE_NAME):$(TEST_IMAGE_TAG)
TEST_IMAGE_BUILD_TARGET ?= test
TEST_CONTAINER_NAME ?= test-$(DOCKER_BUILD_CHECKSUM)
TEST_CONTAINER_SECCOMP_FILE ?= etc/docker/seccomp/chrome.json
DIST_IMAGE_BUILD_TARGET ?= dist
DIST_IMAGE ?= $(IMAGE_BASE_NAME):$(GIT_COMMIT_SHA)
PUBLIC_ROOT_HOSTNAME ?= angular-pipeline-example.mattupstate.com
PUBLIC_ROOT_URL ?= http://$(PUBLIC_ROOT_HOSTNAME)
PUBLIC_VERSIONED_HOSTNAME ?= $(GIT_COMMIT_SHA).$(PUBLIC_ROOT_HOSTNAME)
PUBLIC_VERSIONED_URL ?= http://$(PUBLIC_VERSIONED_HOSTNAME)
DEPLOY_CONTAINER_NAME ?= $(PROJECT_NAME)-deploy
AWS_SECRETS ?= AWS_DEFAULT_REGION AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY
AWS_DOCKER_ENV_SECRETS ?= $(addprefix --env ,$(AWS_SECRETS))
SENTRY_SECRETS ?= SENTRY_AUTH_TOKEN SENTRY_ORG
ROLLBAR_SECRETS ?= ROLLBAR_ACCESS_TOKEN
FASTLY_SECRETS ?= FASTLY_API_KEY
DNSIMPLE_SECRETS ?= DNSIMPLE_TOKEN
ALL_ENV_SECRETS ?= $(AWS_SECRETS) $(SENTRY_SECRETS) $(ROLLBAR_SECRETS) $(FASTLY_SECRETS) $(DNSIMPLE_SECRETS)
ALL_DOCKER_ENV_SECRETS ?= $(addprefix --env ,$(ALL_ENV_SECRETS))
TERRAFORM_VAR_ARGS ?= $(addprefix -var ,'target_version=$(GIT_COMMIT_SHA)')
REPORTS_DIR ?= /reports
APP_REPORTS_DIR ?= $(REPORTS_DIR)/app
APP_COVERAGE_REPORT_DIR ?= $(APP_REPORTS_DIR)/coverage
APP_COVERAGE_LCOV_FILE ?= $(APP_COVERAGE_REPORT_DIR)/lcov.info
APP_ANALYSIS_DIR ?= $(APP_REPORTS_DIR)/lint
APP_ALLURE_DIR ?= $(APP_REPORTS_DIR)/allure
APP_ALLURE_RESULTS_DIR ?= $(APP_ALLURE_DIR)/xml
APP_ALLURE_REPORT_DIR ?= $(APP_ALLURE_DIR)/html
APP_ALLURE_REPORT_HISTORY_DIR ?= $(APP_ALLURE_REPORT_DIR)/history
E2E_REPORTS_DIR ?= $(REPORTS_DIR)/e2e
E2E_ALLURE_DIR ?= $(E2E_REPORTS_DIR)/allure
E2E_ALLURE_RESULTS_DIR ?= $(E2E_ALLURE_DIR)/xml
E2E_ALLURE_REPORT_DIR ?= $(E2E_ALLURE_DIR)/html
E2E_ALLURE_REPORT_HISTORY_DIR ?= $(E2E_ALLURE_REPORT_DIR)/history
E2E_REPORTS_SRC_DIR ?= $(DOCKER_SRC_DIR)/reports/e2e
S3_ROOT_URI ?= s3://$(PUBLIC_ROOT_HOSTNAME)
GLOBAL_APP_ALLURE_REPORT_HISTORY_S3_KEY_PREFIX ?= $(S3_ROOT_URI)/allure/app/history/
GLOBAL_E2E_ALLURE_REPORT_HISTORY_S3_KEY_PREFIX ?= $(S3_ROOT_URI)/allure/e2e/history/
BUILD_S3_KEY_PREFIX ?= $(S3_ROOT_URI)/builds/${GIT_COMMIT_SHA}/
BUILD_REPORTS_S3_KEY_PREFIX ?= $(BUILD_S3_KEY_PREFIX)reports/
RELEASE_S3_KEY_PREFIX ?= $(S3_ROOT_URI)/releases/$(GIT_COMMIT_SHA)/
TERRAFORM_DIR ?= etc/terraform
ROLLBAR_DEPLOY_COMMAND ?= GIT_COMMIT_SHA=$(GIT_COMMIT_SHA) GIT_COMMIT_AUTHOR=$(GIT_COMMIT_AUTHOR) ./bin/rollbar-deploy
E2E_COMPOSE_COMMAND ?= SELENIUM_CHROME_IMAGE=node-chrome SELENIUM_FIREFOX_IMAGE=node-firefox TEST_IMAGE=$(TEST_IMAGE) DIST_IMAGE=$(DIST_IMAGE) docker-compose
SMOKE_COMPOSE_COMMAND ?= NPM_SCRIPT=smoke-ci GIT_COMMIT_SHA=$(GIT_COMMIT_SHA) $(E2E_COMPOSE_COMMAND)
SENTRY_CLI_COMMAND ?= docker run --rm $(ALL_DOCKER_ENV_SECRETS) -v $(PWD):/work getsentry/sentry-cli

.PHONY: test-image
test-image:
	docker pull $(TEST_IMAGE) || :
	docker build --pull --cache-from $(TEST_IMAGE) $(DOCKER_BUILD_ARGS) --target $(TEST_IMAGE_BUILD_TARGET) --tag $(TEST_IMAGE) .

.PHONY: dist-image
dist-image: test-image
	docker build --pull --cache-from $(TEST_IMAGE) $(DOCKER_BUILD_ARGS) --target $(DIST_IMAGE_BUILD_TARGET) --tag $(DIST_IMAGE) .

.PHONY: test-image-push
test-image-push:
	docker push $(TEST_IMAGE)

.PHONY: dist-image-push
dist-image-push:
	docker push $(DIST_IMAGE)

.PHONY: audit
audit:
	docker run --rm $(TEST_IMAGE) npm run audit-ci

.PHONY: analysis
analysis:
	docker rm analysis-$(DOCKER_BUILD_CHECKSUM) || :
	docker run --name analysis-$(DOCKER_BUILD_CHECKSUM) $(TEST_IMAGE) npm run lint
	[[ "$(CI)" == "true" ]] && mkdir -p dirname $(PWD)$(APP_ANALYSIS_DIR) || :
	[[ "$(CI)" == "true" ]] && docker cp analysis-$(DOCKER_BUILD_CHECKSUM):$(DOCKER_SRC_DIR)$(APP_ANALYSIS_DIR) $(PWD)$(REPORTS_DIR)/ || :
	[[ "$(CI)" == "true" ]] && docker run --rm $(AWS_DOCKER_ENV_SECRETS) \
		-v $(PWD)$(REPORTS_DIR):/work --workdir /work \
		mesosphere/aws-cli s3 cp --quiet --acl private --recursive /work $(BUILD_REPORTS_S3_KEY_PREFIX) || :
	# Cleanup
	docker rm analysis-$(DOCKER_BUILD_CHECKSUM)

.PHONY: test
test:
	[[ "$(CI)" == "true" ]] && ./bin/cc-test-reporter before-build || :
	docker rm $(TEST_CONTAINER_NAME) || :
	docker run --name $(TEST_CONTAINER_NAME) \
		--env ALLURE_RESULTS_DIR=$(DOCKER_SRC_DIR)$(APP_ALLURE_RESULTS_DIR) \
		--env COVERAGE_REPORT_DIR=$(DOCKER_SRC_DIR)$(APP_COVERAGE_REPORT_DIR) \
		--security-opt seccomp=$(TEST_CONTAINER_SECCOMP_FILE) \
		$(TEST_IMAGE) /bin/bash -c 'npm run test-ci'
	# Copy the reports from the container to the host
	[[ "$(CI)" == "true" ]] && mkdir -p dirname $(PWD)$(APP_REPORTS_DIR) || :
	[[ "$(CI)" == "true" ]] && docker cp $(TEST_CONTAINER_NAME):$(DOCKER_SRC_DIR)$(APP_REPORTS_DIR) $(PWD)$(REPORTS_DIR)/ || :
	# Fetch global Allure history from S3 repository
	[[ "$(CI)" == "true" ]] && docker run --rm $(AWS_DOCKER_ENV_SECRETS) \
		-v $(PWD)$(APP_ALLURE_RESULTS_DIR)/history:/work --workdir /work \
		mesosphere/aws-cli s3 cp --quiet --recursive $(GLOBAL_APP_ALLURE_REPORT_HISTORY_S3_KEY_PREFIX) /work || :
	# Generate Allure report
	[[ "$(CI)" == "true" ]] && docker run --rm -u `id -u $$USER` \
		-v $(PWD)$(APP_ALLURE_DIR):/usr/src/allure \
			mattupstate/allure generate --clean --report-dir html xml || :
	# Copy test reports to build artifact S3 repository
	[[ "$(CI)" == "true" ]] && docker run --rm $(AWS_DOCKER_ENV_SECRETS) \
		-v $(PWD)$(REPORTS_DIR):/work --workdir /work \
		mesosphere/aws-cli s3 cp --quiet --acl private --recursive /work $(BUILD_REPORTS_S3_KEY_PREFIX) || :
	# Copy build Allure hisitory to global Allure history S3 repository
	[[ "$(CI)" == "true" ]] && docker run --rm $(AWS_DOCKER_ENV_SECRETS) \
		-v $(PWD)$(APP_ALLURE_REPORT_HISTORY_DIR):/work --workdir /work \
		mesosphere/aws-cli s3 cp --quiet --acl private --recursive /work $(GLOBAL_APP_ALLURE_REPORT_HISTORY_S3_KEY_PREFIX) || :
	[[ "$(CI)" == "true" ]] && ./bin/cc-test-reporter format-coverage -o - -t lcov -p $(DOCKER_SRC_DIR) $(PWD)$(APP_COVERAGE_LCOV_FILE) | ./bin/cc-test-reporter upload-coverage -i - || :
	# Cleanup
	docker rm $(TEST_CONTAINER_NAME)

.PHONY: smoke-test
smoke-test:
	$(SMOKE_COMPOSE_COMMAND) down || :
	$(SMOKE_COMPOSE_COMMAND) up --abort-on-container-exit --exit-code-from protractor --force-recreate --remove-orphans --quiet-pull

.PHONY: e2e
e2e:
	$(E2E_COMPOSE_COMMAND) down || :
	$(E2E_COMPOSE_COMMAND) up --abort-on-container-exit --exit-code-from protractor --force-recreate --remove-orphans --quiet-pull
	# Copy the reports from the container to the host
	[[ "$(CI)" == "true" ]] && mkdir -p dirname $(PWD)$(E2E_REPORTS_DIR) || :
	[[ "$(CI)" == "true" ]] && docker cp `docker-compose ps -q protractor 2>/dev/null`:$(DOCKER_SRC_DIR)$(E2E_REPORTS_DIR) $(PWD)$(REPORTS_DIR)/ || :
	# Fetch global Allure history from S3 repository
	[[ "$(CI)" == "true" ]] && docker run --rm $(AWS_DOCKER_ENV_SECRETS) \
		-v $(PWD)$(E2E_ALLURE_RESULTS_DIR)/history:/work --workdir /work \
		mesosphere/aws-cli s3 cp --quiet --recursive $(GLOBAL_E2E_ALLURE_REPORT_HISTORY_S3_KEY_PREFIX) /work || :
	# Generate Allure report
	[[ "$(CI)" == "true" ]] && docker run --rm -u `id -u $$USER` \
		-v $(PWD)$(E2E_ALLURE_DIR):/usr/src/allure \
			mattupstate/allure generate --clean --report-dir html xml || :
	# Copy test reports to build artifact S3 repository
	[[ "$(CI)" == "true" ]] && docker run --rm $(AWS_DOCKER_ENV_SECRETS) \
		-v $(PWD)$(REPORTS_DIR):/work --workdir /work \
		mesosphere/aws-cli s3 cp --quiet --acl private --recursive /work $(BUILD_REPORTS_S3_KEY_PREFIX)
	# Copy build Allure hisitory to global Allure history S3 repository
	[[ "$(CI)" == "true" ]] && docker run --rm $(AWS_DOCKER_ENV_SECRETS) \
		-v $(PWD)$(E2E_ALLURE_REPORT_HISTORY_DIR):/work --workdir /work \
		mesosphere/aws-cli s3 cp --quiet --acl private --recursive /work $(GLOBAL_E2E_ALLURE_REPORT_HISTORY_S3_KEY_PREFIX)
	# Cleanup
	$(E2E_COMPOSE_COMMAND) down || :

.PHONY: e2e-debug
e2e-debug:
	SELENIUM_CHROME_IMAGE=node-chrome-debug SELENIUM_FIREFOX_IMAGE=node-firefox-debug TEST_IMAGE=$(TEST_IMAGE) DIST_IMAGE=$(DIST_IMAGE) docker-compose up chrome firefox webapp

.PHONY: artifacts-deploy
artifacts-deploy:
	# Copy build artifacts from container to host
	docker rm artifacts-$(DOCKER_BUILD_CHECKSUM) || :
	docker create --name artifacts-$(DOCKER_BUILD_CHECKSUM) $(TEST_IMAGE)
	docker cp artifacts-$(DOCKER_BUILD_CHECKSUM):$(DOCKER_SRC_DIR)/dist $(PWD)/
	# Copy build artifacts to S3
	docker run --rm $(AWS_DOCKER_ENV_SECRETS) \
		-v $(PWD)/dist:/work --workdir /work \
		mesosphere/aws-cli s3 cp --quiet --acl private --recursive /work $(RELEASE_S3_KEY_PREFIX)
	# Upload source maps to Rollbar
	PUBLIC_ROOT_URL=$(PUBLIC_ROOT_URL) GIT_COMMIT_SHA=$(GIT_COMMIT_SHA) ./bin/rollbar-sourcemaps'
	# Notify Sentry of new release
	$(SENTRY_CLI_COMMAND) releases new -p angular-pipeline-example $(GIT_COMMIT_SHA)
	$(SENTRY_CLI_COMMAND) releases set-commits --auto $(GIT_COMMIT_SHA)
	$(SENTRY_CLI_COMMAND) releases finalize $(GIT_COMMIT_SHA)
	@echo "Artifacts deployed successfully"
	@echo "S3 URI: $(RELEASE_S3_KEY_PREFIX)"
	@echo "HTTP URI: $(PUBLIC_VERSIONED_URL)"

.PHONY: infra-plan
infra-plan:
	docker run --rm $(ALL_DOCKER_ENV_SECRETS) \
		-v $(PWD):/work --workdir /work \
		hashicorp/terraform init $(TERRAFORM_DIR)
	docker run --rm $(ALL_DOCKER_ENV_SECRETS) \
		-v $(PWD):/work --workdir /work \
		hashicorp/terraform plan $(TERRAFORM_VAR_ARGS) $(TERRAFORM_DIR)

.PHONY: infra-deploy
infra-deploy:
	# Notify Rollbar that deployment has started
	$(ROLLBAR_DEPLOY_COMMAND) started
	docker run --rm $(ALL_DOCKER_ENV_SECRETS) \
		-v $(PWD)$(TERRAFORM_DIR):/work --workdir /work \
		hashicorp/terraform init
	# Apply infra changes and notify Rollbar and Sentry on success
	docker run --rm $(ALL_DOCKER_ENV_SECRETS) \
		-v $(PWD)$(TERRAFORM_DIR):/work --workdir /work \
		hashicorp/terraform apply -auto-approve $(TERRAFORM_VAR_ARGS) \
		&& $(SENTRY_CLI_COMMAND) releases deploys $(GIT_COMMIT_SHA) new -e production \
		&& $(ROLLBAR_DEPLOY_COMMAND) succeeded \
		|| $(ROLLBAR_DEPLOY_COMMAND) failed
	@echo "Infrastructure deployed successfully"
	@echo "HTTP URI: $(PUBLIC_ROOT_URL)"

