#include "macos_dll_i386.h"

int macos_dll_i386_transform(int value) {
    return (value * 17) ^ 0x5A5A;
}
