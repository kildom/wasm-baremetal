#!/bin/bash
set -e -o pipefail
source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )/globals.sh"

# Configuration with single-threaded newlib

SYSROOT=wasm-baremetal-newlib
LIBC=newlib
NEWLIB_CONFIGURE_FLAGS="--host=$TRIPLE --disable-multilib"
