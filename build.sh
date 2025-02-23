#!/usr/bin/env sh

set -x

if [ $1 = "build" ]; then
    gleam build
    esbuild js/index.mjs --bundle --outdir=dist --platform=browser

elif [ $1 = "clean" ]; then
    rm -rf ./build
    rm -f ./dist/*.js
    rm -f ./dist/*.js.map

elif [ $1 = "test" ]; then
    gleam test

else
    echo "Invalid command."

fi

