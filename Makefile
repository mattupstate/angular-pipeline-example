SHELL := /bin/bash
PROJECT_NAME ?= $(shell jq -r '.name' package.json)
PROJECT_VERSION ?= $(shell jq -r '.version' package.json)
TEST_DOCKER_SECCOMP_FILE ?= etc/docker/seccomp/chrome.json
TEST_DOCKER_TARGET ?= test
TEST_DOCKER_IMAGE_TAG ?= test
TEST_CONTAINER_NAME ?= $(PROJECT_NAME)-test
ANALYSIS_CONTAINER_NAME ?= $(PROJECT_NAME)-analysis
AUDIT_CONTAINER_NAME ?= $(PROJECT_NAME)-audit
export TEST_DOCKER_IMAGE ?= $(PROJECT_NAME):$(TEST_DOCKER_IMAGE_TAG)
DIST_DOCKER_TARGET ?= dist
DIST_DOCKER_IMAGE_TAG ?= $(PROJECT_VERSION)
DIST_ARCHIVE_FILE ?= dist.tar
DIST_ARCHIVE_CONTAINER_NAME ?= $(PROJECT_NAME)-dist
DIST_ARCHIVE_SRC_DIR ?= /usr/share/app/dist
REPORTS_DIR ?= ./reports
COVERAGE_DIR ?= $(REPORTS_DIR)/coverage
COVERAGE_SRC_DIR ?= /usr/src/app/reports/coverage
ANALYSIS_DIR ?= $(REPORTS_DIR)/lint
ANALSYS_SRC_DIR ?= /usr/src/app/reports/lint
export DIST_DOCKER_IMAGE ?= $(PROJECT_NAME):$(DIST_DOCKER_IMAGE_TAG)
DIST_DOCKER_PUSH_PREFIX ?= mattupstate/
DIST_DOCKER_PUSH_IMAGE ?= $(DIST_DOCKER_PUSH_PREFIX)$(DIST_DOCKER_IMAGE)

.PHONY: test-image
test-image:
	docker build --pull --quiet --target $(TEST_DOCKER_TARGET) --tag $(TEST_DOCKER_IMAGE) .

.PHONY: dist-image
dist-image:
	docker build --pull --quiet --target $(DIST_DOCKER_TARGET) --tag $(DIST_DOCKER_IMAGE) .

.PHONY: dist-archive
dist-archive: dist-image
	docker rm $(DIST_ARCHIVE_CONTAINER_NAME) 2&>/dev/null || :
	docker create --name $(DIST_ARCHIVE_CONTAINER_NAME) $(DIST_DOCKER_IMAGE)
	docker cp $(DIST_ARCHIVE_CONTAINER_NAME):$(DIST_ARCHIVE_SRC_DIR) - > $(DIST_ARCHIVE_FILE)

.PHONY: audit
audit: test-image
	docker rm $(AUDIT_CONTAINER_NAME) 2&>/dev/null || :
	docker run --name $(AUDIT_CONTAINER_NAME) $(TEST_DOCKER_IMAGE) npm run audit-ci

.PHONY: analysis
analysis: test-image
	docker rm $(ANALYSIS_CONTAINER_NAME) 2&>/dev/null || :
	rm -rf $(ANALYSIS_DIR)
	mkdir -p $(ANALYSIS_DIR)
	docker run --name $(ANALYSIS_CONTAINER_NAME) $(TEST_DOCKER_IMAGE) npm run lint-ci
	docker cp $(ANALYSIS_CONTAINER_NAME):$(ANALSYS_SRC_DIR) $(ANALYSIS_DIR)

.PHONY: test
test: test-image
	docker rm $(TEST_CONTAINER_NAME) 2&>/dev/null || :
	rm -rf $(COVERAGE_DIR)
	mkdir -p $(COVERAGE_DIR)
	docker run --name $(TEST_CONTAINER_NAME) --security-opt seccomp=$(TEST_DOCKER_SECCOMP_FILE) $(TEST_DOCKER_IMAGE) npm run test-ci
	docker cp $(TEST_CONTAINER_NAME):$(COVERAGE_SRC_DIR) $(COVERAGE_DIR)

.PHONY: e2e
e2e: test-image dist-image
	docker-compose down || :
	SELENIUM_CHROME_IMAGE=node-chrome SELENIUM_FIREFOX_IMAGE=node-firefox docker-compose up --exit-code-from protractor --force-recreate --remove-orphans --quiet-pull

.PHONY: e2e-debug
e2e-debug: dist-image
	SELENIUM_CHROME_IMAGE=node-chrome-debug SELENIUM_FIREFOX_IMAGE=node-firefox-debug docker-compose up chrome firefox webapp

.PHONY: build
build: test analysis audit e2e
	@echo "Build completed:"
	@echo "DOCKER_IMAGE=$(DIST_DOCKER_IMAGE)"

.PHONY: publish-image
publish-image: build
	docker tag $(DIST_DOCKER_IMAGE) $(DIST_DOCKER_PUSH_IMAGE)
	docker push $(DIST_DOCKER_PUSH_IMAGE)
