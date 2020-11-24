#!/bin/bash
echo "Warning: Dumping the live production database will take the site offline temporarily."
read -p "Are you sure you want to dump the live production database? (Y/N)" -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]
then
  # This command assumes the prod db to be available on port 7432 on localhost, via an ssh tunnel:
  # ssh -i <your private key> -L 7432:db:5432 -p 2222 root@173.255.229.82
  PORT=${SPI_PRODUCTION_DB_PORT:-'7432'}
  pg_dump --no-owner -Fc -h localhost -p $PORT -U spi_prod spi_prod > spi_prod_$(date +%Y-%m-%d).dump
fi
