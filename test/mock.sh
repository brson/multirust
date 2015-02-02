#!/bin/sh

template_bin_name="@@TEMPLATE_BIN_NAME@@"
template_version="@@TEMPLATE_VERSION@@"
template_hash="@@TEMPLATE_HASH@@"

recurse_arg=false
for arg in "$@"; do
    if [ "$arg" = "--version" ]; then
	echo "$template_bin_name $template_version ($template_hash 2014-12-24 20:47:12 +0000)"
    fi
    # Make a recursive toolchain invocation. Used for 'update checks are not recursive' test.
    if [ "$arg" = "--recurse" ]; then
	recurse_arg=true
    fi
    if [ "$recurse_arg" = true ]; then
	toolname="$(basename "$0")"
	count="$arg"
	if [ "$count" = 2 ]; then
	    "$toolname" --recurse 1
	fi
    fi
done
