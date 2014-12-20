#!/bin/sh

set -e

installer=build/work/multirust-0.0.1/install.sh

if [ ! -e "$installer" ]; then
    echo 'run ./build.sh first'
    exit 1
fi

"$installer" "$@"
