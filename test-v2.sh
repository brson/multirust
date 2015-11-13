#!/bin/sh

# TODO update notifications
# TODO CARGO_HOME
# TODO rpath
# TODO non-absolute MULTIRUST_HOME

set -e -u

# Prints the absolute path of a directory to stdout
abs_path() {
    local _path="$1"
    # Unset CDPATH because it causes havok: it makes the destination unpredictable
    # and triggers 'cd' to print the path to stdout. Route `cd`'s output to /dev/null
    # for good measure.
    (unset CDPATH && cd "$_path" > /dev/null && pwd)
}

S="$(abs_path $(dirname $0))"

TMP_DIR="$S/tmp-v2"
MOCK_DIST_DIR="$TMP_DIR/mock-dist"
CUSTOM_TOOLCHAINS="$TMP_DIR/custom-toolchains"

# Clean out the tmp dir
if [ -n "${NO_REBUILD_MOCKS-}" ]; then
    mv "$MOCK_DIST_DIR" ./mock-backup
    mv "$CUSTOM_TOOLCHAINS" ./custom-backup
fi
rm -Rf "$TMP_DIR"
mkdir "$TMP_DIR"
if [ -n "${NO_REBUILD_MOCKS-}" ]; then
    mv ./mock-backup "$MOCK_DIST_DIR"
    mv ./custom-backup "$CUSTOM_TOOLCHAINS"
fi

TEST_DIR="$S/test"
TEST_SECRET_KEY="$TEST_DIR/secret-key.gpg"
TEST_PUBLIC_KEY="$TEST_DIR/public-key.gpg"
MULTIRUST_GPG_KEY="$TEST_DIR/public-key.asc"
WORK_DIR="$TMP_DIR/work"
MOCK_BUILD_DIR="$TMP_DIR/mock-build"
MULTIRUST_HOME="$(cd "$TMP_DIR" && pwd)/multirust"
VERSION=0.7.0
MULTIRUST_BIN_DIR="$S/build/work/multirust-$VERSION/multirust/bin"
MULTIRUST_BIN_DIR_V1="$S/test/multirust-v1/build/work/multirust-0.0.2/multirust/bin"

CROSS_ARCH1="x86_64-unknown-linux-musl"
CROSS_ARCH2="arm-linux-androideabi"

say() {
    echo "test: $1"
}

pre() {
    echo "test: $1"
    rm -Rf "$MULTIRUST_HOME"
    rm -Rf "$WORK_DIR"
    mkdir -p "$WORK_DIR"
}

need_ok() {
    if [ $? -ne 0 ]; then
        echo
        echo "TEST FAILED!"
        echo
        exit 1
    fi
}

fail() {
    echo
    echo "$1"
    echo
    echo "TEST FAILED!"
    echo
    exit 1
}

try() {
    set +e
    _cmd="$@"
    _output=`$@ 2>&1`
    if [ $? -ne 0 ]; then
        echo \$ "$_cmd"
        # Using /bin/echo to avoid escaping
        /bin/echo "$_output"
        echo
        echo "TEST FAILED!"
        echo
        exit 1
    else
        if [ -n "${VERBOSE-}" -o -n "${VERBOSE_CMD-}" ]; then
            echo \$ "$_cmd"
        fi
        if [ -n "${VERBOSE-}" -o -n "${VERBOSE_OUTPUT-}" ]; then
            /bin/echo "$_output"
        fi
    fi
    set -e
}

expect_fail() {
    set +e
    _cmd="$@"
    _output=`$@ 2>&1`
    if [ $? -eq 0 ]; then
        echo \$ "$_cmd"
        # Using /bin/echo to avoid escaping
        /bin/echo "$_output"
        echo
        echo "TEST FAILED!"
        echo
        exit 1
    else
        if [ -n "${VERBOSE-}" -o -n "${VERBOSE_CMD-}" ]; then
            echo \$ "$_cmd"
        fi
        if [ -n "${VERBOSE-}" -o -n "${VERBOSE_OUTPUT-}" ]; then
            /bin/echo "$_output"
        fi
    fi
    set -e
}

expect_output_ok() {
    set +e
    local _expected="$1"
    shift 1
    _cmd="$@"
    _output=`$@ 2>&1`
    if [ $? -ne 0 ]; then
        echo \$ "$_cmd"
        # Using /bin/echo to avoid escaping
        /bin/echo "$_output"
        echo
        echo "TEST FAILED!"
        echo
        exit 1
    elif ! echo "$_output" | grep -q "$_expected"; then
        echo \$ "$_cmd"
        /bin/echo "$_output"
        echo
        echo "missing expected output '$_expected'"
        echo
        echo
        echo "TEST FAILED!"
        echo
        exit 1
    else
        if [ -n "${VERBOSE-}" -o -n "${VERBOSE_CMD-}" ]; then
            echo \$ "$_cmd"
        fi
        if [ -n "${VERBOSE-}" -o -n "${VERBOSE_OUTPUT-}" ]; then
            /bin/echo "$_output"
        fi
    fi
    set -e
}

expect_output_fail() {
    set +e
    local _expected="$1"
    shift 1
    _cmd="$@"
    _output=`$@ 2>&1`
    if [ $? -eq 0 ]; then
        echo \$ "$_cmd"
        # Using /bin/echo to avoid escaping
        /bin/echo "$_output"
        echo
        echo "TEST FAILED!"
        echo
        exit 1
    elif ! echo "$_output" | grep -q "$_expected"; then
        echo \$ "$_cmd"
        /bin/echo "$_output"
        echo
        echo "missing expected output '$_expected'"
        echo
        echo
        echo "TEST FAILED!"
        echo
        exit 1
    else
        if [ -n "${VERBOSE-}" -o -n "${VERBOSE_CMD-}" ]; then
            echo \$ "$_cmd"
        fi
        if [ -n "${VERBOSE-}" -o -n "${VERBOSE_OUTPUT-}" ]; then
            /bin/echo "$_output"
        fi
    fi
    set -e
}

expect_not_output_ok() {
    set +e
    local _expected="$1"
    shift 1
    _cmd="$@"
    _output=`$@ 2>&1`
    if [ $? -ne 0 ]; then
        echo \$ "$_cmd"
        # Using /bin/echo to avoid escaping
        /bin/echo "$_output"
        echo
        echo "TEST FAILED!"
        echo
        exit 1
    elif echo "$_output" | grep -q "$_expected"; then
        echo \$ "$_cmd"
        /bin/echo "$_output"
        echo
        echo "unexpected output '$_expected'"
        echo
        echo
        echo "TEST FAILED!"
        echo
        exit 1
    else
        if [ -n "${VERBOSE-}" -o -n "${VERBOSE_CMD-}" ]; then
            echo \$ "$_cmd"
        fi
        if [ -n "${VERBOSE-}" -o -n "${VERBOSE_OUTPUT-}" ]; then
            /bin/echo "$_output"
        fi
    fi
    set -e
}

runtest() {
    local _testname="$1"
    if [ -n "${TESTNAME-}" ]; then
        if ! echo "$_testname" | grep -q "$TESTNAME"; then
            return 0
        fi
    fi

    pre "$_testname"
    "$_testname"
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
        local _ostype=pc-windows-gnu
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
        ;;
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

    chmod a+x "$_dir/$_name"
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

    mkdir -p "$MOCK_BUILD_DIR/dist"
    try sh "$S/src/rust-installer/gen-installer.sh" \
        --product-name=Rust \
        --rel-manifest-dir=rustlib \
        --image-dir="$_image" \
        --work-dir="$MOCK_BUILD_DIR/work" \
        --output-dir="$MOCK_BUILD_DIR/dist" \
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

    mkdir -p "$MOCK_BUILD_DIR/dist"
    try sh "$S/src/rust-installer/gen-installer.sh" \
    --product-name=Cargo \
    --rel-manifest-dir=rustlib \
    --image-dir="$_image" \
    --work-dir="$MOCK_BUILD_DIR/work" \
    --output-dir="$MOCK_BUILD_DIR/dist" \
        --package-name="cargo-$_package-$_arch" \
    --component-name=cargo
}


build_mock_std_installer() {
    local _package="$1"
    
    get_architecture
    local _arch="$RETVAL"

    local _image="$MOCK_BUILD_DIR/image/std"
    mkdir -p "$_image/lib/rustlib/$_arch/lib/"
    echo "test" > "$_image/lib/rustlib/$_arch/lib/libstd.rlib"

    mkdir -p "$MOCK_BUILD_DIR/dist"
    try sh "$S/src/rust-installer/gen-installer.sh" \
        --product-name=Rust-std \
        --rel-manifest-dir=rustlib \
        --image-dir="$_image" \
        --work-dir="$MOCK_BUILD_DIR/work" \
        --output-dir="$MOCK_BUILD_DIR/dist" \
        --package-name="rust-std-$_package-$_arch" \
        --component-name=rust-std-$_arch
}

build_mock_cross_std_installer() {
    local _package="$1"
    local _arch="$2"
    local _date="$3"

    local _image="$MOCK_BUILD_DIR/image/std"
    mkdir -p "$_image/lib/rustlib/$_arch/lib/"
    # Just some files to test for
    echo "test" > "$_image/lib/rustlib/$_arch/lib/libstd.rlib"
    echo "test" > "$_image/lib/rustlib/$_arch/lib/$_date"

    mkdir -p "$MOCK_BUILD_DIR/dist"
    try sh "$S/src/rust-installer/gen-installer.sh" \
        --product-name=Rust-std \
        --rel-manifest-dir=rustlib \
        --image-dir="$_image" \
        --work-dir="$MOCK_BUILD_DIR/work" \
        --output-dir="$MOCK_BUILD_DIR/dist" \
        --package-name="rust-std-$_package-$_arch" \
        --component-name=rust-std-$_arch
}

build_mock_rust_docs_installer() {
    local _package="$1"

    local _image="$MOCK_BUILD_DIR/image/docs"
    mkdir -p "$_image/share/doc/rust/html"
    echo "test" > "$_image/share/doc/rust/html/index.html"

    get_architecture
    local _arch="$RETVAL"

    mkdir -p "$MOCK_BUILD_DIR/dist"
    try sh "$S/src/rust-installer/gen-installer.sh" \
        --product-name=Rust-documentation \
        --rel-manifest-dir=rustlib \
        --image-dir="$_image" \
        --work-dir="$MOCK_BUILD_DIR/work" \
        --output-dir="$MOCK_BUILD_DIR/dist" \
        --package-name="rust-docs-$_package-$_arch" \
        --component-name=rust-docs
}

build_mock_combined_installer() {
    local _package="$1"

    get_architecture
    local _arch="$RETVAL"

    local _rustc_tarball="$MOCK_BUILD_DIR/dist/rustc-$_package-$_arch.tar.gz"
    local _cargo_tarball="$MOCK_BUILD_DIR/dist/cargo-$_package-$_arch.tar.gz"
    local _std_tarball="$MOCK_BUILD_DIR/dist/rust-std-$_package-$_arch.tar.gz"
    local _docs_tarball="$MOCK_BUILD_DIR/dist/rust-docs-$_package-$_arch.tar.gz"
    local _inputs="$_rustc_tarball,$_cargo_tarball,$_docs_tarball,$_std_tarball"

    mkdir -p "$MOCK_BUILD_DIR/dist"
    try sh "$S/src/rust-installer/combine-installers.sh" \
        --product-name=Rust \
        --rel-manifest-dir=rustlib \
        --work-dir="$MOCK_BUILD_DIR/work" \
        --output-dir="$MOCK_BUILD_DIR/dist" \
        --package-name="rust-$_package-$_arch" \
        --input-tarballs="$_inputs"
}

build_mock_sums_and_sigs() {
    if command -v gpg > /dev/null 2>&1; then
        (cd "$MOCK_BUILD_DIR/dist" && for i in *; do
                gpg --no-default-keyring --secret-keyring "$TEST_SECRET_KEY" \
                    --keyring "$TEST_PUBLIC_KEY" \
                    --no-tty --yes -a --detach-sign "$i"
                done)
    else
        say "gpg not found. not testing signature verification"
        (cd "$MOCK_BUILD_DIR/dist" && for i in *; do echo "nosig" > "$i.asc"; done)
    fi
    (cd "$MOCK_BUILD_DIR/dist" && for i in *; do shasum -a256 $i > $i.sha256; done)
}

build_mock_channel_manifest() {
    local _channel="$1"
    local _date="$2"
    local _version="$3"

    # Build the v1 manifest for upgrade tests
    (cd "$MOCK_BUILD_DIR/dist" && ls * > channel-rust-"$_channel")

    get_architecture
    local _arch="$RETVAL"

    local _rust_tarball="$(frob_win_path "file://$MOCK_DIST_DIR/dist/$_date/rust-$_package-$_arch.tar.gz")"
    local _rustc_tarball="$(frob_win_path "file://$MOCK_DIST_DIR/dist/$_date/rustc-$_package-$_arch.tar.gz")"
    local _cargo_tarball="$(frob_win_path "file://$MOCK_DIST_DIR/dist/$_date/cargo-$_package-$_arch.tar.gz")"
    local _std_tarball="$(frob_win_path "file://$MOCK_DIST_DIR/dist/$_date/rust-std-$_package-$_arch.tar.gz")"
    local _cross_std_tarball1="$(frob_win_path "file://$MOCK_DIST_DIR/dist/$_date/rust-std-$_package-$CROSS_ARCH1.tar.gz")"
    local _cross_std_tarball2="$(frob_win_path "file://$MOCK_DIST_DIR/dist/$_date/rust-std-$_package-$CROSS_ARCH2.tar.gz")"
    local _docs_tarball="$(frob_win_path "file://$MOCK_DIST_DIR/dist/$_date/rust-docs-$_package-$_arch.tar.gz")"

    local _manifest="$MOCK_BUILD_DIR/dist/channel-rust-$_channel.toml"

    printf "%s\n" "manifest-version = \"2\"" >> "$_manifest"
    printf "%s\n" "date = \"$_date\"" >> "$_manifest"

    # the 'rust' package
    printf "%s\n" "[pkg.rust]" >> "$_manifest"
    printf "%s\n" "version = \"$_version\"" >> "$_manifest"
    printf "%s\n" "[pkg.rust.target.$_arch]" >> "$_manifest"
    printf "%s\n" "url = \"$_rust_tarball\"" >> "$_manifest"
    printf "%s\n" "[[pkg.rust.target.$_arch.components]]" >> "$_manifest"
    printf "%s\n" "pkg = \"rustc\"" >> "$_manifest"
    printf "%s\n" "target = \"$_arch\"" >> "$_manifest"
    printf "%s\n" "[pkg.rust.target.$_arch.components]]" >> "$_manifest"
    printf "%s\n" "pkg = \"rust-docs\"" >> "$_manifest"
    printf "%s\n" "target = \"$_arch\"" >> "$_manifest"
    printf "%s\n" "[pkg.rust.target.$_arch.components]]" >> "$_manifest"
    printf "%s\n" "pkg = \"cargo\"" >> "$_manifest"
    printf "%s\n" "target = \"$_arch\"" >> "$_manifest"
    printf "%s\n" "[pkg.rust.target.$_arch.components]]" >> "$_manifest"
    printf "%s\n" "pkg = \"rust-std\"" >> "$_manifest"
    printf "%s\n" "target = \"$_arch\"" >> "$_manifest"
    printf "%s\n" "[pkg.rust.target.$_arch.extensions]]" >> "$_manifest"
    printf "%s\n" "pkg = \"rust-std\"" >> "$_manifest"
    printf "%s\n" "target = \"$CROSS_ARCH1\"" >> "$_manifest"
    printf "%s\n" "[pkg.rust.target.$_arch.extensions]]" >> "$_manifest"
    printf "%s\n" "pkg = \"rust-std\"" >> "$_manifest"
    printf "%s\n" "target = \"$CROSS_ARCH2\"" >> "$_manifest"
 
    # the other packages
    printf "%s\n" "[pkg.rustc]" >> "$_manifest"
    printf "%s\n" "version = \"$_version\"" >> "$_manifest"
    printf "%s\n" "[pkg.rustc.target.$_arch]" >> "$_manifest"
    printf "%s\n" "url = \"$_rustc_tarball\"" >> "$_manifest"
    printf "%s\n" "[pkg.rust-docs]" >> "$_manifest"
    printf "%s\n" "version = \"$_version\"" >> "$_manifest"
    printf "%s\n" "[pkg.rust-docs.target.$_arch]" >> "$_manifest"
    printf "%s\n" "url = \"$_docs_tarball\"" >> "$_manifest"
    printf "%s\n" "[pkg.cargo]" >> "$_manifest"
    printf "%s\n" "version = \"$_version\"" >> "$_manifest"
    printf "%s\n" "[pkg.cargo.target.$_arch]" >> "$_manifest"
    printf "%s\n" "url = \"$_cargo_tarball\"" >> "$_manifest"
    printf "%s\n" "[pkg.rust-std]" >> "$_manifest"
    printf "%s\n" "version = \"$_version\"" >> "$_manifest"
    printf "%s\n" "[pkg.rust-std.target.$_arch]" >> "$_manifest"
    printf "%s\n" "url = \"$_std_tarball\"" >> "$_manifest"
    printf "%s\n" "[pkg.rust-std.target.$CROSS_ARCH1]" >> "$_manifest"
    printf "%s\n" "url = \"$_cross_std_tarball1\"" >> "$_manifest"
    printf "%s\n" "[pkg.rust-std.target.$CROSS_ARCH2]" >> "$_manifest"
    printf "%s\n" "url = \"$_cross_std_tarball2\"" >> "$_manifest"
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
    build_mock_std_installer "$_package"
    build_mock_cross_std_installer "$_package" "$CROSS_ARCH1" "$_date"
    build_mock_cross_std_installer "$_package" "$CROSS_ARCH2" "$_date"
    build_mock_rustc_installer "$_version" "$_version_hash" "$_package"
    build_mock_cargo_installer "$_version" "$_version_hash" "$_package"
    build_mock_rust_docs_installer "$_package"
    build_mock_combined_installer "$_package"
    build_mock_channel_manifest "$_channel" "$_date" "$_version"
    build_mock_channel_manifest "$_version" "$_date" "$_version"
    build_mock_sums_and_sigs

    mkdir -p "$MOCK_DIST_DIR/dist/$_date"
    cp "$MOCK_BUILD_DIR/dist"/* "$MOCK_DIST_DIR/dist/$_date/"
    cp "$MOCK_BUILD_DIR/dist"/* "$MOCK_DIST_DIR/dist/"

    mkdir -p "$CUSTOM_TOOLCHAINS/$_date"

    for t in "$MOCK_BUILD_DIR/work/"*; do
        sh "$t/install.sh" --prefix="$CUSTOM_TOOLCHAINS/$_date/" 2> /dev/null 1> /dev/null
    done
}

build_mocks() {
    if [ -z "${NO_REBUILD_MOCKS-}" ]; then
        build_mock_channel 1.0.0-nightly hash-nightly-1 nightly nightly 2015-01-01
        build_mock_channel 1.0.0-beta hash-beta-1 1.0.0-beta beta 2015-01-01
        build_mock_channel 1.0.0 hash-stable-1 1.0.0 stable 2015-01-01

        build_mock_channel 1.1.0-nightly hash-nightly-2 nightly nightly 2015-01-02
        build_mock_channel 1.1.0-beta hash-beta-2 1.1.0-beta beta 2015-01-02
        build_mock_channel 1.1.0 hash-stable-2 1.1.0 stable 2015-01-02
    fi
}

set_current_dist_date() {
    local _dist_date="$1"
    cp "$MOCK_DIST_DIR/dist/$_dist_date"/* "$MOCK_DIST_DIR/dist/"
}

frob_win_path() {
    local _path="$1"

    get_architecture
    arch="$RETVAL"

    # HACK: Frob `/c/` prefix into `c:/` on windows to make curl happy
    case "$arch" in
    *pc-windows*)
        printf '%s' "$_path" | sed s~file:///c/~file://c:/~
        ;;
    *)
	printf '%s' "$_path"
        ;;
    esac
}

# Build the mock revisions
build_mocks

say "updating submodules"
try git submodule update --init --recursive

# Build bultirust
say "building multirust"
try sh "$S/build.sh"

# Build old-multirusts
cd "$S/test/multirust-v1" && try sh ./build.sh

get_architecture
arch="$RETVAL"

case "$arch" in
*pc-windows*)
    is_windows=true
    ;;
*)
    is_windows=false
    ;;
esac

# Tell multirust where to put .multirust
export MULTIRUST_HOME
# Tell multirust what key to use to verify sigs
export MULTIRUST_GPG_KEY
export RUSTUP_GPG_KEY="$MULTIRUST_GPG_KEY"

# Tell multirust where to download stuff from
MULTIRUST_DIST_SERVER="$(frob_win_path "file://$(cd "$MOCK_DIST_DIR" && pwd)")"

export MULTIRUST_DIST_SERVER
export RUSTUP_DIST_SERVER="$MULTIRUST_DIST_SERVER"

# Set up the PATH to find multirust
PATH="$MULTIRUST_BIN_DIR:$PATH"
export PATH
try test -e "$MULTIRUST_BIN_DIR/multirust"

# Names of custom installers
local_custom_rust="$MOCK_DIST_DIR/dist/rust-nightly-$arch.tar.gz"
local_custom_rustc="$MOCK_DIST_DIR/dist/rustc-nightly-$arch.tar.gz"
local_custom_cargo="$MOCK_DIST_DIR/dist/cargo-nightly-$arch.tar.gz"
remote_custom_rust="$MULTIRUST_DIST_SERVER/dist/rust-nightly-$arch.tar.gz"
remote_custom_rustc="$MULTIRUST_DIST_SERVER/dist/rustc-nightly-$arch.tar.gz"
remote_custom_cargo="$MULTIRUST_DIST_SERVER/dist/cargo-nightly-$arch.tar.gz"

no_args() {
    expect_output_ok "Usage" multirust
}
runtest no_args

uninitialized() {
    expect_fail rustc
    expect_output_fail "no default toolchain configured" rustc
    expect_output_ok "no default toolchain configured" multirust show-default
}
runtest uninitialized

default_toolchain() {
    try multirust default nightly
    expect_output_ok "nightly" multirust show-default
}
runtest default_toolchain

expected_bins_exist() {
    try multirust default nightly
    expect_output_ok "1.1.0" rustc --version
    expect_output_ok "1.1.0" rustdoc --version
    expect_output_ok "1.1.0" cargo --version
}
runtest expected_bins_exist

install_toolchain_from_channel() {
    try multirust default nightly
    expect_output_ok "hash-nightly-2" rustc --version
    try multirust default beta
    expect_output_ok "hash-beta-2" rustc --version
    try multirust default stable
    expect_output_ok "hash-stable-2" rustc --version
}
runtest install_toolchain_from_channel

install_toolchain_from_archive() {
    try multirust default nightly-2015-01-01
    expect_output_ok "hash-nightly-1" rustc --version
    try multirust default beta-2015-01-01
    expect_output_ok "hash-beta-1" rustc --version
    try multirust default stable-2015-01-01
    expect_output_ok "hash-stable-1" rustc --version
}
runtest install_toolchain_from_archive

install_toolchain_linking_from_path() {
    try multirust default default-from-path --link-local "$CUSTOM_TOOLCHAINS/2015-01-01"
    expect_output_ok "hash-stable-1" rustc --version
}
runtest install_toolchain_linking_from_path

install_toolchain_from_path() {
    try multirust default default-from-path --copy-local "$CUSTOM_TOOLCHAINS/2015-01-01"
    expect_output_ok "hash-stable-1" rustc --version
}
runtest install_toolchain_from_path

install_toolchain_linking_from_path_again() {
    try multirust default default-from-path --link-local "$CUSTOM_TOOLCHAINS/2015-01-01"
    expect_output_ok "hash-stable-1" rustc --version
    try multirust default default-from-path --link-local "$CUSTOM_TOOLCHAINS/2015-01-02"
    expect_output_ok "hash-stable-2" rustc --version
}
runtest install_toolchain_linking_from_path_again

install_toolchain_from_path_again() {
    try multirust default default-from-path --copy-local "$CUSTOM_TOOLCHAINS/2015-01-01"
    expect_output_ok "hash-stable-1" rustc --version
    try multirust default default-from-path --copy-local "$CUSTOM_TOOLCHAINS/2015-01-02"
    expect_output_ok "hash-stable-2" rustc --version
}
runtest install_toolchain_from_path_again

install_toolchain_change_from_copy_to_link() {
    try multirust default default-from-path --copy-local "$CUSTOM_TOOLCHAINS/2015-01-01"
    expect_output_ok "hash-stable-1" rustc --version
    try multirust default default-from-path --link-local "$CUSTOM_TOOLCHAINS/2015-01-02"
    expect_output_ok "hash-stable-2" rustc --version
}
runtest install_toolchain_change_from_copy_to_link

install_toolchain_change_from_link_to_copy() {
    try multirust default default-from-path --link-local "$CUSTOM_TOOLCHAINS/2015-01-01"
    expect_output_ok "hash-stable-1" rustc --version
    try multirust default default-from-path --copy-local "$CUSTOM_TOOLCHAINS/2015-01-02"
    expect_output_ok "hash-stable-2" rustc --version
}
runtest install_toolchain_change_from_link_to_copy

install_toolchain_from_custom() {
    try multirust default custom --installer "$local_custom_rust"
    expect_output_ok nightly rustc --version
}
runtest install_toolchain_from_custom

install_toolchain_from_version() {
    try multirust default 1.1.0
    expect_output_ok "hash-stable-2" rustc --version
}
runtest install_toolchain_from_version

default_existing_toolchain() {
    try multirust update nightly
    expect_output_ok "using existing install for 'nightly'" multirust default nightly
}
runtest default_existing_toolchain

update_channel() {
    set_current_dist_date 2015-01-01
    try multirust default nightly
    expect_output_ok "hash-nightly-1" rustc --version
    set_current_dist_date 2015-01-02
    try multirust update nightly
    expect_output_ok "hash-nightly-2" rustc --version
}
runtest update_channel

list_toolchains() {
    try multirust update nightly
    try multirust update beta-2015-01-01
    expect_output_ok "nightly" multirust list-toolchains
    expect_output_ok "beta-2015-01-01" multirust list-toolchains
}
runtest list_toolchains

list_toolchain_with_none() {
    try multirust list-toolchains
    expect_output_ok "no installed toolchains" multirust list-toolchains
}
runtest list_toolchain_with_none

remove_toolchain() {
    try multirust update nightly
    try multirust remove-toolchain nightly
    try multirust list-toolchains
    expect_output_ok "no installed toolchains" multirust list-toolchains
}
runtest remove_toolchain

remove_active_toolchain_error_handling() {
    try multirust default nightly
    try multirust remove-toolchain nightly
    expect_output_fail "toolchain 'nightly' not installed" rustc
}
runtest remove_active_toolchain_error_handling

bad_sha_on_manifest() {
    # Have to break both v1 and v2 manifest hashes to trigger the failure
    manifest_hash="$MOCK_DIST_DIR/dist/channel-rust-nightly.sha256"
    sha=`cat "$manifest_hash"`
    echo "$sha" | sed s/^......../aaaaaaaa/ >  "$manifest_hash"
    manifest_hash="$MOCK_DIST_DIR/dist/channel-rust-nightly.toml.sha256"
    sha=`cat "$manifest_hash"`
    echo "$sha" | sed s/^......../aaaaaaaa/ >  "$manifest_hash"
    expect_output_fail "checksum failed" multirust default nightly
    set_current_dist_date 2015-01-02
}
runtest bad_sha_on_manifest

bad_sha_on_installer() {
    for i in "$MOCK_DIST_DIR/dist"/*.sha256; do
        sha=`cat "$i"`
        echo "$sha" | sed s/^......../aaaaaaaa/ > "$i"
    done
    expect_output_fail "checksum failed" multirust default 1.0.0
    set_current_dist_date 2015-01-02
}
runtest bad_sha_on_installer

delete_data() {
    try multirust default nightly
    if [ ! -d "$MULTIRUST_HOME" ]; then
        fail "no multirust dir"
    fi
    try multirust delete-data -y
    if [ -d "$MULTIRUST_HOME" ]; then
        fail "multirust dir not removed"
    fi
}
runtest delete_data

install_override_toolchain_from_channel() {
    try multirust override nightly
    expect_output_ok "hash-nightly-2" rustc --version
    try multirust override beta
    expect_output_ok "hash-beta-2" rustc --version
    try multirust override stable
    expect_output_ok "hash-stable-2" rustc --version
}
runtest install_override_toolchain_from_channel

install_override_toolchain_from_archive() {
    try multirust override nightly-2015-01-01
    expect_output_ok "hash-nightly-1" rustc --version
    try multirust override beta-2015-01-01
    expect_output_ok "hash-beta-1" rustc --version
    try multirust override stable-2015-01-01
    expect_output_ok "hash-stable-1" rustc --version
}
runtest install_override_toolchain_from_archive

install_override_toolchain_linking_path() {
    try multirust override stable-from-path --link-local "$CUSTOM_TOOLCHAINS/2015-01-01"
    expect_output_ok "hash-stable-1" rustc --version
}
runtest install_override_toolchain_linking_path

install_override_toolchain_from_path() {
    try multirust override stable-from-path --copy-local "$CUSTOM_TOOLCHAINS/2015-01-01"
    expect_output_ok "hash-stable-1" rustc --version
}
runtest install_override_toolchain_from_path

install_override_toolchain_linking_path_again() {
    try multirust override stable-from-path --link-local "$CUSTOM_TOOLCHAINS/2015-01-01"
    expect_output_ok "hash-stable-1" rustc --version
    try multirust override stable-from-path --link-local "$CUSTOM_TOOLCHAINS/2015-01-02"
    expect_output_ok "hash-stable-2" rustc --version
}
runtest install_override_toolchain_linking_path_again

install_override_toolchain_from_path_again() {
    try multirust override stable-from-path --copy-local "$CUSTOM_TOOLCHAINS/2015-01-01"
    expect_output_ok "hash-stable-1" rustc --version
    try multirust override stable-from-path --copy-local "$CUSTOM_TOOLCHAINS/2015-01-02"
    expect_output_ok "hash-stable-2" rustc --version
}
runtest install_override_toolchain_from_path_again

install_override_toolchain_change_from_copy_to_link() {
    try multirust override stable-from-path --copy-local "$CUSTOM_TOOLCHAINS/2015-01-01"
    expect_output_ok "hash-stable-1" rustc --version
    try multirust override stable-from-path --link-local "$CUSTOM_TOOLCHAINS/2015-01-02"
    expect_output_ok "hash-stable-2" rustc --version
}
runtest install_override_toolchain_change_from_copy_to_link

install_override_toolchain_change_from_link_to_copy() {
    try multirust override stable-from-path --link-local "$CUSTOM_TOOLCHAINS/2015-01-01"
    expect_output_ok "hash-stable-1" rustc --version
    try multirust override stable-from-path --copy-local "$CUSTOM_TOOLCHAINS/2015-01-02"
    expect_output_ok "hash-stable-2" rustc --version
}
runtest install_override_toolchain_change_from_link_to_copy

install_override_toolchain_from_version() {
    try multirust override 1.1.0
    expect_output_ok "hash-stable-2" rustc --version
}
runtest install_override_toolchain_from_version

override_overrides_default() {
    try multirust default nightly
    try multirust override beta
    expect_output_ok "beta" rustc --version
}
runtest override_overrides_default

multiple_overrides() {
    mkdir -p "$WORK_DIR/dir1"
    mkdir -p "$WORK_DIR/dir2"
    try multirust default nightly
    (cd "$WORK_DIR/dir1" && try multirust override beta)
    (cd "$WORK_DIR/dir2" && try multirust override stable)
    expect_output_ok "nightly" rustc --version
    (cd "$WORK_DIR/dir1" && expect_output_ok "beta" rustc --version)
    (cd "$WORK_DIR/dir2" && expect_output_ok "stable" rustc --version)
}
runtest multiple_overrides

change_override() {
    try multirust override nightly
    try multirust override beta
    expect_output_ok "beta" rustc --version
}
runtest change_override

show_override() {
    try multirust override nightly
    expect_output_ok "override toolchain: nightly" multirust show-override
    expect_output_ok "override reason: directory override for '`pwd`'" multirust show-override
    expect_output_ok "override location: $MULTIRUST_HOME/toolchains/nightly" multirust show-override
    expect_output_ok "hash-nightly-2" multirust show-override
}
runtest show_override

show_override_no_override() {
    try multirust default nightly
    expect_output_ok "no override" multirust show-override
}
runtest show_override_no_override

show_override_no_override_no_default() {
    expect_output_ok "no override" multirust show-override
}
runtest show_override_no_override_no_default

show_override_no_override_show_default() {
    try multirust default nightly
    expect_output_ok "no override" multirust show-override
    expect_output_ok "default toolchain: nightly" multirust show-override
}
runtest show_override_no_override_show_default

show_override_from_MULTIRUST_TOOLCHAIN() {
    try multirust update beta
    try multirust override nightly
    export MULTIRUST_TOOLCHAIN=beta
    expect_output_ok "override toolchain: beta" multirust show-override
    expect_output_ok "override reason: environment override" multirust show-override
    expect_output_ok "override location: $MULTIRUST_HOME/toolchains/beta" multirust show-override
    expect_output_ok "hash-beta-2" multirust show-override
    unset MULTIRUST_TOOLCHAIN
}
runtest show_override_from_MULTIRUST_TOOLCHAIN

remove_override_no_default() {
    try multirust override nightly
    try multirust remove-override
    expect_output_fail "no default toolchain configured" rustc
}
runtest remove_override_no_default

remove_override_with_default() {
    try multirust default nightly
    try multirust override beta
    try multirust remove-override
    expect_output_ok "nightly" rustc --version
}
runtest remove_override_with_default

remove_override_with_multiple_overrides() {
    mkdir -p "$WORK_DIR/dir1"
    mkdir -p "$WORK_DIR/dir2"
    try multirust default nightly
    (cd "$WORK_DIR/dir1" && try multirust override beta)
    (cd "$WORK_DIR/dir2" && try multirust override stable)
    expect_output_ok "nightly" rustc --version
    (cd "$WORK_DIR/dir1" && try multirust remove-override)
    (cd "$WORK_DIR/dir1" && expect_output_ok "nightly" rustc --version)
    (cd "$WORK_DIR/dir2" && expect_output_ok "stable" rustc --version)
}
runtest remove_override_with_multiple_overrides

custom_no_installer_specified() {
    expect_output_fail "unspecified installer" multirust update nightly --installer
}
runtest custom_no_installer_specified

custom_invalid_names() {
    expect_output_fail "invalid custom toolchain name: 'nightly'" \
    multirust update nightly --installer "$local_custom_rust"
    expect_output_fail "invalid custom toolchain name: 'beta'" \
    multirust update beta --installer "$local_custom_rust"
    expect_output_fail "invalid custom toolchain name: 'stable'" \
    multirust update stable --installer "$local_custom_rust"
}
runtest custom_invalid_names

custom_invalid_names_with_archive_dates() {
    expect_output_fail "invalid custom toolchain name: 'nightly-2015-01-01'" \
    multirust update nightly-2015-01-01 --installer "$local_custom_rust"
    expect_output_fail "invalid custom toolchain name: 'beta-2015-01-01'" \
    multirust update beta-2015-01-01 --installer "$local_custom_rust"
    expect_output_fail "invalid custom toolchain name: 'stable-2015-01-01'" \
    multirust update stable-2015-01-01 --installer "$local_custom_rust"
}
runtest custom_invalid_names_with_archive_dates

custom_local() {
    try multirust update custom --installer "$local_custom_rust"
    try multirust default custom
    expect_output_ok nightly rustc --version
}
runtest custom_local

custom_remote() {
    try multirust update custom --installer "$remote_custom_rust"
    try multirust default custom
    expect_output_ok nightly rustc --version
}
runtest custom_remote

custom_multiple_local() {
    try multirust update custom --installer "$local_custom_rustc,$local_custom_cargo"
    try multirust default custom
    expect_output_ok nightly rustc --version
    expect_output_ok nightly cargo --version
}
runtest custom_multiple_local

custom_multiple_remote() {
    try multirust update custom --installer "$remote_custom_rustc,$remote_custom_cargo"
    try multirust default custom
    expect_output_ok nightly rustc --version
    expect_output_ok nightly cargo --version
}
runtest custom_multiple_remote

remove_custom() {
    try multirust update custom --installer "$remote_custom_rustc,$remote_custom_cargo"
    try multirust remove-toolchain custom
    expect_output_ok "no installed toolchains" multirust list-toolchains
}
runtest remove_custom

update_toolchain_linking_path() {
    try multirust update custom --link-local "$CUSTOM_TOOLCHAINS/2015-01-01"
    try multirust default custom
    expect_output_ok "hash-stable-1" rustc --version
}
runtest update_toolchain_linking_path

update_toolchain_from_path() {
    try multirust update custom --copy-local "$CUSTOM_TOOLCHAINS/2015-01-01"
    try multirust default custom
    expect_output_ok "hash-stable-1" rustc --version
}
runtest update_toolchain_from_path

update_toolchain_change_from_copy_to_link() {
    try multirust update custom --copy-local "$CUSTOM_TOOLCHAINS/2015-01-01"
    try multirust default custom
    expect_output_ok "hash-stable-1" rustc --version
    try multirust update custom --link-local "$CUSTOM_TOOLCHAINS/2015-01-02"
    try multirust default custom
    expect_output_ok "hash-stable-2" rustc --version
}
runtest update_toolchain_change_from_copy_to_link

update_toolchain_change_from_link_to_copy() {
    try multirust update custom --link-local "$CUSTOM_TOOLCHAINS/2015-01-01"
    try multirust default custom
    expect_output_ok "hash-stable-1" rustc --version
    try multirust update custom --copy-local "$CUSTOM_TOOLCHAINS/2015-01-02"
    try multirust default custom
    expect_output_ok "hash-stable-2" rustc --version
}
runtest update_toolchain_change_from_link_to_copy

custom_dir_invalid_names() {
    expect_output_fail "invalid custom toolchain name: 'nightly'" \
    multirust update nightly --copy-local "$CUSTOM_TOOLCHAINS/2015-01-01"
    expect_output_fail "invalid custom toolchain name: 'beta'" \
    multirust update beta --copy-local "$CUSTOM_TOOLCHAINS/2015-01-01"
    expect_output_fail "invalid custom toolchain name: 'stable'" \
    multirust update stable --copy-local "$CUSTOM_TOOLCHAINS/2015-01-01"
}
runtest custom_dir_invalid_names

custom_without_rustc() {
    rm -Rf "$CUSTOM_TOOLCHAINS/broken"
    cp -R "$CUSTOM_TOOLCHAINS/2015-01-01" "$CUSTOM_TOOLCHAINS/broken"
    rm "$CUSTOM_TOOLCHAINS/broken/bin/rustc"
    expect_output_fail "no rustc in custom toolchain at " \
    multirust update custom --copy-local "$CUSTOM_TOOLCHAINS/broken"
    rm -Rf "$CUSTOM_TOOLCHAINS/broken"
}
runtest custom_without_rustc

no_update_on_channel_when_data_has_not_changed() {
    try multirust update nightly
    expect_output_ok "'nightly' is already up to date" multirust update nightly
}
runtest no_update_on_channel_when_data_has_not_changed

update_on_channel_when_data_has_changed() {
    set_current_dist_date 2015-01-01
    try multirust default nightly
    expect_output_ok "hash-nightly-1" rustc --version
    set_current_dist_date 2015-01-02
    try multirust update nightly
    expect_output_ok "hash-nightly-2" rustc --version
}
runtest update_on_channel_when_data_has_changed

with_multirust_from_v1_error() {
    # No windows support in v1
    if [ "$is_windows" != true ]; then
        try "$MULTIRUST_BIN_DIR_V1/multirust" default nightly
        expect_output_fail "metadata version is 1, need 2" multirust default nightly
    fi
}
runtest with_multirust_from_v1_error

upgrade_from_v1_to_v2() {
    if [ "$is_windows" != true ]; then
        try "$MULTIRUST_BIN_DIR_V1/multirust" default nightly
        try multirust upgrade-data
        try multirust default nightly
    fi
}
runtest upgrade_from_v1_to_v2

update_no_toolchain_means_update_all() {
    set_current_dist_date 2015-01-01
    try multirust update
    expect_output_ok "using existing"  multirust default nightly
    expect_output_ok "hash-nightly-1" rustc --version
    expect_output_ok "using existing"  multirust default beta
    expect_output_ok "hash-beta-1" rustc --version
    expect_output_ok "using existing"  multirust default stable
    expect_output_ok "hash-stable-1" rustc --version
    set_current_dist_date 2015-01-02
    expect_output_ok "updating existing"  multirust update nightly
    try multirust update
    expect_output_ok "using existing"  multirust default nightly
    expect_output_ok "hash-nightly-2" rustc --version
    expect_output_ok "using existing"  multirust default beta
    expect_output_ok "hash-beta-2" rustc --version
    expect_output_ok "using existing"  multirust default stable
    expect_output_ok "hash-stable-2" rustc --version
}
runtest update_no_toolchain_means_update_all

run_command() {
    try multirust update nightly
    try multirust default beta
    expect_output_ok "nightly" multirust run nightly rustc --version
}
runtest run_command

remove_toolchain_then_add_again() {
    # Issue 53
    try multirust default beta
    try multirust remove-toolchain beta
    try multirust update beta
    try rustc --version
}
runtest remove_toolchain_then_add_again

ctl_default_toolchain_no_default() {
    expect_output_fail "no default toolchain configured" multirust ctl default-toolchain
}
runtest ctl_default_toolchain_no_default

ctl_default_toolchain_with_default_no_override() {
    try multirust default beta
    expect_output_ok "beta" multirust ctl default-toolchain
}
runtest ctl_default_toolchain_with_default_no_override

ctl_default_toolchain_with_default_and_override() {
    try multirust default beta
    try multirust override nightly
    expect_output_ok "beta" multirust ctl default-toolchain
}
runtest ctl_default_toolchain_with_default_and_override

list_available_targets_no_toolchain() {
    expect_output_fail "toolchain 'bogus' is not installed" multirust list-available-targets bogus 
}
runtest list_available_targets_no_toolchain

list_available_targets() {
    try multirust default nightly
    expect_output_ok "$CROSS_ARCH1" multirust list-available-targets nightly
    expect_output_ok "$CROSS_ARCH2" multirust list-available-targets nightly
}
runtest list_available_targets

add_target() {
    try multirust default nightly
    try multirust add-target nightly "$CROSS_ARCH1"
    try test -e "$MULTIRUST_HOME/toolchains/nightly/lib/rustlib/$CROSS_ARCH1/lib/libstd.rlib"
}
runtest add_target

add_target_bogus() {
    try multirust default nightly
    expect_output_fail "unable to find package url" multirust add-target nightly bogus
}
runtest add_target_bogus

add_target_no_toolchain() {
    expect_output_fail "toolchain 'bogus' is not installed" multirust add-target bogus "$CROSS_ARCH1"
}
runtest add_target_no_toolchain

echo
echo "SUCCESS!"
echo
