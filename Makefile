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
	swift build

run:
	swift run

test:
	swift test --enable-test-discovery --enable-code-coverage

docker-build: version
	docker build -t $(DOCKER_IMAGE):$(VERSION) .

docker-push:
	docker push $(DOCKER_IMAGE):$(VERSION)

test-docker:
	@# run tests inside a docker container
	docker run --rm -v "$(PWD)":/host -w /host --network="host" finestructure/spi-base:0.2.0 \
	  bash -c "apt-get update && apt-get install -y unzip && make test"

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
	docker run --name spi_dev -e POSTGRES_DB=spi_dev -e POSTGRES_USER=spi_dev -e POSTGRES_PASSWORD=xxx -p 6432:5432 -d postgres:12.1-alpine

db-up-test:
	docker run --name spi_test \
		-e POSTGRES_DB=spi_test \
		-e POSTGRES_USER=spi_test \
		-e POSTGRES_PASSWORD=xxx \
		-e PGDATA=/pgdata \
		--tmpfs /pgdata:rw,noexec,nosuid,size=1024m \
		-p 5432:5432 \
		-d \
		postgres:12.1-alpine

db-down: db-down-dev db-down-test

db-down-dev:
	docker rm -f spi_dev

db-down-test:
	docker rm -f spi_test

db-reset: db-down db-up migrate

build-front-end:
	docker run --rm -it -v $$PWD:/host -w /host --entrypoint sh node:15.8-alpine /usr/local/bin/yarn && /usr/local/bin/yarn build

serve-front-end:
	docker run --rm -it -v $$PWD:/host -w /host --entrypoint sh node:15.8-alpine /usr/local/bin/yarn && /usr/local/bin/yarn serve
