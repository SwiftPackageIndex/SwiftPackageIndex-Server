#!/usr/bin/env bash

for port in {6000..6007}; do
    docker run --name "spi_test_$port" \
        -e POSTGRES_DB=spi_test \
        -e POSTGRES_USER=spi_test \
        -e POSTGRES_PASSWORD=xxx \
        -e PGDATA=/pgdata \
        --tmpfs /pgdata:rw,noexec,nosuid,size=1024m \
        -p "$port":5432 \
        -d \
        postgres:16-alpine
done
