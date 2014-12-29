#!/bin/sh

S="$(cd $(dirname $0) && pwd)"

TEST_DIR="$S/test"
TMP_DIR="$S/tmp"
MOCK_DIST_DIR="$S/tmp/dist"
MULTIRUST_HOME="$S/tmp"
MULTIRUST_DIR="$MULTIRUST_HOME/.multirust"

pre() {
    echo
    echo "test: $1"
    echo
    rm -Rf "$MULTIRUST_DIR"
}

post() {
    echo
}

need_ok() {
    if [ $? -ne 0 ]
    then
	echo
	echo "TEST FAILED!"
	echo
	exit 1
    fi
}

try() {
    _cmd="$@"
    echo \$ "$_cmd"
    _output=`$@`
    if [ $? -ne 0 ]; then
	echo
	# Using /bin/echo to avoid escaping
	/bin/echo "$_output"
	echo
	echo "TEST FAILED!"
	echo
	exit 1
    fi
}

expect_fail() {
    _cmd="$@"
    echo \$ "$_cmd"
    _output=`$@`
    if [ $? -eq 0 ]; then
	echo
	# Using /bin/echo to avoid escaping
	/bin/echo "$_output"
	echo
	echo "TEST FAILED!"
	echo
	exit 1
    fi
}

build_mock_bin() {
    local _dir="$1"
    local _name="$2"
    local _version="$3"
}

build_mock_bins() {
}

build_mock_rust_installer() {
}

build_mock_cargo_installer() {
}

build_mock_channel() {
}

# Clean out the tmp dir
try rm -Rf "$TMP_DIR"
try mkdir "$TMP_DIR"

# Tell multirust where to put .multirust
try export MULTIRUST_HOME

# Build bultirust
try "sh $S/build.sh"

# Build the mock revisions
