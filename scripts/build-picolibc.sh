#!/bin/bash
set -e -o pipefail
source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )/globals.sh"

mkdir -p $BUILD_DIR/$SYSROOT/picolibc
cd $BUILD_DIR/$SYSROOT/picolibc

function create-venv {
    python3 -m venv $ROOT/.venv
    source $ROOT/.venv/bin/activate
    pip3 install meson
}

[ -e $ROOT/.venv ] || create-venv
source $ROOT/.venv/bin/activate

PATH=$INSTALL_DIR/bin:$PATH

$BM_FORCE_FULL_REBUILD && rm -Rf *

[ -e build.ninja ] || meson setup \
    -Dincludedir=include \
    -Dlibdir=lib \
    -Dpicocrt=false \
    -Dfast-strcmp=false \
    -Dmultilib=false \
    -Dsemihost=false \
    -Dspecsdir=none \
    -Dio-c99-formats=false \
    -Datomic-ungetc=false \
    -Dio-float-exact=false \
    -Dformat-default=integer \
    -Dthread-local-storage=false \
    -Dprefix=$INSTALL_DIR/share/$SYSROOT \
    --cross-file $SCRIPTS_DIR/cross-$TRIPLE.txt \
    $EXT_DIR/picolibc

$BM_CONFIGURE_ONLY && exit

ninja -v
ninja -v install

