#!/bin/bash

# Copyright 2020-2021 Dave Verwer, Sven A. Schmidt, and other contributors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

read -p "Are you sure you want to dump the live production database? (Y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]
then
  # This command assumes the prod db to be available on port 7432 on localhost, via an ssh tunnel:
  # ssh -i <your private key> -L 7432:db:5432 -p 2222 root@173.255.229.82
  PORT=${SPI_PRODUCTION_DB_PORT:-'7432'}
  pg_dump --no-owner -Fc -h localhost -p "$PORT" -U spi_prod@spi-prod-db-1 spi_prod > spi_prod_$(date +%Y-%m-%d).dump
fi
