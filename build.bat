@ECHO OFF

gleam build
esbuild js/index.mjs --bundle --outdir=dist --sourcemap --platform=browser

