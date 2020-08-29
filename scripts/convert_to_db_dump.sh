#!/bin/sh

set -eu

TARFILE=$1
DUMPFILE=$(basename $TARFILE).dump

[[ -n $DATABASE_PASSWORD ]]  || (echo "DATABASE_PASSWORD not set" && exit 1)
[[ -n $DB_BACKUP_DIR ]]      || (echo "DB_BACKUP_DIR not set" && exit 1)
[[ -n $ENV ]]                || (echo "ENV not set" && exit 1)

tar xvfz $TARFILE

/usr/local/bin/docker run --rm --name backup-db -d -v "$PWD/db_data:/var/lib/postgresql/data" -p 9432:5432 postgres:12.1-alpine

echo "Exporting ..."

RETRIES=20
until env PGPASSWORD=${DATABASE_PASSWORD} /usr/local/bin/pg_dump --no-owner -Fc -h localhost -p 9432 -U spi_${ENV} spi_${ENV} > $DUMPFILE || [ $RETRIES -eq 0 ]; do
    echo "Waiting for postgres server, $((RETRIES-=1)) remaining attempts..."
    sleep 2
done

echo "Moving file"
mv $DUMPFILE ${DB_BACKUP_DIR}

echo "Cleaning up"
rm $TARFILE
rm -rf db_data
docker rm -f backup-db
