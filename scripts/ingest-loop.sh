#!/bin/sh

set -eu

rester="docker run --rm -t -v $PWD:/host -w /host --network=host finestructure/rester"

# export LOG_LEVEL=warning

while true; do
    time swift run Run ingest -l 100
    # $rester restfiles/ingest.restfile
    echo Pausing...
    sleep 2
done
