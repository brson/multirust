#!/bin/sh

set -e -u

S="$(cd $(dirname $0) && pwd)"

TEST_DIR="$S/test"
TMP_DIR="$S/tmp"
WORK_DIR="$S/tmp/work"
MOCK_BUILD_DIR="$S/tmp/mock-build"
MOCK_DIST_DIR="$S/tmp/mock-dist"
MULTIRUST_HOME="$(cd "$TMP_DIR" && pwd)"
MULTIRUST_DIR="$MULTIRUST_HOME/.multirust"
VERSION=0.0.1
MULTIRUST_BIN_DIR="$S/build/multirust-$VERSION/bin"

say() {
    echo
    echo "test: $1"
    echo
}

pre() {
    echo
    echo "test: $1"
    echo
    rm -Rf "$MULTIRUST_DIR"
    rm -Rf "$WORK_DIR"
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
    set +e
    _cmd="$@"
    echo \$ "$_cmd"
    _output=`$@ 2>&1`
    if [ $? -ne 0 ]; then
	echo
	# Using /bin/echo to avoid escaping
	/bin/echo "$_output"
	echo
	echo "TEST FAILED!"
	echo
	exit 1
    elif [ -n "${VERBOSE-}" ]; then
	/bin/echo "$_output"
    fi
    set -e
}

expect_fail() {
    set +e
    _cmd="$@"
    echo \$ "$_cmd"
    _output=`$@ 2>&1`
    if [ $? -eq 0 ]; then
	echo
	# Using /bin/echo to avoid escaping
	/bin/echo "$_output"
	echo
	echo "TEST FAILED!"
	echo
	exit 1
    elif [ -n "${VERBOSE-}" ]; then
	/bin/echo "$_output"
    fi
    set -e
}

expect_output() {
    set +e
    local _expected="$1"
    shift 1
    _cmd="$@"
    echo \$ "$_cmd"
    _output=`$@ 2>&1`
    if [ -n "${VERBOSE-}" ]; then
	/bin/echo "$_output"
	echo
    fi
    if ! echo "$_output" | grep -q "$_expected"; then
	echo
	echo "missing expected output '$_expected'"
	echo
	/bin/echo "$_output"
	echo
	echo "TEST FAILED!"
	echo
	exit 1
    fi
    set -e
}

get_architecture() {

    local _ostype="$(uname -s)"
    local _cputype="$(uname -m)"

    if [ "$_ostype" = Darwin -a "$_cputype" = i386 ]; then
	# Darwin `uname -s` lies
	if sysctl hw.optional.x86_64 | grep -q ': 1'; then
	    local _cputype=x86_64
	fi
    fi

    case "$_ostype" in

	Linux)
	    local _ostype=unknown-linux-gnu
	    ;;

	FreeBSD)
	    local _ostype=unknown-freebsd
	    ;;

	DragonFly)
	    local _ostype=unknown-dragonfly
	    ;;

	Darwin)
	    local _ostype=apple-darwin
	    ;;

	MINGW* | MSYS*)
	    err "unimplemented windows arch detection"
	    ;;

	*)
	    err "unrecognized OS type: $_ostype"
	    ;;

    esac

    case "$_cputype" in

	i386 | i486 | i686 | i786 | x86)
            local _cputype=i686
            ;;

	xscale | arm)
	    local _cputype=arm
            ;;

	armv7l)
            local _cputype=arm
            local _ostype="${_ostype}eabihf"
            ;;

	x86_64 | x86-64 | x64 | amd64)
            local _cputype=x86_64
            ;;

	*)
            err "unknown CPU type: $CFG_CPUTYPE"

    esac

    # Detect 64-bit linux with 32-bit userland
    if [ $_ostype = unknown-linux-gnu -a $_cputype = x86_64 ]; then
	file -L "$SHELL" | grep -q "x86[_-]64"
	if [ $? != 0 ]; then
	    local _cputype=i686
	fi
    fi

    local _arch="$_cputype-$_ostype" 

    RETVAL="$_arch"
}

build_mock_bin() {
    local _name="$1"
    local _version="$2"
    local _version_hash="$3"
    local _dir="$4"

    cat "$TEST_DIR/mock.sh" | \
	sed s/@@TEMPLATE_BIN_NAME@@/"$_name"/ | \
	sed s/@@TEMPLATE_VERSION@@/"$_version"/ | \
	sed s/@@TEMPLATE_HASH@@/"$_version_hash"/ > "$_dir/$_name"
}

build_mock_rustc_installer() {
    local _version="$1"
    local _version_hash="$2"
    local _package="$3"

    local _image="$MOCK_BUILD_DIR/image/rustc"
    mkdir -p "$_image/bin"
    build_mock_bin rustc "$_version" "$_version_hash" "$_image/bin"
    build_mock_bin rustdoc "$_version" "$_version_hash" "$_image/bin"

    get_architecture
    local _arch="$RETVAL"

    mkdir -p "$MOCK_BUILD_DIR/pkg"
    try sh "$S/src/rust-installer/gen-installer.sh" \
	--product-name=Rust \
	--rel-manifest-dir=rustlib \
	--image-dir="$_image" \
	--work-dir="$MOCK_BUILD_DIR/work" \
	--output-dir="$MOCK_BUILD_DIR/pkg" \
        --package-name="rustc-$_package-$_arch" \
	--component-name=rustc
}

build_mock_cargo_installer() {
    local _version="$1"
    local _version_hash="$2"
    local _package="$3"

    local _image="$MOCK_BUILD_DIR/image/cargo"
    mkdir -p "$_image/bin"
    build_mock_bin cargo "$_version" "$_version_hash" "$_image/bin"

    get_architecture
    local _arch="$RETVAL"

    mkdir -p "$MOCK_BUILD_DIR/pkg"
    try sh "$S/src/rust-installer/gen-installer.sh" \
	--product-name=Cargo \
	--rel-manifest-dir=rustlib \
	--image-dir="$_image" \
	--work-dir="$MOCK_BUILD_DIR/work" \
	--output-dir="$MOCK_BUILD_DIR/pkg" \
        --package-name="cargo-$_package-$_arch" \
	--component-name=cargo
}

build_mock_rust_docs_installer() {
    local _package="$1"

    local _image="$MOCK_BUILD_DIR/image/docs"
    mkdir -p "$_image/share/doc/rust/html"
    echo "test" > "$_image/share/doc/rust/html/index.html"

    get_architecture
    local _arch="$RETVAL"

    mkdir -p "$MOCK_BUILD_DIR/pkg"
    try sh "$S/src/rust-installer/gen-installer.sh" \
	--product-name=Rust-documentation \
	--rel-manifest-dir=rustlib \
	--image-dir="$_image" \
	--work-dir="$MOCK_BUILD_DIR/work" \
	--output-dir="$MOCK_BUILD_DIR/pkg" \
        --package-name="rust-docs-$_package-$_arch" \
	--component-name=rust-docs
}

build_mock_combined_installer() {
    local _package="$1"

    get_architecture
    local _arch="$RETVAL"

    local _rustc_tarball="$MOCK_BUILD_DIR/pkg/rustc-$_package-$_arch.tar.gz"
    local _cargo_tarball="$MOCK_BUILD_DIR/pkg/cargo-$_package-$_arch.tar.gz"
    local _docs_tarball="$MOCK_BUILD_DIR/pkg/rust-docs-$_package-$_arch.tar.gz"
    local _inputs="$_rustc_tarball,$_cargo_tarball,$_docs_tarball"

    mkdir -p "$MOCK_BUILD_DIR/dist"
    try sh "$S/src/rust-installer/combine-installers.sh" \
	--product-name=Rust \
	--rel-manifest-dir=rustlib \
	--work-dir="$MOCK_BUILD_DIR/work" \
	--output-dir="$MOCK_BUILD_DIR/dist" \
	--package-name="rust-$_package-$_arch" \
	--input-tarballs="$_inputs"
}

build_mock_dist_channel() {
    local _channel="$1"
    local _date="$2"

    (cd "$MOCK_BUILD_DIR/dist" && ls * > channel-rust-"$_channel")
    (cd "$MOCK_BUILD_DIR/dist" && for i in *; do shasum -a256 $i > $i.sha256; done)
}

build_mock_channel() {
    local _version="$1"
    local _version_hash="$2"
    local _package="$3"
    local _channel="$4"
    local _date="$5"

    rm -Rf "$MOCK_BUILD_DIR"
    mkdir -p "$MOCK_BUILD_DIR"

    say "building mock channel $_version $_version_hash $_package $_channel $_date"
    build_mock_rustc_installer "$_version" "$_version_hash" "$_package"
    build_mock_cargo_installer "$_version" "$_version_hash" "$_package"
    build_mock_rust_docs_installer "$_package"
    build_mock_combined_installer "$_package"
    build_mock_dist_channel "$_channel" "$_date"

    mkdir -p "$MOCK_DIST_DIR/dist/$_date"
    cp "$MOCK_BUILD_DIR/dist"/* "$MOCK_DIST_DIR/dist/$_date/"
    cp "$MOCK_BUILD_DIR/dist"/* "$MOCK_DIST_DIR/dist/"
}

build_mocks() {
    #build_mock_channel 1.0.0-nightly hash-1 nightly nightly 2015-01-01
    #build_mock_channel 1.0.0-beta hash-2 beta beta 2015-01-01
    #build_mock_channel 1.0.0 hash-3 1.0.0 stable 2015-01-01
    build_mock_channel 1.1.0-nightly hash-4 nightly nightly 2015-01-02
}

# Clean out the tmp dir
rm -Rf "$TMP_DIR"
mkdir "$TMP_DIR"

# Build the mock revisions
build_mocks

# Build bultirust
say "building multirust"
try sh "$S/build.sh"

# Tell multirust where to put .multirust
export MULTIRUST_HOME

# Tell multirust where to download stuff from
MULTIRUST_DIST_SERVER="file://$(cd "$MOCK_DIST_DIR" && pwd)"
export MULTIRUST_DIST_SERVER

# Set up the PATH to find multirust
PATH="$MULTIRUST_BIN_DIR;$PATH"

pre "uninitialized"
expect_fail rustc
expect_output "no default toolchain configured" rustc
expect_fail multirust show-default
expect_output "no default toolchain configured" multirust show-default

pre "default toolchain"
try multirust default nightly
try multirust show-default
expect_output "nightly" multirust show-default

pre "expected bins exist"
try multirust default nightly
expect_output "1.1.0" rustc --version
expect_output "1.1.0" rustdoc --version
expect_output "1.1.0" cargo --version
