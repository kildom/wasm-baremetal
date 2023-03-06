#!/bin/bash
set -e -o pipefail
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
DIR=$(realpath $DIR)

INSTALL_DIR=$DIR/install
CLANG_VERSION=15.0.7
ESCAPE_SLASH=


function check_tools {
	cmake --version | head -n1
	ver=$(ninja --version)
	echo ninja version $ver
}


function llvm {
	mkdir -p $DIR/build/llvm
	pushd $DIR/build/llvm > /dev/null

	$rebuild && echo rm -Rf *

	[ -e build.ninja ] || \
		cmake -G Ninja \
		-DCMAKE_BUILD_TYPE=MinSizeRel \
		-DLLVM_ENABLE_TERMINFO=OFF \
		-DLLVM_ENABLE_ZLIB=OFF \
		-DLLVM_ENABLE_ZSTD=OFF \
		-DLLVM_STATIC_LINK_CXX_STDLIB=ON \
		-DLLVM_HAVE_LIBXAR=OFF \
		-DCMAKE_OSX_ARCHITECTURES="arm64;x86_64" \
		-DCMAKE_OSX_DEPLOYMENT_TARGET=11.0 \
		-DCMAKE_INSTALL_PREFIX=/opt/wasm-baremetal \
		-DLLVM_TARGETS_TO_BUILD=WebAssembly \
		-DLLVM_DEFAULT_TARGET_TRIPLE=wasm32-unknown-unknown \
		-DLLVM_ENABLE_PROJECTS="lld;clang;clang-tools-extra" \
		-DLLVM_INSTALL_BINUTILS_SYMLINKS=TRUE \
		-DLLVM_ENABLE_LIBXML2=OFF \
		-DDEFAULT_SYSROOT=wasm32-unknown-unknown \
		$DIR/llvm-project/llvm

	$configure || \
		DESTDIR=$INSTALL_DIR \
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

	popd > /dev/null
}

function compiler-rt {
	mkdir -p $DIR/build/compiler-rt
	pushd $DIR/build/compiler-rt > /dev/null

	$rebuild && echo rm -Rf *

	[ -e build.ninja ] || \
		cmake -G Ninja \
		-DCMAKE_C_COMPILER_WORKS=ON \
		-DCMAKE_CXX_COMPILER_WORKS=ON \
		-DCMAKE_AR=$INSTALL_DIR/opt/wasm-baremetal/bin/ar \
		-DCMAKE_BUILD_TYPE=MinSizeRel \
		-DCMAKE_TOOLCHAIN_FILE=$DIR/wasm-baremetal.cmake \
		-DCOMPILER_RT_BAREMETAL_BUILD=On \
		-DCOMPILER_RT_BUILD_XRAY=OFF \
		-DCOMPILER_RT_INCLUDE_TESTS=OFF \
		-DCOMPILER_RT_HAS_FPIC_FLAG=OFF \
		-DCOMPILER_RT_ENABLE_IOS=OFF \
		-DCOMPILER_RT_DEFAULT_TARGET_ONLY=On \
		-DWASM_BM_SDK_PREFIX=$INSTALL_DIR/opt/wasm-baremetal \
		-DLLVM_CONFIG_PATH=$DIR/build/llvm/bin/llvm-config \
		-DCMAKE_INSTALL_PREFIX=/opt/wasm-baremetal/lib/clang/$CLANG_VERSION/ \
		-DCMAKE_VERBOSE_MAKEFILE:BOOL=ON \
		$DIR/llvm-project/compiler-rt/lib/builtins

	$configure || \
		DESTDIR=$INSTALL_DIR \
		ninja $NINJA_FLAGS $NINJA_COMPILER_RT_FLAGS \
		install

	# TODO: compile crt1.o to command mode "-mexec-model=command" and crt1-reactor.o reactor "-mexec-model=reactor"

	popd > /dev/null
}

function newlib {
	# TODO: compile automake and autoconf for newlib in correct versions... Check if the changes requires both automake and autoconf
	# export CC=.../clang
	# export CFLAGS=-Oz
	# $DIR/newlib-cygwin/newlib/configure --host=wasm32-unknown-unknown --disable-multilib --prefix=/home/doki/my/wasm-baremetal/install
	# Is needed: --enable-newlib-multithread???
	# make -j`nproc`
	# make install
	# TODO: clang requires libs with index, so ranlib is needed: ranlib install/wasm32-unknown-unknown/lib/*.a
	#       Check if it can be done by the newlib build system.
	echo OK
}

function libcxx {
	mkdir -p $DIR/build/libcxx
	pushd $DIR/build/libcxx > /dev/null

	[ -e build.ninja ] || cmake -G Ninja \
		-DCMAKE_C_COMPILER_WORKS=ON \
		-DCMAKE_CXX_COMPILER_WORKS=ON \
		-DCMAKE_AR=$INSTALL_DIR/opt/wasm-baremetal/bin/ar \
		-DCMAKE_TOOLCHAIN_FILE=$DIR/wasm-baremetal.cmake \
		-DCMAKE_STAGING_PREFIX=$ESCAPE_SLASH/wasm32-unknown-unknown \
		-DLLVM_CONFIG_PATH=$DIR/build/llvm/bin/llvm-config \
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
		-DLIBCXX_CXX_ABI_INCLUDE_PATHS=$DIR/llvm-project/libcxxabi/include \
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
		-DWASM_BM_SDK_PREFIX=$INSTALL_DIR/opt/wasm-baremetal \
		-DUNIX:BOOL=ON \
		-DCMAKE_SYSROOT=$INSTALL_DIR/wasm32-unknown-unknown \
		-DLIBCXX_LIBDIR_SUFFIX=$ESCAPE_SLASH/wasm32-unknown-unknown \
		-DLIBCXXABI_LIBDIR_SUFFIX=$ESCAPE_SLASH/wasm32-unknown-unknown \
		-DLLVM_ENABLE_RUNTIMES="libcxx;libcxxabi" \
		$DIR/llvm-project/runtimes

	DESTDIR=$INSTALL_DIR \
		ninja $NINJA_FLAGS $NINJA_COMPILER_RT_FLAGS \
		install # TODO: install overrides some header files from newlib - check what and why.
				# If this cannot be resolved, use a copy of sysroot to compile libcxx and install in actual sysroot (if possible)

	# TODO: compile crt1.o to command mode "-mexec-model=command" and crt1-reactor.o reactor "-mexec-model=reactor"

	popd > /dev/null
}

rebuild=false
configure=false
rebuild_def=false
configure_def=false
all=true

for arg in "$@"; do
	if [ "$arg" = "--rebuild" ]; then
		rebuild=true
	elif [ "$arg" = "--configure" ]; then
		configure=true
	elif [ "$arg" = "--rebuild-all" ]; then
		rebuild=true
		rebuild_def=true
	elif [ "$arg" = "--configure-all" ]; then
		configure=true
		configure_def=true
	else
		if [ "$arg" = "llvm" ]; then
			echo llvm
		elif [ "$arg" = "compiler-rt" ]; then
			compiler-rt
		elif [ "$arg" = "newlib" ]; then
			echo llvm
		elif [ "$arg" = "all" ]; then
			echo TODO: llvm
			newlib
		else
			echo "Unrecognized argument: $arg"
		fi
		rebuild=$rebuild_def
		configure=$configure_def
		all=false
	fi
done

if $all; then
	echo ALL
fi


#check_tools
#llvm
#compiler-rt
#newlib
#libcxx
# TODO: Compile libunwind from Emscripten repository with wasm-exceptions support.


true <<EOF

Some examples:

install/opt/wasm-baremetal/bin/clang++ a.cpp --sysroot /home/doki/my/wasm-baremetal/install/wasm32-unknown-unknown -mexec-model=reactor -o a.wat -Os -fwasm-exceptions -S -matomics -mbulk-memory

enable standard WASM exceptions: -fwasm-exceptions
enable threads, so wasm-exceptions landing pad will be put into Thread Local Storage: -matomics -mbulk-memory

EOF
