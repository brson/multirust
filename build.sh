#!/bin/sh

set -e

ver_date=$(git log -1 --pretty=format:'%ci')
ver_hash=$(git rev-parse --short=9 HEAD)

git submodule update --init

mkdir -p build
rm -Rf build/*
mkdir -p build/image/bin
cat src/multirust | sed "s/^ *commit_version=$/commit_version=\"$ver_hash $ver_date\"/" > build/image/bin/multirust
chmod 0755 build/image/bin/multirust
cp src/rustup/rustup.sh build/image/bin/rustup.sh
chmod 0755 build/image/bin/rustup.sh
cp src/multirustproxy build/image/bin/
cp src/multirustproxy build/image/bin/rustc
cp src/multirustproxy build/image/bin/cargo
cp src/multirustproxy build/image/bin/rustdoc
cp src/multirustproxy build/image/bin/rust-gdb
mkdir build/overlay
cp README.md build/overlay

if [ "$(uname -s)" = Darwin ]; then
    cp src/multirustproxy build/image/bin/rust-lldb
fi

sh src/rust-installer/gen-installer.sh \
    --product-name=multirust \
    --package-name=multirust-0.8.0 \
    --rel-manifest-dir=rustlib \
    --success-message=Get-ready-for-Maximum-Rust. \
    --image-dir=./build/image \
    --work-dir=./build/work \
    --output-dir=./build \
    --non-installed-overlay=./build/overlay \
    --component-name=multirust \
    --legacy-manifest-dirs=rustlib,cargo > /dev/null
