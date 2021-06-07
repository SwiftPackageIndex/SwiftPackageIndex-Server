#!/bin/sh

set -eux

docker run --rm -v "$(PWD)":/host -w /host --network="host" finestructure/spi-base:0.5.2 \
  swift run -c release -Xswiftc -g Run crash "$@"
