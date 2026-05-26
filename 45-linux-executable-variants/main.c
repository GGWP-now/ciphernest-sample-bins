#include <stdint.h>
#include <stdio.h>

static uint32_t fold(const char *text) {
    uint32_t value = 0x811C9DC5u;
    while (*text) {
        value ^= (unsigned char)*text++;
        value *= 0x01000193u;
    }
    return value;
}

int main(int argc, char **argv) {
    const char *variant = argc > 1 ? argv[1] : "linux";
    printf("Linux executable variant victim\n");
    printf("Variant: %s\n", variant);
    printf("Pointer bits: %u\n", (unsigned)(sizeof(void *) * 8u));
    printf("Checksum: 0x%08X\n", fold(variant));
    return 0;
}
