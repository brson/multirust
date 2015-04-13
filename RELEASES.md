# 0.0.3

* Built off of `rustup.sh`, includes `rustup.sh` in the installation.
* `multirust update`, without specifying a toolchain, will update all three of 'stable', 'beta'
  and 'nightly'.
* Added `multirust run <toolchain>`, which configures the environment of a subprocess
  so that multirust will use a specific toolchain.
* Removed update notifications. Just use `multirust update`, which will be a no-op if there's
  no new revision to install.
* multirust now can validate hashes with either sha256sum or shasum.
* Added `multirust upgrade-data` for upgrading metadata.
* Updated metadata format from version 1 to 2.
