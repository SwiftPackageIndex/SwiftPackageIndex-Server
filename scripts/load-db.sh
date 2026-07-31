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

POSTGRES_IMAGE="postgres:18-alpine"

docker rm -f spi_dev
docker run --name spi_dev -e POSTGRES_DB=spi_dev -e POSTGRES_USER=spi_dev -e POSTGRES_PASSWORD=xxx -p 6432:5432 -d $POSTGRES_IMAGE
echo "Giving Postgres a moment to launch ..."
sleep 5

echo "Creating Azure roles"
docker exec spi_dev psql -U spi_dev -d spi_dev -c 'CREATE ROLE azure_pg_admin; CREATE ROLE azuresu;'

# Restore from inside the container (rather than piping over `docker exec -i`)
# since large tables can be silently truncated mid-COPY when streamed through
# stdin over the docker exec/network hop.
echo "Importing"
docker cp "$IMPORT_FILE" spi_dev:/tmp/import.dump
docker exec spi_dev pg_restore --no-owner -U spi_dev -d spi_dev /tmp/import.dump
docker exec spi_dev rm -f /tmp/import.dump
