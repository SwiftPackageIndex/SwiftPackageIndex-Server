#!/bin/bash
# This command assumes the dev db to be available on port 7432 on localhost, via an ssh tunnel:
# ssh -i <your private key> -L 7432:db:5432 -p 2222 root@173.255.229.82
PORT=${SPI_STAGING_DB_PORT:-'7432'}
pg_dump --no-owner -Fc -h localhost -p $PORT -U spi_dev@spi-dev-db-1 spi_dev > spi_dev_$(date +%Y-%m-%d).dump
