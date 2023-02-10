# wasm-baremetal

C/C++ WebAssembly SDK without additional OS-like layers.

Goal is to create an SDK that you can use to create "baremetal" WebAssembly files.
You will have control on entire module interface (exports/imports) unlike other solutions like, WASI or Emscripten.

The SDK will contain:
 * Clang/LLVM compiler
 * Standard library - I am considering different options:
   * patched newlib with three options for "system calls": "do nothing" stubs, minimal stubs (e.g. only stdout/stderr redirected to user functions), no stubs (user is responsible for implementing it).
   * patched musl where `__syscall` is a macro that calls specific function (or function-like macro) e.g. `__syscall(SYS_lstat, path, &kst) -> syscall_SYS_lstat(path, &kst)`
   * or both to allow user to choose bigger or smaller, but with less functionality.
 * some samples
