SHELL := /bin/bash
PROJECT_NAME ?= $(shell jq -r '.name' package.json)
PROJECT_VERSION ?= $(shell jq -r '.version' package.json)
export GIT_BRANCH ?= $(shell git rev-parse --abbrev-ref HEAD)
export GIT_COMMIT_SHA ?= $(shell git rev-parse --verify HEAD)
export GIT_COMMIT_SHORT_SHA ?= $(shell git rev-parse --verify --short HEAD)
DOCKER_IMAGE_BASE_NAME ?= mattupstate/$(PROJECT_NAME)
TEST_DOCKER_SECCOMP_FILE ?= etc/docker/seccomp/chrome.json
TEST_DOCKER_TARGET ?= test
export TEST_DOCKER_IMAGE ?= $(DOCKER_IMAGE_BASE_NAME):$(GIT_BRANCH)-test
TEST_CONTAINER_NAME ?= $(PROJECT_NAME)-test
ANALYSIS_CONTAINER_NAME ?= $(PROJECT_NAME)-analysis
AUDIT_CONTAINER_NAME ?= $(PROJECT_NAME)-audit
DIST_DOCKER_TARGET ?= dist
DIST_VERSIONED_DOCKER_IMAGE ?= $(DOCKER_IMAGE_BASE_NAME):$(PROJECT_VERSION)
DIST_HASHED_DOCKER_IMAGE ?= $(DOCKER_IMAGE_BASE_NAME):$(GIT_COMMIT_SHORT_SHA)
export DIST_DOCKER_IMAGE ?= $(DOCKER_IMAGE_BASE_NAME):$(GIT_BRANCH)
DIST_ARCHIVE_FILE ?= dist.tar
DIST_ARCHIVE_CONTAINER_NAME ?= $(PROJECT_NAME)-dist
DIST_ARCHIVE_SRC_DIR ?= /usr/share/app/dist
REPORTS_DIR ?= ./reports
COVERAGE_DIR ?= $(REPORTS_DIR)/coverage
LCOV_FILE ?= $(COVERAGE_DIR)/lcov.info
COVERAGE_SRC_DIR ?= /usr/src/app/reports/coverage
ANALYSIS_DIR ?= $(REPORTS_DIR)/lint
ANALSYS_SRC_DIR ?= /usr/src/app/reports/lint

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
	mkdir -p $$(dirname $(ANALYSIS_DIR))
	docker run --name $(ANALYSIS_CONTAINER_NAME) $(TEST_DOCKER_IMAGE) npm run lint-ci
	docker cp $(ANALYSIS_CONTAINER_NAME):$(ANALSYS_SRC_DIR) $(ANALYSIS_DIR)

.PHONY: test
test: test-image
	docker rm $(TEST_CONTAINER_NAME) 2&>/dev/null || :
	rm -rf $(COVERAGE_DIR)
	mkdir -p $$(dirname $(COVERAGE_DIR))
	[[ "$$CI" == "true" ]] && ./bin/cc-test-reporter before-build || :
	docker run --name $(TEST_CONTAINER_NAME) --security-opt seccomp=$(TEST_DOCKER_SECCOMP_FILE) $(TEST_DOCKER_IMAGE) npm run test-ci
	docker cp $(TEST_CONTAINER_NAME):$(COVERAGE_SRC_DIR) $(COVERAGE_DIR)
	[[ "$$CI" == "true" ]] && ./bin/cc-test-reporter format-coverage -o - -t lcov -p /usr/src/app $(COVERAGE_DIR)/lcov.info | ./bin/cc-test-reporter upload-coverage -i - || :

.PHONY: e2e
e2e: test-image dist-image
	SELENIUM_CHROME_IMAGE=node-chrome SELENIUM_FIREFOX_IMAGE=node-firefox docker-compose down || :
	SELENIUM_CHROME_IMAGE=node-chrome SELENIUM_FIREFOX_IMAGE=node-firefox docker-compose up --abort-on-container-exit --exit-code-from protractor --force-recreate --remove-orphans --quiet-pull

.PHONY: e2e-debug
e2e-debug: dist-image
	SELENIUM_CHROME_IMAGE=node-chrome-debug SELENIUM_FIREFOX_IMAGE=node-firefox-debug docker-compose up chrome firefox webapp

.PHONY: build
build: test analysis audit e2e
	@echo "Build completed:"
	@echo "DOCKER_IMAGE=$(DIST_DOCKER_IMAGE)"

.PHONY: publish-image
publish-image:
	docker tag $(DIST_DOCKER_IMAGE) $(DIST_VERSIONED_DOCKER_IMAGE)
	docker tag $(DIST_DOCKER_IMAGE) $(DIST_HASHED_DOCKER_IMAGE)
	docker push $(DIST_VERSIONED_DOCKER_IMAGE)
	docker push $(DIST_HASHED_DOCKER_IMAGE)
