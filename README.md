A simple tool for managing multiple installations of the Rust
toolchain. It replaces the standard Rust toolchain with components
that dynamically choose between alternate implementations based on
context.

Features:

* Manages multiple installations of official Rust binaries.
* Configure Rust revisions per-directory.
* Install and update from Rust release channels: nightly, beta, and
  stable.
* Receive notifications of updates to release channels.
* Install historical nightly toolchains from the official archives.
* Install by specific stable version number.
* Isolates Cargo metadata per-installation.
* Verifies hashes of downloads.
* Works on Linux and OS X.

# Usage

Installation:

```
git submodule update --init
./build.sh && sudo ./install.sh
```

*Warning: Uninstall Rust and Cargo before installing `multirust`.
Failure to do so will currently result in unknowable badness.*

Run `sudo ./install.sh --uninstall` to uninstall.

Initial configuration:

```
multirust default nightly
```

This will download and install the nightly compiler and package
manager and configure it as the default when executing `rustc`,
`rustdoc`, and `cargo`.

Overriding the compiler in specific directories:

```
mkdir beta-project && cd beta-project
multirust override beta
```

Now any time the toolchain is executed in the `beta-project`
directory or any subdirectory thereof the compiler from the beta
release channel will be used.

To pin to a specific nightly:

```
multirust override nightly-2014-12-18
```

Or a specific stable release:

```
multirust override 1.0.0
```

Information about the current override can be displayed with `multirust
show-override`. The current override can be deleted by running
`multirust delete-override` from the directory where the override was
created.

When using the 'stable', 'beta', or 'nightly' toolchains, the tools
will periodically notify you of updates:

```
cargo build
multirust: a new version of the 'nightly' release is available. run `multirust update nightly` to install it.
... normal output ...
```

In which case the toolchain can be updated with `multirust update
nightly`.

An alternate way of accessing multiple toolchains, `multirust alias
nightly` will produce new binaries called `rustc-nightly`,
`cargo-nightly`, and `rustdoc-nightly` that live in `~/.multirust/bin`
(add it to your `$PATH` to get access). `multirust alias nightly -g`
will add these commands globally, prompting for your password to call
`sudo`. At that point you can invoke `cargo-nightly` and it will use
the nightly toolchain. *Note: Not implemented. Requires cargo
modifications.*

# Toolchain specification

`multirust` supports several ways to indicate the toolchain: 'stable',
'beta' and 'nightly' all download from the corresponding release
channel. When any of these toolchain specifiers are used `multirust`
will periodically notify you of available updates. All three channels
can be optionally appended with an archive date, as in
'nightly-2014-12-18', in which case the toolchain is downloaded from
the archive for that date (if available). Any other specifier is
considered an explict Rust version number, as in '0.12.0'.

# Implementation Details

`multirust` installs a script called `multirustproxy` as all the tools
in the Rust toolchain: `rustc`, `cargo`, and `rustdoc`.  This script
consults `multirust` to decide which toolchain to invoke, and decides
which tool to invoke based on the name it is called as.

`multirustproxy` automatically applies `-C rpath` to all `rustc`
invocations so that the resulting binaries 'just work' when using
dynamic linking, even though the toolchains live in various places.

It keeps Cargo's metadata isolated per toolchain via the `CARGO_HOME`
environment variable.

# Limitations

* Installation of multirust over an existing installation of Rust or
  vice versa will cause brokenness. Uninstall the other first. This
  should be fixable in the future.
* The beta and stable release channel don't actually exist yet.
* The `rustc`, `cargo` and `rustdoc` commands should be symlinks to
  `rustcmdproxy` but are actually copies, a limitation of the
  installer.
* Definitely broken on windows.
* Concurrent writing of `multirust`'s metadata can possibly cause
  minor data loss in limited circumstances.
* Paths with tabs in their names will cause breakage when configured
  with overrides.
* Other unusual characters in paths may break overrides.
* Overrides at the filesystem root probably don't work.

# Future work

* Fix broken update notifications.
* Tests.
* Resume downloads.
* Check sigs.
* Check for and install updates of multirust itself.
* Windows support.
* One-liner installation.
* Allow creation of aliases like `rustc-0.12.0` (needs cargo to obey RUSTC and RUSTDOC env vars).
* GC unused toolchains.
* Cache installers to avoid redownloads? Maybe only useful for testing.
* override, show-override, remove-override could take an optional path.
* Allow management of custom toolchain builds.
* Install without docs? Saves lots of space.
* Teach multirust to uninstall itself.
* Support rust-lldb and rust-gdb.
  
# License

multirust is licensed under the same terms as the Rust compiler, now and
forevermore.
