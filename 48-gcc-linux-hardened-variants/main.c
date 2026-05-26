#include <stdint.h>
#include <stdio.h>
#include <string.h>

#ifndef VICTIM_VARIANT
#define VICTIM_VARIANT "gcc_linux_unknown"
#endif

static uint32_t checksum(const char *text) {
    uint32_t hash = 2166136261u;
    for (size_t i = 0; text[i] != '\0'; ++i) {
        hash ^= (unsigned char)text[i];
        hash *= 16777619u;
    }
    return hash;
}

int main(void) {
    printf("GCC Linux hardened victim\n");
    printf("Variant: %s\n", VICTIM_VARIANT);
    printf("Checksum: 0x%08X\n", checksum(VICTIM_VARIANT));
    return 0;
}
