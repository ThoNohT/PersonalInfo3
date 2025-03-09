#!/usr/bin/env sh

cd "$(dirname "$0")"
set -x

if [ $1 = "build" ]; then
    gleam build

elif [ $1 = "clean" ]; then
    rm -rf ./build

elif [ $1 = "test" ]; then
    gleam test

else
    echo "Invalid command."

fi

