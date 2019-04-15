SHELL := /bin/bash
CI ?= false
PROJECT_NAME ?= $(shell jq -r '.name' package.json)
PROJECT_VERSION ?= $(shell jq -r '.version' package.json)
GIT_COMMIT_SHA ?= $(shell git rev-parse --verify --short HEAD)
GIT_BRANCH ?= $(shell git rev-parse --abbrev-ref HEAD)
GIT_IS_DIRTY ?= $(shell git diff --quiet && echo "false" || echo "true")
DOCKER_BUILD_ARGS ?= $(addprefix --build-arg ,git_branch=$(GIT_BRANCH) git_commit_sha=$(GIT_COMMIT_SHA) git_is_dirty=$(GIT_IS_DIRTY))
IMAGE_BASE_NAME ?= mattupstate/$(PROJECT_NAME)
TEST_IMAGE ?= $(IMAGE_BASE_NAME):$(GIT_COMMIT_SHA)-test
TEST_IMAGE_BUILD_TARGET ?= test
TEST_CONTAINER_NAME ?= $(PROJECT_NAME)-test
TEST_CONTAINER_SECCOMP_FILE ?= etc/docker/seccomp/chrome.json
TEST_CONTAINER_SRC_DIR ?= /usr/src/app
ANALYSIS_CONTAINER_NAME ?= $(PROJECT_NAME)-analysis
AUDIT_CONTAINER_NAME ?= $(PROJECT_NAME)-audit
DIST_IMAGE_BUILD_TARGET ?= dist
DIST_IMAGE_NAME_VERSIONED ?= $(IMAGE_BASE_NAME):$(PROJECT_VERSION)
DIST_IMAGE_NAME_HASHED ?= $(IMAGE_BASE_NAME):$(GIT_COMMIT_SHA)
DIST_IMAGE ?= $(IMAGE_BASE_NAME):$(GIT_COMMIT_SHA)
DIST_ARCHIVE_FILENAME ?= dist.tar
DIST_ARCHIVE_CONTAINER_NAME ?= $(PROJECT_NAME)-dist
DIST_ARCHIVE_SRC_DIR ?= /usr/share/app/dist
DEPLOY_CONTAINER_NAME ?= $(PROJECT_NAME)-deploy
DEPLOY_IMAGE_BUILD_TARGET ?= deploy
DEPLOY_ENV_ARGS ?= $(addprefix --env ,FASTLY_API_KEY DNSIMPLE_TOKEN DNSIMPLE_ACCOUNT AWS_REGION AWS_DEFAULT_REGION AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY)
DEPLOY_IMAGE ?= $(IMAGE_BASE_NAME):$(GIT_COMMIT_SHA)-deploy
DEPLOY_BUCKET_NAME ?= angular-pipeline-example.mattupstate.com
S3_KEY_PREFIX_URI ?= s3://$(DEPLOY_BUCKET_NAME)/$(GIT_COMMIT_SHA)/
PUBLIC_ROOT_HOSTNAME ?= angular-pipeline-example.mattupstate.com
PUBLIC_VERSIONED_HOSTNAME ?= $(GIT_COMMIT_SHA).$(PUBLIC_ROOT_HOSTNAME)
ENV_FILE ?= .envrc
REPORTS_DIR ?= ./reports
E2E_REPORTS_DIR ?= $(REPORTS_DIR)/e2e
COVERAGE_DIR ?= $(REPORTS_DIR)/coverage
ANALYSIS_DIR ?= $(REPORTS_DIR)/lint
LCOV_FILE ?= $(COVERAGE_DIR)/lcov.info
COVERAGE_SRC_DIR ?= $(TEST_CONTAINER_SRC_DIR)/reports/coverage
E2E_REPORTS_SRC_DIR ?= $(TEST_CONTAINER_SRC_DIR)/reports/e2e

.PHONY: test-image
test-image:
	docker build --pull --quiet $(DOCKER_BUILD_ARGS) --target $(TEST_IMAGE_BUILD_TARGET) --tag $(TEST_IMAGE) .

.PHONY: dist-image
dist-image:
	docker build --pull --quiet $(DOCKER_BUILD_ARGS) --target $(DIST_IMAGE_BUILD_TARGET) --tag $(DIST_IMAGE) .

.PHONY: deploy-image
deploy-image:
	docker build --pull --quiet $(DOCKER_BUILD_ARGS) --target $(DEPLOY_IMAGE_BUILD_TARGET) --tag $(DEPLOY_IMAGE) .

.PHONY: dist-archive
dist-archive: dist-image
	@docker rm $(DIST_ARCHIVE_CONTAINER_NAME) 2&>/dev/null || :
	docker create --name $(DIST_ARCHIVE_CONTAINER_NAME) $(DIST_IMAGE)
	docker cp $(DIST_ARCHIVE_CONTAINER_NAME):$(DIST_ARCHIVE_SRC_DIR) - > $(DIST_ARCHIVE_FILENAME)

.PHONY: audit
audit: test-image
	@docker rm $(AUDIT_CONTAINER_NAME) 2&>/dev/null || :
	# docker run --name $(AUDIT_CONTAINER_NAME) $(TEST_IMAGE) npm run audit-ci

.PHONY: analysis
analysis: test-image
	@docker rm $(ANALYSIS_CONTAINER_NAME) 2&>/dev/null || :
	rm -rf $(ANALYSIS_DIR)
	mkdir -p $(dir $(ANALYSIS_DIR))
	docker run --name $(ANALYSIS_CONTAINER_NAME) $(TEST_IMAGE) npm run lint

.PHONY: test
test: test-image
	@docker rm $(TEST_CONTAINER_NAME) 2&>/dev/null || :
	rm -rf $(COVERAGE_DIR)
	mkdir -p $(dir $(COVERAGE_DIR))
	[[ "$(CI)" == "true" ]] && ./bin/cc-test-reporter before-build || :
	docker run --name $(TEST_CONTAINER_NAME) --security-opt seccomp=$(TEST_CONTAINER_SECCOMP_FILE) $(TEST_IMAGE) npm run test-ci
	docker cp $(TEST_CONTAINER_NAME):$(COVERAGE_SRC_DIR) $(COVERAGE_DIR)
	[[ "$(CI)" == "true" ]] && ./bin/cc-test-reporter format-coverage -o - -t lcov -p $(TEST_CONTAINER_SRC_DIR) $(COVERAGE_DIR)/lcov.info | ./bin/cc-test-reporter upload-coverage -i - || :

.PHONY: e2e
e2e: test-image dist-image
	rm -rf $(E2E_REPORTS_DIR)
	mkdir -p $(dir $(E2E_REPORTS_DIR))
	SELENIUM_CHROME_IMAGE=node-chrome SELENIUM_FIREFOX_IMAGE=node-firefox TEST_IMAGE=$(TEST_IMAGE) DIST_IMAGE=$(DIST_IMAGE) docker-compose down || :
	SELENIUM_CHROME_IMAGE=node-chrome SELENIUM_FIREFOX_IMAGE=node-firefox TEST_IMAGE=$(TEST_IMAGE) DIST_IMAGE=$(DIST_IMAGE) docker-compose up --abort-on-container-exit --exit-code-from protractor --force-recreate --remove-orphans --quiet-pull
	docker cp $$(SELENIUM_CHROME_IMAGE=node-chrome SELENIUM_FIREFOX_IMAGE=node-firefox TEST_IMAGE=$(TEST_IMAGE) DIST_IMAGE=$(DIST_IMAGE) docker-compose ps -q protractor):$(E2E_REPORTS_SRC_DIR) $(E2E_REPORTS_DIR)

.PHONY: e2e-debug
e2e-debug: dist-image
	SELENIUM_CHROME_IMAGE=node-chrome-debug SELENIUM_FIREFOX_IMAGE=node-firefox-debug TEST_IMAGE=$(TEST_IMAGE) DIST_IMAGE=$(DIST_IMAGE) docker-compose up chrome firefox webapp

.PHONY: build
build: test analysis audit e2e
	@echo "Build completed:"
	@echo "DOCKER_IMAGE=$(DIST_IMAGE)"

.PHONY: dist-image-push
dist-image-push:
	docker tag $(DIST_IMAGE) $(DIST_IMAGE_NAME_VERSIONED)
	docker tag $(DIST_IMAGE) $(DIST_IMAGE_NAME_HASHED)
	docker push $(DIST_IMAGE_NAME_VERSIONED)
	docker push $(DIST_IMAGE_NAME_HASHED)

.PHONY: artifacts-deploy
artifacts-deploy: deploy-image
	docker run --rm --name $(DEPLOY_CONTAINER_NAME) $(DEPLOY_ENV_ARGS) $(DEPLOY_IMAGE) aws s3 cp --acl public-read --recursive ./dist $(S3_KEY_PREFIX_URI)
	@echo "Artifacts deployed successfully"
	@echo "S3 URI: $(S3_KEY_PREFIX_URI)
	@echo "HTTP URI: http://$(PUBLIC_VERSIONED_HOSTNAME)

.PHONY: infra-plan
infra-plan: deploy-image
	docker run --rm --name $(DEPLOY_CONTAINER_NAME) $(DEPLOY_ENV_ARGS) $(DEPLOY_IMAGE) /bin/bash -c 'terraform init ./terraform && terraform plan -var 'target_version=$(GIT_COMMIT_SHA)' ./terraform'

.PHONY: infra-deploy
infra-deploy: deploy-image
	docker run --rm --name $(DEPLOY_CONTAINER_NAME) $(DEPLOY_ENV_ARGS) $(DEPLOY_IMAGE) /bin/bash -c 'terraform init ./terraform && terraform apply -var 'target_version=$(GIT_COMMIT_SHA)' ./terraform'
	@echo "Infrastructure deployed successfully"
	@echo "HTTP URI: http://$(DEPLOY_BUCKET_NAME)
