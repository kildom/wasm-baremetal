#!/bin/bash
set -e -o pipefail
source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )/globals.sh"

mkdir -p $BUILD_DIR/$SYSROOT/newlib
cd $BUILD_DIR/$SYSROOT/newlib

# TODO: Check if the changes requires automake and autoconf
# TODO: Is needed: --enable-newlib-multithread???

export CC=$INSTALL_DIR/bin/clang
export CFLAGS=-Oz
export INSTALL="install -C"
export RANLIB=$INSTALL_DIR/bin/ranlib

$BM_FORCE_FULL_REBUILD && rm -Rf *

[ -e Makefile ] || \
    $EXT_DIR/newlib-cygwin/newlib/configure \
    --prefix=/ \
    $NEWLIB_CONFIGURE_FLAGS

$BM_CONFIGURE_ONLY && exit

make -j`nproc` $NEWLIB_MAKE_FLAGS

rm -Rf $BUILD_DIR/$SYSROOT/newlib-install

DESTDIR=$BUILD_DIR/$SYSROOT/newlib-install \
    make install $NEWLIB_MAKE_FLAGS

for triple in "$BUILD_DIR/$SYSROOT/newlib-install/*"; do
    #ranlib install/$TRIPLE/lib/*.a #TODO: check if it is already done by the makefile
    rsync -cr $triple/ "$INSTALL_DIR/share/$SYSROOT"
done
