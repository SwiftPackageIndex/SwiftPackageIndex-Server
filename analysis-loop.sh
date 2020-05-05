#!/bin/sh

set -eu

# export LOG_LEVEL=warning

while true; do
    time vapor-beta run analyze -l 10
    echo Pausing...
    sleep 2
done
