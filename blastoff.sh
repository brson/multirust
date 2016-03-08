#!/bin/sh

say() {
    echo "blastoff: $1"
}

verbose_say() {
    if [ "$flag_verbose" = true ]; then
      say "$1"
    fi
}

err() {
    say "$1" >&2
    exit 1
}

need_cmd() {
    if ! command -v $1 > /dev/null 2>&1
    then err "need $1"
    fi
}

need_ok() {
    if [ $? != 0 ]; then
        err "$1"
    fi
}

assert_nz() {
    if [ -z "$1" ]; then
        err "assert_nz $2"
    fi
}

create_tmp_dir() {
    local tmp_dir="`pwd`/multirust-tmp-install"

    rm -Rf "${tmp_dir}"
    need_ok "failed to remove temporary installation directory"

    mkdir -p "${tmp_dir}"
    need_ok "failed to create create temporary installation directory"

    echo $tmp_dir
}

# Copied from rustup.sh
get_architecture() {

    verbose_say "detecting architecture"

    local _ostype="$(uname -s)"
    local _cputype="$(uname -m)"

    verbose_say "uname -s reports: $_ostype"
    verbose_say "uname -m reports: $_cputype"

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

    esac

    # Detect 64-bit linux with 32-bit userland
    if [ $_ostype = unknown-linux-gnu -a $_cputype = x86_64 ]; then
        # $SHELL does not exist in standard 'sh', so probably only exists
        # if configure is running in an interactive bash shell. /usr/bin/env
        # exists *everywhere*.
        local _bin_to_probe="${SHELL-bogus_shell}"
        if [ ! -e "$_bin_to_probe" -a -e "/usr/bin/env" ]; then
            _bin_to_probe="/usr/bin/env"
        fi
        if [ -e "$_bin_to_probe" ]; then
            file -L "$_bin_to_probe" | grep -q "x86[_-]64"
            if [ $? != 0 ]; then
                local _cputype=i686
            fi
        fi
    fi

    local _arch="$_cputype-$_ostype"
    verbose_say "architecture is $_arch"

    RETVAL="$_arch"
}

check_for_windows() {
    get_architecture
    case "$RETVAL" in
    *pc-windows*)
        return 0
        ;;
    *)
        return 1
        ;;
    esac
}

run() {
    need_cmd rm
    need_cmd git
    need_cmd sed
    need_cmd sh
    need_cmd sleep

    GIT_REPO=https://github.com/brson/multirust.git
    UNINSTALL=
    YES=

    for arg in "$@"; do
        case "$arg" in
            --uninstall)
            UNINSTALL=true
        ;;
            --yes)
            YES=true
        ;;
            *)
            err "unrecognized argument '$arg'"
        ;;
    esac
    done

    if [ ! -e "/dev/tty" ]; then
        err "/dev/tty does not exist"
    fi

    check_for_windows
    if [ "$?" = 0 ]; then
        local _is_windows=true
    else
        local _is_windows=false
    fi

    if [ "$_is_windows" = "false" ]; then
        if [ -z "$UNINSTALL" ]; then
            cat <<EOF

Welcome to Rust.

This script will download, build, and install multirust as root, then
configure multirust with the most common options. It may prompt for
your password for installation via 'sudo'.

You may run /usr/local/lib/rustlib/uninstall.sh to uninstall multirust.
EOF
       else
           echo "This script will uninstall multirust. It may prompt for your password via 'sudo'."
       fi
    else
        if [ -z "$UNINSTALL" ]; then
            cat <<EOF

Welcome to Rust.

This script will download, build, and install multirust as root, then
configure multirust with the most common options.

You may run /usr/local/lib/rustlib/uninstall.sh to uninstall multirust.
EOF
       else
           echo "This script will uninstall multirust."
       fi
    fi

    echo

    if [ -z "$YES" ]; then
        local _yn=""

        read -p "Ready? (y/N) " _yn < /dev/tty

        echo

        if [ "$_yn" != "y" -a "$_yn" != "Y" ]; then
            exit 0
        fi
    fi

    tmp_dir="$(mktemp -d 2>/dev/null \
    || mktemp -d -t 'rustup-tmp-install' 2>/dev/null \
    || create_tmp_dir)"
    if [ -z "$tmp_dir" ]; then
        err "empty temp dir"
    fi

    original_dir=`pwd`

    say "working in temporary directory $tmp_dir"
    cd "$tmp_dir"
    need_ok "failed to cd to temporary install directory"

    local _branch="${MULTIRUST_BLASTOFF_BRANCH-master}"

    # Clone git repo
    say "cloning multirust git repo"
    git clone "$GIT_REPO" -b "$_branch" --depth 1
    if [ $? != 0 ]; then
        cd "$original_dir" && rm -Rf "$tmp_dir"
        err "failed to clone git repo $GIT_REPO"
    fi
    cd multirust
    if [ $? != 0 ]; then
        cd "$original_dir" && rm -Rf "$tmp_dir"
        err "failed to cd to git repo"
    fi

    say "building"
    sh ./build.sh
    if [ $? != 0 ]; then
        cd "$original_dir" && rm -Rf "$tmp_dir"
        err "failed to build multirust"
    fi

    if [ -z "$UNINSTALL" ]; then
        say "installing"
        if [ "$_is_windows" = "false" ]; then
            sudo sh ./install.sh
        else
            sh ./install.sh
        fi
        if [ $? != 0 ]; then
            cd "$original_dir" && rm -Rf "$tmp_dir"
            err "failed to install multirust"
        fi
    else
        say "uninstalling"
        if [ "$_is_windows" = "false" ]; then
            sudo sh ./install.sh --uninstall
        else
            sh ./install.sh --uninstall
        fi
        if [ $? != 0 ]; then
            cd "$original_dir" && rm -Rf "$tmp_dir"
            err "failed to uninstall multirust"
        fi
    fi

    cd "$original_dir" && rm -Rf "$tmp_dir"
    need_ok "failed to remove temporary install directory"

    if [ -n "$UNINSTALL" ]; then
        exit 0
    fi

    if ! command -v multirust > /dev/null 2>&1; then
        err 'unable to run `multirust` after install. this is odd. not finishing configuration'
    fi

    say "installing stable toolchain"
    multirust default stable
    need_ok 'failed to install stable toolchain. if this appears to be a network problem retry with `multirust default stable`'

    say "all systems go"
}

run "$@"
