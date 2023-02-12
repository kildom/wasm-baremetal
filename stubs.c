
#define WASM_EXPORT(name) \
    __attribute__((used)) \
    __attribute__((export_name(#name)))

#define WASM_IMPORT(name) \
    __attribute__((used)) \
    __attribute__((import_name(#name)))

int read(int file, char *ptr, int len) {
  return 0;
}

void* sbrk(int incr) {
    return 0;
}

WASM_IMPORT(wasm_putc)
void wasm_putc(int);

int write(int file, char *ptr, int len) {
  int todo;

  for (todo = 0; todo < len; todo++) {
    wasm_putc (*ptr++);
  }
  return len;
}

int close(int file) {
  return -1;
}
#include <sys/stat.h>
int fstat(int file, struct stat *st) {
  st->st_mode = S_IFCHR;
  return 0;
}

int isatty(int file) {
  return 1;
}

int lseek(int file, int ptr, int dir) {
  return 0;
}

void _exit(int code) {
    __builtin_unreachable();
}

#include <errno.h>
#undef errno
extern int errno;
int kill(int pid, int sig) {
  errno = EINVAL;
  return -1;
}

int getpid(void) {
  return 1;
}
