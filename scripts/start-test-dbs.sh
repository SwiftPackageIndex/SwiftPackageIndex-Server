#!/usr/bin/env bash

docker network create -d bridge spi_test

for port in {0..7}; do
    docker run --name "spi_test_$port" \
        -e POSTGRES_DB=spi_test \
        -e POSTGRES_USER=spi_test \
        -e POSTGRES_PASSWORD=xxx \
        -e PGDATA=/pgdata \
        --tmpfs /pgdata:rw,noexec,nosuid,size=1024m \
        --network spi_test \
        -d \
        postgres:13-alpine
done
