VAPOR=vapor-beta

build:
	$(VAPOR) build

run:
	$(VAPOR) run

migrate:
	$(VAPOR) run migrate

revert:
	$(VAPOR) run migrate --revert

routes:
	$(VAPOR) run routes

ingest:
	$(VAPOR) run ingest

db-up:
	docker run --name spi_dev -e POSTGRES_DB=spi_dev -e POSTGRES_USER=spi_dev -e POSTGRES_PASSWORD=xxx -p 5432:5432 -d postgres

db-down:
	docker rm -f spi_dev

db-reset: db-down db-up

