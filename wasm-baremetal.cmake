# Cmake toolchain description file for the Makefile

# This is arbitrary, AFAIK, for now.
cmake_minimum_required(VERSION 3.4.0)

set(CMAKE_SYSTEM_NAME .)
set(CMAKE_SYSTEM_VERSION 1)
set(CMAKE_SYSTEM_PROCESSOR wasm32)
set(triple wasm32-unknown-unknown)

if(WIN32)
	set(WASM_BM_HOST_EXE_SUFFIX ".exe")
else()
	set(WASM_BM_HOST_EXE_SUFFIX "")
endif()

set(CMAKE_C_COMPILER ${WASM_BM_SDK_PREFIX}/bin/clang${WASM_BM_HOST_EXE_SUFFIX})
set(CMAKE_CXX_COMPILER ${WASM_BM_SDK_PREFIX}/bin/clang++${WASM_BM_HOST_EXE_SUFFIX})
set(CMAKE_AR ${WASM_BM_SDK_PREFIX}/bin/llvm-ar${WASM_BM_HOST_EXE_SUFFIX})
set(CMAKE_RANLIB ${WASM_BM_SDK_PREFIX}/bin/llvm-ranlib${WASM_BM_HOST_EXE_SUFFIX})
set(CMAKE_C_COMPILER_TARGET ${triple})
set(CMAKE_CXX_COMPILER_TARGET ${triple})

# Don't look in the sysroot for executables to run during the build
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
# Only look in the sysroot (not in the host paths) for the rest
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)