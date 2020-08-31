#!/bin/sh

set -u

TARFILE=$1

echo "Backing up database to $PWD/$TARFILE ..."

docker run --rm \
    -v $PWD:/host \
    -v spi_db_data:/db_data \
    -w /host \
    ubuntu \
    tar cfz $TARFILE /db_data

echo "done."

# don't let tar errors or warnings bubble up
exit 0
