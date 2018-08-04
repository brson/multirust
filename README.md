**Note: multirust is not actively maintained. Migrate to [rustup.rs](https://github.com/rust-lang-nursery/rustup.rs) ([help](#migrating-to-rustup)).**

[![Build Status](https://travis-ci.org/brson/multirust.svg?branch=master)](https://travis-ci.org/brson/multirust)

A simple tool for managing multiple installations of the Rust
toolchain. It replaces the standard Rust toolchain with components
that dynamically choose between alternate implementations based on
context.

Features:

* Manage multiple installations of the official Rust binaries.
* Configure Rust toolchains per-directory.
* Install and update from Rust release channels: nightly, beta, and
  stable.
* Receive notifications of updates to release channels.
* Install historical nightly toolchains from the official archives.
* Install by specific stable version number.
* Install additional `std`s for cross-compilation.
* Install custom toolchains.
* Isolate Cargo metadata per-installation.
* Verify hashes of downloads.
* Verify signatures (if GPG is available).
* Resume partial downloads.
* Requires only bash, curl and common unix utilities.
* For Linux, OS X, and Windows (via MSYS2).

# Migrating to rustup

If you have multirust installed and you would like to migrate to rustup.rs,
follow these steps (for Linux/Mac):

1. First, uninstall Multirust using this command:
```
curl -sf https://raw.githubusercontent.com/brson/multirust/master/blastoff.sh | sh -s -- --uninstall
```
2. Delete the folder `~/.multirust`.
3. If the file `/usr/local/lib/rustlib/uninstall.sh` still exists, the uninstallation was not successful. Run `sudo /usr/local/lib/rustlib/uninstall.sh` to complete it.
4. Install rustup using the instructions at [rustup.rs](https://www.rustup.rs/).


# Quick installation

```
curl -sf https://raw.githubusercontent.com/brson/multirust/master/blastoff.sh | sh
```

This will build and install multirust, possibly prompting you for your
password via `sudo`. It will then download and install the stable
toolchain, configuring it as the default when executing `rustc`,
`rustdoc`, and `cargo`.


# Manual build, install and configure

A manual build and install allows one to tailor `multirust` to meet specific needs.

The basic template is:

```
git clone --recursive https://github.com/brson/multirust && cd multirust
git submodule update --init
./build.sh && sudo ./install.sh
```

Run `sudo ./install.sh --uninstall` to uninstall.

Run `multirust default nightly` to download and install the nightly
compiler and package manager and configure it as the default.

As an example customization, to install underneath your home
directory in e.g. `~/my_stuff/bin/multirust`, you could use:

```
./build.sh && ./install.sh --prefix=~/my_stuff/
```

(In this scenario, `./install.sh --prefix=~/my_stuff/ --uninstall` to uninstall.)

Run `./build.sh && ./install.sh --help` to see a list of available options.

# Usage

To install Rust, run `multirust update <toolchain>`. See `multirust help update` for
details and to configure what this will install.

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
`multirust remove-override` from the directory where the override was
created.

Check for updates with `multirust update nightly`. All three release
channels can be updated at once with `multirust update`.

`multirust run` will run an arbitrary command in an environment
configured for a given toolchain, so e.g. `multirust run beta cargo
build` will run the beta cargo, regardless of the current
override. This can also be used to e.g. open a beta shell like
`multirust run beta bash`.

Commands can be abbreviated by using a prefix of the intended command,
for example `multirust ru` (`run`) or `multirust s-o` (`show-override`).
In the case of an ambiguous prefix, it picks the first match using the
order of commands shown in `multirust help`.

# Toolchain specification

`multirust` supports several ways to indicate the toolchain: 'stable',
'beta' and 'nightly' all download from the corresponding release
channel. When any of these toolchain specifiers are used `multirust`
will periodically notify you of available updates. All three channels
can be optionally appended with an archive date, as in
'nightly-2014-12-18', in which case the toolchain is downloaded from
the archive for that date (if available). Any other specifier is
considered an explicit Rust version number, as in '0.12.0', or a custom
toolchain identifier, depending on context.

# Cross-compilation

`multirust` can install additional standard libraries for
cross-compilation targets. Once you have installed a toolchain, use
the `multirust list-available-targets` command to show which targets
can be added, and `multirust add-target` to add a target.

# Custom toolchains

Custom toolchains - those not distributed by The Rust Project - may be
installed from either custom-built installer or from a local directory
containing a build of Rust.

To install from an existing Rust build use either the `--copy-local`
or the `--link-local` flags to the `update` command. `--copy-local`
will copy a build of Rust to multirust's private toolchain
installation directory; `--link-local` will create a toolchain that is
a symlink to a build of Rust, convenient for those who frequently
build Rust themselves:

```
multirust update my-rust --link-local ~/dev/rust/build/x86_64-unknown-linux-gnu/stage2
```

A custom-built installer can be installed with `multirust update
<toolchain> --installer <installer-path-or-url>`, e.g. `multirust
update my-rust --installer
rust-1.0.0-dev-x86_64-unknown-linux-gnu.tar.gz`. In this case the
toolchain is installed via the specified installer and can then be
activated with `multirust default my-rust`.

Since the main Rust build does not produce an installer that includes
Cargo, it may be easier to install the individual rustc and cargo
installers instead of trying to produce the combined installer through
[rust-packaging](https://github.com/rust-lang/rust-packaging). For
this reason the `--installer` flag takes a comma-separated list of
installers, allowing custom rustc and cargo packages to be installed
with e.g.

```
multirust update my-rust --installer rustc-1.0.0-dev-x86_64-unknown-linux-gnu.tar.gz,cargo-nightly-x86_64-unknown-linux-gnu.tar.gz
```

These three options can also be supplied to the `default` and
`override` commands, in which case the toolchain is also
activated after installation.

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

`multirust` saves settings and toolchains per user in `~/.multirust`.
The directory is initialized when using the `multirust` command to
set the default channel, or when setting an override or updating for first time.
The name of this directory can be controlled with the `MULTIRUST_HOME`
environment variable.

# Can you trust Rust binaries?

Although multirust verifies signatures of its downloads if GPG is
available, the question of whether you can 'trust' Rust depends on
quite a few factors. Although I'm not prepared to give advice on this
subject, here are some of the details around how the Rust project
binaries are signed and verified. You can make your own judgments.

* Rust binaries are produced on mostly cloud infrastructure to which
  several people have access.
* They are signed automatically by a master bot that has access
  to a secret subkey of the Rust signing key.
* They are uploaded to s3 using a secret key on that same bot.
* The master bot is exposed to the Internet through an ssh tunnel via
  which it communicates with buildbot slaves.
* Rust binaries are served over HTTPS.
* The Rust public key is distributed as part of multirust.
* Rust is self-hosting, bootstrapped off of a chain of binary
  snapshots that extends back for several years, which are presently
  served over HTTPS (but have not always been), and are not
  cryptographically signed.

When GPG successfully verifies a signature from the Rust signing key
it will almost certainly emit a warning saying the key is untrusted:

```
gpg: Signature made Fri 09 Jan 2015 12:07:05 AM PST using RSA key ID 7B3B09DC
gpg: Good signature from "Rust Language (Tag and Release Signing Key) <rust-key@rust-lang.org>"
gpg: WARNING: This key is not certified with a trusted signature!
gpg:          There is no indication that the signature belongs to the owner.
Primary key fingerprint: 108F 6620 5EAE B0AA A8DD  5E1C 85AB 96E6 FA1B E5FE
     Subkey fingerprint: C134 66B7 E169 A085 1886  3216 5CB4 A934 7B3B 09DC
```

This is because the Rust signing key isn't known to be trusted by
others in your 'web of trust'. It isn't strictly a problem, assuming
that you trust the authors of multirust and the channel through which
you installed it.

If you are so inclined you can import the Rust signing key, and if it
happens to be in the same web of trust as your own trusted keys, then
the warnings may go away:

```
gpg --keyserver hkp://keys.gnupg.net --recv-keys 7B3B09DC
```

At the present time the certificate chain for the Rust signing key is
quite meager though so it's unlikely to help.

# Limitations

* Installation of multirust over an existing installation of Rust or
  vice versa will cause brokenness. Uninstall the other first.
  `./install.sh` will detect this and error. This should be fixable in
  the future.
* The `rustc`, `cargo` and `rustdoc` commands should be symlinks to
  `multirustproxy` but are actually copies, a limitation of the
  installer.
* Concurrent writing of `multirust`'s metadata can possibly cause
  minor data loss in limited circumstances.
* Paths with semicolons in their names will cause breakage when configured
  with overrides.
* Other unusual characters in paths may break overrides.
* Overrides at the filesystem root probably don't work.

# Future work

* Check for and install updates of multirust itself.
* Windows support.
* Allow creation of aliases like `rustc-0.12.0` (needs cargo to obey
  RUSTC and RUSTDOC env vars).
* GC unused toolchains.
* Cache installers to avoid redownloads? Maybe only useful for
  testing.
* override, show-override, remove-override could take an optional
  path.
* Install without docs? Saves lots of space.
* Teach multirust to uninstall itself.
* Handle temp file cleanup more consistently - always cleaned up on
  error unless requested otherwise.
* Use wget if curl isn't available?
* Command to check for and show available updates explicitly.
* Figure out what to do about command line completions for cargo,
  etc.
* Tests for various paths with spaces in them.
* Make blastoff script interactive: require confirmation to start and
  display a notice if gpg is not installed.
* Add a way to disable signature verification.
* There are probably ways to cause damage by trusting the user about
  what is and isn't a 'custom' toolchain.
* Refactor multirustproxy to use 'multirust run'.

# License

multirust is licensed under the same terms as the Rust compiler, now and
forevermore.
