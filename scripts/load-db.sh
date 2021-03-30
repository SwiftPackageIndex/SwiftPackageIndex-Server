#!/bin/bash
set -eu
IMPORT_FILE=$1
docker rm -f spi_dev
docker run --name spi_dev -e POSTGRES_DB=spi_dev -e POSTGRES_USER=spi_dev -e POSTGRES_PASSWORD=xxx -p 6432:5432 -d postgres:11.6-alpine
echo "Giving Postgres a moment to launch ..."
sleep 5
echo "Importing"
PGPASSWORD=xxx pg_restore --no-owner -h ${HOST:-localhost} -p 6432 -U spi_dev -d spi_dev < $IMPORT_FILE
