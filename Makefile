VAPOR=vapor-beta
DOCKER_IMAGE=finestructure/spi-server

build:
	$(VAPOR) build

run:
	$(VAPOR) run

test:
	swift test --enable-test-discovery --enable-code-coverage

build-docker:
	docker-compose build

push:
	docker push $(DOCKER_IMAGE)

test-docker:
	@# run tests inside a docker container
	docker run --rm -v $(PWD):/host -w /host --network="host" swift:5.2.3-bionic make test

test-e2e: reset reconcile ingest
	@# run import sequence test

migrate:
	$(VAPOR) run migrate

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
	docker run --name spi_dev -e POSTGRES_DB=spi_dev -e POSTGRES_USER=spi_dev -e POSTGRES_PASSWORD=xxx -p 6432:5432 -d postgres

db-up-test:
	docker run --name spi_test -e POSTGRES_DB=spi_test -e POSTGRES_USER=spi_test -e POSTGRES_PASSWORD=xxx -p 5432:5432 -d postgres

db-down: db-down-dev db-down-test

db-down-dev:
	docker rm -f spi_dev

db-down-test:
	docker rm -f spi_test

reset: db-down-dev db-up-dev migrate
	@# reset dev db (test db is automatically reset by tests)

