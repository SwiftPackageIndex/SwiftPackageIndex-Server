#!/bin/sh

set -eu

TARFILE=$1

echo "Backing up database to $PWD/$TARFILE"

docker run --rm \
    -v $PWD:/host \
    -v spi_db_data:/db_data \
    -w /host \
    ubuntu \
    tar cvfz $TARFILE /db_data
