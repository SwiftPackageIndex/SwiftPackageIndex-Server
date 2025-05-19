#!/usr/bin/env bash

# Sets up the databases the same way we do in ci.yml
# - no ports exposed
# - connected to a bridge network
# Tests need to be run from a container attached to the same network.

docker network create -d bridge spi_test 2> /dev/null

for port in {0..7}; do
    docker run --name "spi_test_$port" \
        -e POSTGRES_DB=spi_test \
        -e POSTGRES_USER=spi_test \
        -e POSTGRES_PASSWORD=xxx \
        -e POSTGRES_HOST_AUTH_METHOD=md5 \
        -e POSTGRES_INITDB_ARGS="--auth-host=md5" \
        -e PGDATA=/pgdata \
        --tmpfs /pgdata:rw,noexec,nosuid,size=1024m \
        --network spi_test \
        -d \
        postgres:16-alpine
done
