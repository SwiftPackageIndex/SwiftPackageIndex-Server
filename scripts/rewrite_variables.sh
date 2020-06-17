#!/bin/bash

set -eu

ENV=$1

ENV_UPPER=$(echo $ENV | tr "[:lower:]" "[:upper:]")
echo env: $ENV_UPPER

export PROD_FOO="prod_foo"
export PROD_BAR_1="prod_bar"
export INT_FOO="int_foo"
export INT_BAR_1="int_bar"
export BAZ="baz"
export BAQ="baq"

function join_by { local IFS="$1"; shift; echo "$*"; }

for line in $(printenv | grep $ENV_UPPER); do
    echo $line
    IFS="=" read -ra var <<< "$line"
    var=${var[0]}
    echo var: $var
    IFS="_" read -ra parts <<< "$var"
    echo parts: ${parts[@]}
    unset parts[0]
    echo parts: ${parts[@]}
    new=$(join_by _ "${parts[@]}")
    echo new: $new
    export $new=$(eval echo \"\$$var\")
    echo
done

echo FOO: $FOO
echo BAR_1: $BAR_1
