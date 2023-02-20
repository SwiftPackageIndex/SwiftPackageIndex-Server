#!/bin/bash

# Copyright Dave Verwer, Sven A. Schmidt, and other contributors.
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

set -eu
IMPORT_FILE=$1
docker rm -f spi_dev
docker run --name spi_dev -e POSTGRES_DB=spi_dev -e POSTGRES_USER=spi_dev -e POSTGRES_PASSWORD=xxx -p 6432:5432 -d postgres:13.8-alpine
echo "Giving Postgres a moment to launch ..."
sleep 5
echo "Creating Azure roles"
PGPASSWORD=xxx psql -h "${HOST:-localhost}" -p 6432 -U spi_dev -d spi_dev -c 'CREATE ROLE azure_pg_admin; CREATE ROLE azuresu;'
echo "Importing"
PGPASSWORD=xxx pg_restore --no-owner -h "${HOST:-localhost}" -p 6432 -U spi_dev -d spi_dev < "$IMPORT_FILE"
