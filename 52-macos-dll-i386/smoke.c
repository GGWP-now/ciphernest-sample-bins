#include "macos_dll_i386.h"
#include <stdio.h>

int main(void) {
    printf("macOS i386 dylib smoke: %d\n", macos_dll_i386_transform(123));
    return 0;
}
