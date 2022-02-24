# Copyright 2020-2021 Dave Verwer, Sven A. Schmidt, and other contributors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

SHELL=bash
DOCKER_IMAGE=registry.gitlab.com/finestructure/swiftpackageindex

ifndef VERSION
	export VERSION=$(shell git rev-parse HEAD)
	WARN_VERSION=true
endif

version:
ifeq ($(WARN_VERSION), true)
	$(info No VERSION provided, defaulting to $(VERSION))
else
	$(info VERSION: $(VERSION))
endif

build:
	swift build --disable-automatic-resolution

run:
	swift run

test: xcbeautify
	set -o pipefail \
	&& env RUN_IMAGE_SNAPSHOT_TESTS=true \
	   swift test --enable-code-coverage --disable-automatic-resolution --sanitize=thread \
	2>&1 | ./xcbeautify

test-without-tsan: xcbeautify
	set -o pipefail \
	&& env RUN_IMAGE_SNAPSHOT_TESTS=true \
	   swift test --enable-code-coverage --disable-automatic-resolution \
	2>&1 | ./xcbeautify

test-query-performance:
	set -o pipefail \
	&& env RUN_QUERY_PERFORMANCE_TESTS=true \
	   swift test --enable-code-coverage --disable-automatic-resolution \
	   --filter QueryPerformanceTests

test-fast:
	@echo Skipping image snapshot tests
	@echo Running without --sanitize=thread
	swift test --disable-automatic-resolution

xcbeautify:
	rm -rf .build/checkouts/xcbeautify
	git clone --depth=1 https://github.com/thii/xcbeautify.git .build/checkouts/xcbeautify
	cd .build/checkouts/xcbeautify && make build
	binpath=`cd .build/checkouts/xcbeautify && swift build -c release --show-bin-path` && ln -sf $$binpath/xcbeautify

docker-build: version
	docker build -t $(DOCKER_IMAGE):$(VERSION) .

docker-push:
	docker push $(DOCKER_IMAGE):$(VERSION)

test-docker:
	@# run tests inside a docker container
	docker run --rm -v "$(PWD)":/host -w /host \
	  --add-host=host.docker.internal:host-gateway \
	  registry.gitlab.com/finestructure/spi-base:0.6.4 \
	  make test

test-e2e: db-reset reconcile ingest analyze
	@# run import sequence test

migrate:
	echo y | swift run Run migrate

revert:
	swift run Run migrate --revert

routes:
	swift run Run routes

reconcile:
	swift run Run reconcile

ingest:
	swift run Run ingest --limit 1

analyze:
	swift run Run analyze --limit 1

db-up: db-up-dev db-up-test

db-up-dev:
	docker run --name spi_dev -e POSTGRES_DB=spi_dev -e POSTGRES_USER=spi_dev -e POSTGRES_PASSWORD=xxx -p 6432:5432 -d postgres:13.5-alpine

db-up-test:
	docker run --name spi_test \
		-e POSTGRES_DB=spi_test \
		-e POSTGRES_USER=spi_test \
		-e POSTGRES_PASSWORD=xxx \
		-e PGDATA=/pgdata \
		--tmpfs /pgdata:rw,noexec,nosuid,size=1024m \
		-p 5432:5432 \
		-d \
		postgres:13.5-alpine

db-up-test-log-statement:
	docker run --name spi_test \
		-e POSTGRES_DB=spi_test \
		-e POSTGRES_USER=spi_test \
		-e POSTGRES_PASSWORD=xxx \
		-e PGDATA=/pgdata \
		--tmpfs /pgdata:rw,noexec,nosuid,size=1024m \
		-p 5432:5432 \
		--rm \
		postgres:13.5-alpine \
		postgres -c log_statement=all

db-down: db-down-dev db-down-test

db-down-dev:
	docker rm -f spi_dev

db-down-test:
	docker rm -f spi_test

db-reset: db-down db-up migrate

build-front-end:
	docker run --rm -it -v $$PWD:/host -w /host --entrypoint sh node:16-alpine -c "/usr/local/bin/yarn && /usr/local/bin/yarn build"

serve-front-end:
	docker run --rm -it -v $$PWD:/host -w /host --entrypoint sh node:16-alpine -c "/usr/local/bin/yarn && /usr/local/bin/yarn serve"

copy-front-end-resources:
	@# copy front-end resources from existing image (rather than build them)
	docker run --rm -it -v $$PWD:/host -w /host --entrypoint sh registry.gitlab.com/finestructure/swiftpackageindex:$(VERSION) -c "cp -r /run/Public ."
