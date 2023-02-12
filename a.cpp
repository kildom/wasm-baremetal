
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <setjmp.h>

#define WASM_EXPORT(name) \
    __attribute__((used)) \
    __attribute__((export_name(#name)))

#define WASM_IMPORT(name) \
    __attribute__((used)) \
    __attribute__((import_name(#name)))

WASM_IMPORT(aa)
int aa(int);

struct Constr {
    int x;
    Constr(int p) {
        x = aa(12 + p);
    }
};

Constr ca(1);
Constr cb(2);

uint32_t swap(uint32_t x) {
    return aa(x);
}

WASM_EXPORT(SomeFunc)
int f(int x) {
    puts("OK");
    return strlen("OK\n") + swap(x + 2);
}

struct Ex{ int x; };

#if 1
WASM_EXPORT(SomeFunc2)
int f2(int x) {
    try {
        return swap(x + 1);
    } catch (int x) {
        return x;
    }
}
#endif

//FILE *const stdout = nullptr;

/*
#ifdef __GNUC__
void	longjmp (jmp_buf __jmpb, int __retval)
			__attribute__ ((__noreturn__));
#else
void	longjmp (jmp_buf __jmpb, int __retval);
#endif
int	setjmp (jmp_buf __jmpb);

*/

jmp_buf __jmpb;

#if 1
WASM_EXPORT(other33333333333333333333333)
int other33333333333333333333333(int x) {
    throw "a";
}
#endif

WASM_EXPORT(otherasdasdsad)
int otherasdasdsad(int x) {
    return setjmp(__jmpb);
}
