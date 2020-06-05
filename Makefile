VAPOR=vapor-beta
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
	$(VAPOR) build

run:
	$(VAPOR) run

test:
	swift test --enable-test-discovery --enable-code-coverage

docker-build: version
	docker build -t $(DOCKER_IMAGE):$(VERSION) .

docker-push:
	docker push $(DOCKER_IMAGE):$(VERSION)

test-docker:
	@# run tests inside a docker container
	docker run --rm -v $(PWD):/host -w /host --network="host" swift:5.2.4-bionic \
	  bash -c "apt-get update && apt-get install -y unzip && make test"

test-e2e: db-reset reconcile ingest analyze
	@# run import sequence test

migrate:
	echo y | $(VAPOR) run migrate

revert:
	$(VAPOR) run migrate --revert

routes:
	$(VAPOR) run routes

reconcile:
	$(VAPOR) run reconcile

ingest:
	$(VAPOR) run ingest --limit 1

analyze:
	$(VAPOR) run analyze --limit 1

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
