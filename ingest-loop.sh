#!/bin/sh

set -eu

# export LOG_LEVEL=warning

while true; do
    time vapor-beta run ingest -l 100
    echo Pausing...
    sleep 10
done
