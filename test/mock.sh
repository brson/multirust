#!/bin/sh

template_bin_name="@@TEMPLATE_BIN_NAME@@"
template_version="@@TEMPLATE_VERSION@@"

if [ "$1" = "--version" ]; then
    echo "$template_bin_name $template_version (7e11b2271 2014-12-24 20:47:12 +0000)"
    exit 0
fi

echo "unknown parameter"
exit 1
