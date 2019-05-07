SHELL := /bin/bash
export CI ?= false
export PROJECT_NAME ?= $(shell jq -r '.name' package.json)
export GIT_COMMIT_SHA ?= $(shell git rev-parse --verify HEAD)
export GIT_BRANCH ?= $(shell git rev-parse --abbrev-ref HEAD)
export GIT_IS_DIRTY ?= $(shell git diff --quiet && echo "false" || echo "true")
export DOCKER_BUILD_CHECKSUM ?= $(shell ./bin/md5 package-lock.json Dockerfile)
export DOCKER_BUILD_ARGS ?= $(addprefix --build-arg ,app_src_dir=/usr/src/app git_branch=$(GIT_BRANCH) git_commit_sha=$(GIT_COMMIT_SHA) git_is_dirty=$(GIT_IS_DIRTY))
export DOCKER_IMAGE_BASE_NAME ?= mattupstate/$(PROJECT_NAME)
export TEST_IMAGE ?= $(DOCKER_IMAGE_BASE_NAME):test-$(DOCKER_BUILD_CHECKSUM)
export DIST_IMAGE ?= $(DOCKER_IMAGE_BASE_NAME):$(GIT_COMMIT_SHA)
export PUBLIC_ROOT_HOSTNAME ?= $(PROJECT_NAME).mattupstate.com
export PUBLIC_ROOT_URL ?= http://$(PUBLIC_ROOT_HOSTNAME)/
export PUBLIC_VERSIONED_ROOT_URL ?= http://$(GIT_COMMIT_SHA).$(PUBLIC_ROOT_HOSTNAME)/
export S3_ROOT_URI ?= s3://$(PUBLIC_ROOT_HOSTNAME)
export GLOBAL_ALLURE_HISTORY_S3_KEY_PREFIX ?= $(S3_ROOT_URI)/allure/history/
export RELEASE_S3_KEY_PREFIX ?= $(S3_ROOT_URI)/releases/$(GIT_COMMIT_SHA)/
export BUILD_S3_KEY_PREFIX ?= $(S3_ROOT_URI)/builds/${GIT_COMMIT_SHA}/

.PHONY: test-image
test-image:
	docker pull $(TEST_IMAGE) || :
	docker build --pull --cache-from $(TEST_IMAGE) $(DOCKER_BUILD_ARGS) --target test --tag $(TEST_IMAGE) .

.PHONY: dist-image
dist-image: test-image
	docker build --pull --cache-from $(TEST_IMAGE) $(DOCKER_BUILD_ARGS) --target dist --tag $(DIST_IMAGE) .

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
	./bin/ci-analysis

.PHONY: test
test:
	./bin/ci-test

.PHONY: smoke-test
smoke-test:
	./bin/ci-smoke

.PHONY: e2e
e2e:
	./bin/ci-e2e

.PHONY: e2e-debug
e2e-debug:
	SELENIUM_CHROME_IMAGE=node-chrome-debug \
	SELENIUM_FIREFOX_IMAGE=node-firefox-debug \
		docker-compose up chrome firefox webapp

.PHONY: artifacts-deploy
artifacts-deploy:
	./bin/ci-artifacts-deploy
	@echo "Artifacts deployed successfully"
	@echo "S3 URI: $(RELEASE_S3_KEY_PREFIX)"
	@echo "HTTP URI: $(PUBLIC_VERSIONED_ROOT_URL)"

.PHONY: infra-plan
infra-plan:
	./bin/ci-infra-plan

.PHONY: infra-deploy
infra-deploy:
	./bin/ci-infra-deploy
	@echo "Infrastructure deployed successfully"
	@echo "HTTP URI: $(PUBLIC_ROOT_URL)"

