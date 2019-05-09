SHELL := /bin/bash
CI_SCRIPTS = $(subst ./bin/ci-,,$(shell find ./bin/ci-* -type f))
export CI ?= false
export PROJECT_NAME ?= $(shell jq -r '.name' package.json)
export GIT_COMMIT_SHA ?= $(shell git rev-parse --verify HEAD)
export GIT_COMMITED_AT ?= $(shell git show -s --format=%at HEAD)
export GIT_BRANCH ?= $(shell git rev-parse --abbrev-ref HEAD)
export GIT_IS_DIRTY ?= $(shell git diff --quiet && echo "false" || echo "true")
export DOCKER_BUILD_CHECKSUM ?= $(shell ./bin/md5 package-lock.json Dockerfile)
export DOCKER_BUILD_ARGS ?= $(addprefix --build-arg ,app_src_dir=/usr/src/app git_branch=$(GIT_BRANCH) git_commit_sha=$(GIT_COMMIT_SHA) git_is_dirty=$(GIT_IS_DIRTY))
export DOCKER_IMAGE_BASE_NAME ?= mattupstate/$(PROJECT_NAME)
export TEST_IMAGE ?= $(DOCKER_IMAGE_BASE_NAME):test-$(DOCKER_BUILD_CHECKSUM)
export TEST_CONTAINER_NAME ?= test-${DOCKER_BUILD_CHECKSUM}
export ANALYSIS_CONTAINER_NAME ?= analysis-${DOCKER_BUILD_CHECKSUM}
export DIST_IMAGE ?= $(DOCKER_IMAGE_BASE_NAME):$(GIT_COMMIT_SHA)
export PUBLIC_ROOT_HOSTNAME ?= $(PROJECT_NAME).mattupstate.com
export PUBLIC_ROOT_URL ?= http://$(PUBLIC_ROOT_HOSTNAME)/
export PUBLIC_VERSIONED_ROOT_URL ?= http://$(GIT_COMMIT_SHA).$(PUBLIC_ROOT_HOSTNAME)/
export S3_ROOT_URI ?= s3://$(PUBLIC_ROOT_HOSTNAME)
export MASTER_BUILD_S3_KEY_PREFIX ?= $(S3_ROOT_URI)/builds/master/
export RELEASE_S3_KEY_PREFIX ?= $(S3_ROOT_URI)/releases/$(GIT_COMMIT_SHA)/
export BUILD_S3_KEY_PREFIX ?= $(S3_ROOT_URI)/builds/${GIT_COMMIT_SHA}/

ifeq ($(CI),true)
	DOCKER_CACHE_FROM ?= --cache-from $(TEST_IMAGE)
endif

.PHONY: test-image
test-image:
	docker pull $(TEST_IMAGE) || :
	docker build --pull $(DOCKER_CACHE_FROM) $(DOCKER_BUILD_ARGS) --target test --tag $(TEST_IMAGE) .

.PHONY: dist-image
dist-image: test-image
	docker build --pull $(DOCKER_CACHE_FROM) $(DOCKER_BUILD_ARGS) --target dist --tag $(DIST_IMAGE) .

.PHONY: test-image-push
test-image-push:
	docker push $(TEST_IMAGE)

.PHONY: dist-image-push
dist-image-push:
	docker push $(DIST_IMAGE)

.PHONY: $(CI_SCRIPTS)
$(CI_SCRIPTS):
	./bin/ci-$(@)

.PHONY: e2e-debug
e2e-debug:
	SELENIUM_CHROME_IMAGE=node-chrome-debug \
	SELENIUM_FIREFOX_IMAGE=node-firefox-debug \
		docker-compose up chrome firefox webapp
