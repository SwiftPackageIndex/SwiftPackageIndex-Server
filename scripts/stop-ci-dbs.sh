#!/usr/bin/env bash

for c in $(docker ps --all --format "{{.Names}}" | grep spi_test_); do
    docker rm -f "$c"
done

docker network rm spi_test 2> /dev/null || true
