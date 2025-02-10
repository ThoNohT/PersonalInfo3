#!/usr/bin/env sh

set -x

if [ $1 = "build" ]; then
    gleam build 2>/dev/null
    esbuild js/index.mjs --bundle --outdir=dist --sourcemap --platform=browser

elif [ $1 = "clean" ]; then
    rm -rf ./build
    rm -f ./dist/*.js
    rm -f ./dist/*.js.map

else
    echo "Invalid command."

fi

