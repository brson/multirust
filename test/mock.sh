#!/bin/sh

template_bin_name="@@TEMPLATE_BIN_NAME@@"
template_version="@@TEMPLATE_VERSION@@"
template_hash="@@TEMPLATE_HASH@@"

if [ "$1" = "--version" ]; then
    echo "$template_bin_name $template_version ($template_hash 2014-12-24 20:47:12 +0000)"
fi
