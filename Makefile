VAPOR=vapor-beta

build:
	$(VAPOR) build

run:
	$(VAPOR) run

db-up:
	docker run --name spmidx_dev -e POSTGRES_DB=spmidx_dev -e POSTGRES_USER=spmidx_dev -e POSTGRES_PASSWORD=xxx -p 5432:5432 -d postgres

db-down:
	docker rm -f spmidx_dev

migrate:
	$(VAPOR) run migrate

db-reset: db-down db-up
