#!/bin/bash
set -e -o pipefail
SCRIPTS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

SCRIPTS_DIR=$(realpath $SCRIPTS_DIR)
ROOT=$(realpath $SCRIPTS_DIR/..)
EXT_DIR=$ROOT/ext
INSTALL_ROOT=$ROOT/install
INSTALL_DIR=$INSTALL_ROOT/opt/wasm-baremetal
BUILD_DIR=$ROOT/build

TRIPLE=wasm32-unknown-unknown
