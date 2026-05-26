#include "win32_dll_i386.h"

int win32_dll_i386_transform(int value) {
    return (value * 31) ^ 0x1357;
}
