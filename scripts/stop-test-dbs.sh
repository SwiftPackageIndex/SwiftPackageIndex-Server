#!/usr/bin/env bash

for c in $(docker ps --format "{{.Names}}" | grep spi_test_); do
    docker rm -f "$c"
done
