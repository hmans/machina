#include <stddef.h>
#include <stdlib.h>

extern "C" void *__cxa_allocate_exception(size_t thrown_size) {
    return malloc(thrown_size);
}

extern "C" __attribute__((noreturn)) void __cxa_throw(void *, void *, void (*)(void *)) {
    abort();
}
