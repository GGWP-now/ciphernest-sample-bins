#include "win32_dll_i386.h"
#include <stdio.h>

int main(void) {
    printf("Win32 DLL i386 smoke: %d\n", win32_dll_i386_transform(77));
    return 0;
}
