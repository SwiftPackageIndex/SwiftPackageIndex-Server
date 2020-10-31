#!/bin/sh

set -eu

TARFILE=$1
DUMPFILE=$2
PG_IMAGE=postgres:12.1-alpine

[[ -n $DATABASE_PASSWORD ]]  || (echo "DATABASE_PASSWORD not set" && exit 1)
[[ -n $DB_BACKUP_DIR ]]      || (echo "DB_BACKUP_DIR not set" && exit 1)
[[ -n $ENV ]]                || (echo "ENV not set" && exit 1)

# Create docker network (ignoring "already exists") in order to
# discover database at hostname "backup-db"
docker network create backup || true

echo "Unpacking ..."

tar xfz $TARFILE

echo "Launching backup db ..."

docker run --rm --name backup-db -d \
    -v "$PWD/db_data:/var/lib/postgresql/data" \
    --network backup \
    $PG_IMAGE

echo "Exporting to $DUMPFILE ..."

RETRIES=30
until docker run --rm --name pg_dump \
    -v "$PWD":/host \
    --network backup \
    --env PGPASSWORD=$DATABASE_PASSWORD \
    $PG_IMAGE \
    pg_dump --no-owner -Fc -f /host/$DUMPFILE \
        -h backup-db -U spi_${ENV} spi_${ENV} \
    || [ $RETRIES -eq 0 ]; do
    echo "Waiting for postgres server, $((RETRIES-=1)) remaining attempts..."
    sleep 5
    echo "Retrying ..."
done

echo "Moving file"
mv $DUMPFILE $DB_BACKUP_DIR

echo "Cleaning up"
rm $TARFILE
rm -rf db_data
docker rm -f backup-db
