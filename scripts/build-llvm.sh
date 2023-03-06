#!/bin/bash
set -e -o pipefail
source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )/globals.sh"

mkdir -p $BUILD_DIR/llvm
cd $BUILD_DIR/llvm

$BM_FORCE_FULL_REBUILD && rm -Rf *

BUILD_TYPE_OPTIONS=(-DCMAKE_BUILD_TYPE=MinSizeRel)

if [ "$BM_LLVM_BUILD_TYPE" = "fast" ]; then # TODO: Is it really faster?
    BUILD_TYPE_OPTIONS=(-DCMAKE_BUILD_TYPE=Release -DCMAKE_CXX_FLAGS_RELEASE="-g0 -O0")
elif [ "$BM_LLVM_BUILD_TYPE" = "lto" ]; then
    BUILD_TYPE_OPTIONS=(-DCMAKE_BUILD_TYPE=MinSizeRel -DLLVM_ENABLE_LTO=ON)
elif [ "$BM_LLVM_BUILD_TYPE" = "debug" ]; then
    BUILD_TYPE_OPTIONS=(-DCMAKE_BUILD_TYPE=Debug)
fi

[ -e build.ninja ] || \
    cmake -G Ninja \
    -DCMAKE_INSTALL_PREFIX=/$(realpath --relative-to=$INSTALL_ROOT $INSTALL_DIR) \
    -DLLVM_INSTALL_BINUTILS_SYMLINKS=TRUE \
    -DCMAKE_OSX_ARCHITECTURES="arm64;x86_64" \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=11.0 \
    "${BUILD_TYPE_OPTIONS[@]}" \
    -DLLVM_ENABLE_LTO=OFF \
    -DLLVM_ENABLE_TERMINFO=OFF \
    -DLLVM_ENABLE_ZLIB=OFF \
    -DLLVM_ENABLE_ZSTD=OFF \
    -DLLVM_ENABLE_LIBXML2=OFF \
    -DLLVM_HAVE_LIBXAR=OFF \
    -DLLVM_STATIC_LINK_CXX_STDLIB=ON \
    -DLLVM_ENABLE_PROJECTS="lld;clang;clang-tools-extra" \
    -DLLVM_TARGETS_TO_BUILD=WebAssembly \
    -DLLVM_DEFAULT_TARGET_TRIPLE=$TRIPLE \
    -DDEFAULT_SYSROOT=wasm-baremetal-pico \
    $EXT_DIR/llvm-project/llvm

$BM_CONFIGURE_ONLY && exit

DESTDIR=$INSTALL_ROOT \
    ninja $NINJA_FLAGS $NINJA_LLVM_FLAGS \
    install-clang \
    install-clang-format \
    install-clang-tidy \
    install-clang-apply-replacements \
    install-lld \
    install-llvm-mc \
    install-llvm-ranlib \
    install-llvm-strip \
    install-llvm-dwarfdump \
    install-clang-resource-headers \
    install-ar \
    install-llvm-as \
    install-ranlib \
    install-strip \
    install-nm \
    install-size \
    install-strings \
    install-objdump \
    install-objcopy \
    install-c++filt \
    install-llc \
    llvm-config
