#!/bin/bash
set -e -o pipefail
source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )/globals.sh"

# Configuration with picolibc

SYSROOT=wasm-baremetal-pico
LIBC=picolibc
PICOLIBC_MESON_FLAGS=
