#!/bin/bash
set -e -o pipefail
source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )/globals.sh"

source $SCRIPTS_DIR/$1

# TODO: is it needed?
ESCAPE_SLASH=

mkdir -p $BUILD_DIR/$SYSROOT/libcxx
cd $BUILD_DIR/$SYSROOT/libcxx

$BM_FORCE_FULL_REBUILD && rm -Rf *

[ -e build.ninja ] || cmake -G Ninja \
    -DCMAKE_C_COMPILER_WORKS=ON \
    -DCMAKE_CXX_COMPILER_WORKS=ON \
    -DCMAKE_AR=$INSTALL_DIR/bin/ar \
    -DCMAKE_TOOLCHAIN_FILE=$ROOT/wasm-baremetal.cmake \
    -DCMAKE_STAGING_PREFIX=$ESCAPE_SLASH/wasm32-unknown-unknown \
    -DLLVM_CONFIG_PATH=$BUILD_DIR/llvm/bin/llvm-config \
    -DCMAKE_VERBOSE_MAKEFILE:BOOL=ON \
    -DCXX_SUPPORTS_CXX11=ON \
    -DLIBCXX_ENABLE_THREADS:BOOL=OFF \
    -DLIBCXX_HAS_PTHREAD_API:BOOL=OFF \
    -DLIBCXX_HAS_EXTERNAL_THREAD_API:BOOL=OFF \
    -DLIBCXX_BUILD_EXTERNAL_THREAD_LIBRARY:BOOL=OFF \
    -DLIBCXX_HAS_WIN32_THREAD_API:BOOL=OFF \
    -DLLVM_COMPILER_CHECKED=ON \
    -DCMAKE_BUILD_TYPE=RelWithDebugInfo \
    -DLIBCXX_ENABLE_SHARED:BOOL=OFF \
    -DLIBCXX_ENABLE_EXPERIMENTAL_LIBRARY:BOOL=OFF \
    -DLIBCXX_ENABLE_EXCEPTIONS:BOOL=ON \
    -DLIBCXX_ENABLE_FILESYSTEM:BOOL=OFF \
    -DLIBCXX_CXX_ABI=libcxxabi \
    -DLIBCXX_CXX_ABI_INCLUDE_PATHS=$EXT_DIR/llvm-project/libcxxabi/include \
    -DLIBCXX_HAS_MUSL_LIBC:BOOL=ON \
    -DLIBCXX_ABI_VERSION=2 \
    -DLIBCXXABI_ENABLE_EXCEPTIONS:BOOL=ON \
    -DLIBCXXABI_ENABLE_SHARED:BOOL=OFF \
    -DLIBCXXABI_SILENT_TERMINATE:BOOL=ON \
    -DLIBCXXABI_ENABLE_THREADS:BOOL=OFF \
    -DLIBCXXABI_HAS_PTHREAD_API:BOOL=OFF \
    -DLIBCXXABI_HAS_EXTERNAL_THREAD_API:BOOL=OFF \
    -DLIBCXXABI_BUILD_EXTERNAL_THREAD_LIBRARY:BOOL=OFF \
    -DLIBCXXABI_HAS_WIN32_THREAD_API:BOOL=OFF \
    -DLIBCXXABI_ENABLE_PIC:BOOL=OFF \
    -DWASM_BM_SDK_PREFIX=$INSTALL_DIR \
    -DUNIX:BOOL=ON \
    -DCMAKE_SYSROOT=$INSTALL_DIR/share/$SYSROOT \
    -DLIBCXX_LIBDIR_SUFFIX=/ \
    -DLIBCXXABI_LIBDIR_SUFFIX= \
    -DLLVM_ENABLE_RUNTIMES="libcxx;libcxxabi" \
    $EXT_DIR/llvm-project/runtimes

$BM_CONFIGURE_ONLY && exit

rm -Rf $BUILD_DIR/$SYSROOT/libcxx-install

DESTDIR=$BUILD_DIR/$SYSROOT/libcxx-install \
    ninja \
    install # TODO: install overrides some header files from newlib - check what and why.
            # If this cannot be resolved, use a copy of sysroot to compile libcxx and install in actual sysroot (if possible)

for triple in "$BUILD_DIR/$SYSROOT/libcxx-install/*"; do
    rsync -cr $triple/ "$INSTALL_DIR/share/$SYSROOT"
done
