# creds

Credentials backup and restore.

- [creds](#creds)
  - [Running Script](#running-script)
    - [Encrypt and Package](#encrypt-and-package)
    - [Decrypt and Un-Pack](#decrypt-and-un-pack)

## Running Script

### Encrypt and Package

Encrypt and package credentials and other files, preserving directory locations:

    ./creds.sh [-a <ADDITIONAL_DIRS>]

where `ADDITIONAL_DIRS` is a comma separated string, to list any directories
that shall be included in the package.

### Decrypt and Un-Pack

The [encrypted package](#encrypt-and-package) can be unpacked back into the
originating directories' locations:

    ./creds.sh -x [FILE]

The latest file will be selected for decryption and unpacking, OR
if `FILE` is specified, then this file will be decrypted and unpacked.
