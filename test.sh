#!/bin/sh

# TODO update notifications
# TODO CARGO_HOME
# TODO rpath
# TODO non-absolute MULTIRUST_HOME

set -e -u

S="$(cd $(dirname $0) && pwd)"

TMP_DIR="$S/tmp"
MOCK_DIST_DIR="$S/tmp/mock-dist"
CUSTOM_TOOLCHAINS="$S/tmp/custom-toolchains"

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
WORK_DIR="$S/tmp/work"
MOCK_BUILD_DIR="$S/tmp/mock-build"
MULTIRUST_HOME="$(cd "$TMP_DIR" && pwd)/multirust"
VERSION=0.0.1
MULTIRUST_BIN_DIR="$S/build/work/multirust-$VERSION/bin"

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
    if [ $? -ne 0 ]
    then
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
    elif [ -n "${VERBOSE-}" ]; then
	echo \$ "$_cmd"
	/bin/echo "$_output"
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
    elif [ -n "${VERBOSE-}" ]; then
	echo \$ "$_cmd"
	/bin/echo "$_output"
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
    elif [ -n "${VERBOSE-}" ]; then
	echo \$ "$_cmd"
	/bin/echo "$_output"
	echo
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
    elif [ -n "${VERBOSE-}" ]; then
	echo \$ "$_cmd"
	/bin/echo "$_output"
	echo
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
    elif [ -n "${VERBOSE-}" ]; then
	echo \$ "$_cmd"
	/bin/echo "$_output"
	echo
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
    # Copy the intermediate installers too, though without manifests, checksums, etc.
    cp "$MOCK_BUILD_DIR/pkg"/* "$MOCK_DIST_DIR/dist/$_date/"
    cp "$MOCK_BUILD_DIR/pkg"/* "$MOCK_DIST_DIR/dist/"

    mkdir -p "$CUSTOM_TOOLCHAINS/$_date"

    for t in "$MOCK_BUILD_DIR/pkg"/*.tar.gz;
    do
	tar xzf "$t" --strip 1 -C "$CUSTOM_TOOLCHAINS/$_date/"
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

# Build the mock revisions
build_mocks

# Build bultirust
say "building multirust"
try sh "$S/build.sh"

# Tell multirust where to put .multirust
export MULTIRUST_HOME
# Tell multirust what key to use to verify sigs
export MULTIRUST_GPG_KEY

# Tell multirust where to download stuff from
MULTIRUST_DIST_SERVER="file://$(cd "$MOCK_DIST_DIR" && pwd)"
export MULTIRUST_DIST_SERVER

# Set up the PATH to find multirust
PATH="$MULTIRUST_BIN_DIR:$PATH"
export PATH

# Don't run the async updates. Otherwise the extra process
# may futz with our files and break subsequent tests.
export MULTIRUST_DISABLE_UPDATE_CHECKS=1

pre "no args"
expect_output_ok "Usage" multirust

pre "uninitialized"
expect_fail rustc
expect_output_fail "no default toolchain configured" rustc
# FIXME: This should succeed and say 'no default'
expect_output_fail "no default toolchain configured" multirust show-default

pre "default toolchain"
try multirust default nightly
expect_output_ok "nightly" multirust show-default

pre "expected bins exist"
try multirust default nightly
expect_output_ok "1.1.0" rustc --version
expect_output_ok "1.1.0" rustdoc --version
expect_output_ok "1.1.0" cargo --version

pre "install toolchain from channel"
try multirust default nightly
expect_output_ok "hash-nightly-2" rustc --version
try multirust default beta
expect_output_ok "hash-beta-2" rustc --version
try multirust default stable
expect_output_ok "hash-stable-2" rustc --version

pre "install toolchain from archive"
try multirust default nightly-2015-01-01
expect_output_ok "hash-nightly-1" rustc --version
try multirust default beta-2015-01-01
expect_output_ok "hash-beta-1" rustc --version
try multirust default stable-2015-01-01
expect_output_ok "hash-stable-1" rustc --version

pre "install toolchain linking from path"
try multirust default default-from-path --link-local "$CUSTOM_TOOLCHAINS/2015-01-01"
expect_output_ok "hash-stable-1" rustc --version

pre "install toolchain from path"
try multirust default default-from-path --copy-local "$CUSTOM_TOOLCHAINS/2015-01-01"
expect_output_ok "hash-stable-1" rustc --version


pre "install toolchain from version"
try multirust default 1.1.0
expect_output_ok "hash-stable-2" rustc --version

pre "default existing toolchain"
try multirust update nightly
expect_output_ok "using existing install for 'nightly'" multirust default nightly

pre "update channel"
set_current_dist_date 2015-01-01
try multirust default nightly
expect_output_ok "hash-nightly-1" rustc --version
set_current_dist_date 2015-01-02
try multirust update nightly
expect_output_ok "hash-nightly-2" rustc --version

pre "list toolchains"
try multirust update nightly
try multirust update beta-2015-01-01
expect_output_ok "nightly" multirust list-toolchains
expect_output_ok "beta-2015-01-01" multirust list-toolchains

pre "list toolchain with none"
try multirust list-toolchains
expect_output_ok "no installed toolchains" multirust list-toolchains

pre "remove toolchain"
try multirust update nightly
try multirust remove-toolchain nightly
try multirust list-toolchains
expect_output_ok "no installed toolchains" multirust list-toolchains

pre "remove active toolchain error handling"
try multirust default nightly
try multirust remove-toolchain nightly
expect_output_fail "toolchain 'nightly' not installed" rustc

pre "bad sha on manifest"
manifest_hash="$MOCK_DIST_DIR/dist/channel-rust-nightly.sha256"
sha=`cat "$manifest_hash"`
echo "$sha" | sed s/^......../aaaaaaaa/ >  "$manifest_hash"
expect_output_fail "checksum failed" multirust default nightly
set_current_dist_date 2015-01-02

pre "bad sha on installer"
for i in "$MOCK_DIST_DIR/dist"/*.sha256; do
    sha=`cat "$i"`
    echo "$sha" | sed s/^......../aaaaaaaa/ > "$i"
done
expect_output_fail "checksum failed" multirust default 1.0.0
set_current_dist_date 2015-01-02

pre "delete data"
try multirust default nightly
if [ ! -d "$MULTIRUST_HOME" ]; then
    fail "no multirust dir"
fi
try multirust delete-data -y
if [ -d "$MULTIRUST_HOME" ]; then
    fail "multirust dir not removed"
fi

pre "install override toolchain from channel"
try multirust override nightly
expect_output_ok "hash-nightly-2" rustc --version
try multirust override beta
expect_output_ok "hash-beta-2" rustc --version
try multirust override stable
expect_output_ok "hash-stable-2" rustc --version

pre "install override toolchain from archive"
try multirust override nightly-2015-01-01
expect_output_ok "hash-nightly-1" rustc --version
try multirust override beta-2015-01-01
expect_output_ok "hash-beta-1" rustc --version
try multirust override stable-2015-01-01
expect_output_ok "hash-stable-1" rustc --version

pre "install override toolchain linking path"
try multirust override stable-from-path --link-local "$CUSTOM_TOOLCHAINS/2015-01-01"
expect_output_ok "hash-stable-1" rustc --version

pre "install override toolchain from path"
try multirust override stable-from-path --copy-local "$CUSTOM_TOOLCHAINS/2015-01-01"
expect_output_ok "hash-stable-1" rustc --version

pre "install override toolchain from version"
try multirust override 1.1.0
expect_output_ok "hash-stable-2" rustc --version

pre "override overrides default"
try multirust default nightly
try multirust override beta
expect_output_ok "beta" rustc --version

pre "multiple overrides"
mkdir -p "$WORK_DIR/dir1"
mkdir -p "$WORK_DIR/dir2"
try multirust default nightly
(cd "$WORK_DIR/dir1" && try multirust override beta)
(cd "$WORK_DIR/dir2" && try multirust override stable)
expect_output_ok "nightly" rustc --version
(cd "$WORK_DIR/dir1" && expect_output_ok "beta" rustc --version)
(cd "$WORK_DIR/dir2" && expect_output_ok "stable" rustc --version)

pre "change override"
try multirust override nightly
try multirust override beta
expect_output_ok "beta" rustc --version

pre "show override"
try multirust override nightly
expect_output_ok "override toolchain: nightly" multirust show-override
expect_output_ok "override directory: `pwd`" multirust show-override
expect_output_ok "override location: $MULTIRUST_HOME/toolchains/nightly" multirust show-override
expect_output_ok "hash-nightly-2" multirust show-override

pre "show override no override"
try multirust default nightly
expect_output_ok "no override" multirust show-override

pre "show override no override no default"
expect_output_ok "no override" multirust show-override

pre "remove override no default"
try multirust override nightly
try multirust remove-override
expect_output_fail "no default toolchain configured" rustc

pre "remove override with default"
try multirust default nightly
try multirust override beta
try multirust remove-override
expect_output_ok "nightly" rustc --version

pre "remove override with multiple overrides"
mkdir -p "$WORK_DIR/dir1"
mkdir -p "$WORK_DIR/dir2"
try multirust default nightly
(cd "$WORK_DIR/dir1" && try multirust override beta)
(cd "$WORK_DIR/dir2" && try multirust override stable)
expect_output_ok "nightly" rustc --version
(cd "$WORK_DIR/dir1" && try multirust remove-override)
(cd "$WORK_DIR/dir1" && expect_output_ok "nightly" rustc --version)
(cd "$WORK_DIR/dir2" && expect_output_ok "stable" rustc --version)

pre "update checks"
unset MULTIRUST_DISABLE_UPDATE_CHECKS
set_current_dist_date 2015-01-01
try multirust default nightly
try rustc
try sleep 0.1
echo "not todays date" > "$MULTIRUST_HOME/update-stamp"
set_current_dist_date 2015-01-02
try rustc
try sleep 0.1
expect_output_ok "a new version of 'nightly' is available" rustc
expect_output_ok "a new version of 'nightly' is available" cargo
expect_output_ok "a new version of 'nightly' is available" rustdoc
try multirust update nightly
expect_not_output_ok "a new version of 'nightly' is available" rustc
expect_not_output_ok "a new version of 'nightly' is available" cargo
expect_not_output_ok "a new version of 'nightly' is available" rustdoc
export MULTIRUST_DISABLE_UPDATE_CHECKS=1

pre "update notifications not displayed for version flags"
unset MULTIRUST_DISABLE_UPDATE_CHECKS
set_current_dist_date 2015-01-01
try multirust default nightly
try rustc --version
try sleep 0.1
echo "not todays date" > "$MULTIRUST_HOME/update-stamp"
set_current_dist_date 2015-01-02
try rustc --version
try sleep 0.1
expect_not_output_ok "a new version of 'nightly' is available" rustc --version
expect_not_output_ok "a new version of 'nightly' is available" rustc -V
expect_not_output_ok "a new version of 'nightly' is available" cargo --version
expect_not_output_ok "a new version of 'nightly' is available" cargo -V
expect_not_output_ok "a new version of 'nightly' is available" rustdoc --version
expect_not_output_ok "a new version of 'nightly' is available" rustdoc -V
expect_not_output_ok "a new version of 'nightly' is available" rustc --print
expect_not_output_ok "a new version of 'nightly' is available" rustc --print=crate-name
export MULTIRUST_DISABLE_UPDATE_CHECKS=1

# Names of custom installers
get_architecture
arch="$RETVAL"
local_custom_rust="$MOCK_DIST_DIR/dist/rust-nightly-$arch.tar.gz"
local_custom_rustc="$MOCK_DIST_DIR/dist/rustc-nightly-$arch.tar.gz"
local_custom_cargo="$MOCK_DIST_DIR/dist/cargo-nightly-$arch.tar.gz"
remote_custom_rust="$MULTIRUST_DIST_SERVER/dist/rust-nightly-$arch.tar.gz"
remote_custom_rustc="$MULTIRUST_DIST_SERVER/dist/rustc-nightly-$arch.tar.gz"
remote_custom_cargo="$MULTIRUST_DIST_SERVER/dist/cargo-nightly-$arch.tar.gz"

pre "custom no installer specified"
expect_output_fail "unspecified installer" multirust update nightly --custom

pre "custom invalid names"
expect_output_fail "invalid custom toolchain name: 'nightly'" \
    multirust update nightly --custom "$local_custom_rust"
expect_output_fail "invalid custom toolchain name: 'beta'" \
    multirust update beta --custom "$local_custom_rust"
expect_output_fail "invalid custom toolchain name: 'stable'" \
    multirust update stable --custom "$local_custom_rust"

pre "custom local"
try multirust update custom --custom "$local_custom_rust"
try multirust default custom
expect_output_ok nightly rustc --version

pre "custom remote"
try multirust update custom --custom "$remote_custom_rust"
try multirust default custom
expect_output_ok nightly rustc --version

pre "custom multiple local"
try multirust update custom --custom "$local_custom_rustc,$local_custom_cargo"
try multirust default custom
expect_output_ok nightly rustc --version
expect_output_ok nightly cargo --version

pre "custom multiple remote"
try multirust update custom --custom "$remote_custom_rustc,$remote_custom_cargo"
try multirust default custom
expect_output_ok nightly rustc --version
expect_output_ok nightly cargo --version

pre "remove custom"
try multirust update custom --custom "$remote_custom_rustc,$remote_custom_cargo"
try multirust remove-toolchain custom
expect_output_ok "no installed toolchains" multirust list-toolchains

pre "update toolchain linking path"
try multirust update custom --link-local "$CUSTOM_TOOLCHAINS/2015-01-01"
try multirust default custom
expect_output_ok "hash-stable-1" rustc --version

pre "update toolchain from path"
try multirust update custom --copy-local "$CUSTOM_TOOLCHAINS/2015-01-01"
try multirust default custom
expect_output_ok "hash-stable-1" rustc --version


