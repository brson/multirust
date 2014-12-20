#!/bin/sh

set -e

mkdir -p build
rm -Rf build/*
mkdir -p build/image/bin
cp src/multirust build/image/bin/
cp src/multirustproxy build/image/bin/
cp src/multirustproxy build/image/bin/rustc
cp src/multirustproxy build/image/bin/cargo
cp src/multirustproxy build/image/bin/rustdoc
cp README.md build/image/

src/rust-installer/gen-installer.sh \
    --product-name=multirust \
    --package-name=multirust-0.0.1 \
    --rel-manifest-dir=rustlib \
    --success-message=multirust-to-the-max! \
    --image-dir=./build/image \
    --work-dir=./build/work \
    --output-dir=./build \
    --non-installed-prefixes=README.md \
    --component-name=multirust \
    --legacy-manifest-dirs=rustlib,cargo

