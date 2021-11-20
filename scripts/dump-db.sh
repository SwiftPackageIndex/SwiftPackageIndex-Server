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

HOST=${SPI_DBDUMP_HOST:-'spi-prod-db-1-dump'}
PORT=${SPI_DBDUMP_PORT:-'7435'}
USER=${SPI_DBDUMP_USER:-'spi_prod'}
DATABASE=${SPI_DBDUMP_DATABASE:-'spi_prod'}

read -p "Are you sure you want to dump ${DATABASE} from ${USER}@${HOST}:${PORT}? (Y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]
then
  # This command assumes the db will be available on $PORT on localhost, via an ssh tunnel:
  # For example: ssh -i <your private key> -L 7432:db:5432 -p 2222 root@173.255.229.82
  pg_dump --no-owner -Fc -h localhost -p ${PORT} -U ${USER}@${HOST} ${DATABASE} > ${HOST}-$(date +%Y-%m-%d).dump
fi
