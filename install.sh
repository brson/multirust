#!/bin/sh

set -e

installer=build/work/multirust-0.8.0/install.sh

if [ ! -e "$installer" ]; then
    echo 'run ./build.sh first'
    exit 1
fi

if command -v rustc > /dev/null 2>&1; then
    if ! command -v multirust > /dev/null 2>&1; then
        echo
        echo "it appears that an existing Rust toolchain is installed. please uninstall it first"
        echo
        exit 1
    fi
fi

"$installer" "$@"
