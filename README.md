# wasm-baremetal

C/C++ WebAssembly SDK without additional OS-like layers.

Goal is to create an SDK that you can use to create "baremetal" WebAssembly files.
You will have control on entire module interface (exports/imports) unlike other solutions like, WASI or Emscripten.

The SDK will contain:
 * Clang/LLVM compiler
 * Standard library - I am considering different options:
   * patched newlib with three options for "system calls": "do nothing" stubs, minimal stubs (e.g. only stdout/stderr redirected to user functions), no stubs (user is responsible for implementing it).
   * patched musl where `__syscall` is a macro that calls specific function (or function-like macro) e.g. `__syscall(SYS_lstat, path, &kst) -> _CALL_SYS_lstat(path, &kst)`
   * or both to allow user to choose bigger or smaller, but with less functionality.
 * some samples

## Building

You can build SDK with a build script:
```bash
./build.sh
```

You can specify one or more targets, which can be:
* a name of a project: `llvm`, `compiler-rt`, `crt`, `libc`,`libcxx`, `libunwind`. If project exists on multiple configurations, then project will be compiled for all of them.
* a name of a project with configuration, e.g. `libunwind-newlib`.
* a name of configuration: `newlib`, `picolibc`, e.t.c. All projects with this configuration will be compiled.

By default, also all dependencies are also compiled. Prefix target with `only-` to compile only this target without its dependencies, e.g. `only-libunwind-newlib`.

You can pass environment variables to customize the build:
* `BM_FORCE_FULL_REBUILD` - before building any project, delete its content to force full configuration and build.
* `BM_CONFIGURE_ONLY` - stop build process of each project after configuration stage, do not compile it.
* `BM_NINJA_FLAGS` or `BM_NINJA_FLAGS_{project}` - Flags passed to ninja.
* `BM_MAKE_FLAGS` or `BM_MAKE_FLAGS_{project}`- Flags passed to make.
* `BM_LLVM_BUILD_TYPE` - How to compile Clang/LLVM:
  * *empty or not provided* - build optimized for size,
  * `fast` - fast building, unoptimized with no assertions or debug info,
  * `debug` - unoptimized build with assertions and debug info,
  * `lto` - build optimized for size with LTO (a lot of system memory required),

Where `{project}` can be: `LLVM`, `COMPILER_RT`, `CRT`, `LIBC`, `LIBCXX`, `LIBUNWIND`.