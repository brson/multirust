#!/bin/sh

set -e

ver_date=$(git log -1 --pretty=format:'%ci')
ver_hash=$(git rev-parse --short=9 HEAD)

mkdir -p build
rm -Rf build/*
mkdir -p build/image/bin
cat src/multirust | sed "s/^commit_version=$/commit_version=\"$ver_hash $ver_date\"/" > build/image/bin/multirust
chmod 0755 build/image/bin/multirust
cp src/multirustproxy build/image/bin/
cp src/multirustproxy build/image/bin/rustc
cp src/multirustproxy build/image/bin/cargo
cp src/multirustproxy build/image/bin/rustdoc
cp src/multirustproxy build/image/bin/rust-gdb
cp README.md build/image/

if [ "$(uname -s)" = Darwin ]; then
    cp src/multirustproxy build/image/bin/rust-lldb
fi


src/rust-installer/gen-installer.sh \
    --product-name=multirust \
    --package-name=multirust-0.0.2 \
    --rel-manifest-dir=rustlib \
    --success-message=Get-ready-for-Maximum-Rust. \
    --image-dir=./build/image \
    --work-dir=./build/work \
    --output-dir=./build \
    --non-installed-prefixes=README.md \
    --component-name=multirust \
    --legacy-manifest-dirs=rustlib,cargo

