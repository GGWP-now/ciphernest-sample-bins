#include <stdint.h>
#include <stdio.h>

static uint32_t scramble(uint32_t value) {
    for (unsigned i = 0; i < 24; ++i) {
        value = (value << 3) ^ (value >> 5) ^ (0x45D9F3Bu + i);
    }
    return value;
}

int main(void) {
    printf("Win32 EXE i386 victim\n");
    printf("Pointer bits: %u\n", (unsigned)(sizeof(void *) * 8u));
    printf("Checksum: 0x%08X\n", scramble(0x12345678u));
    return 0;
}
