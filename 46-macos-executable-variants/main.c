#include <stdint.h>
#include <stdio.h>

static uint64_t mix(const char *text) {
    uint64_t hash = 1469598103934665603ull;
    while (*text) {
        hash ^= (unsigned char)*text++;
        hash *= 1099511628211ull;
    }
    return hash;
}

int main(int argc, char **argv) {
    const char *arch = argc > 1 ? argv[1] : "macos";
    printf("macOS executable variant victim\n");
    printf("Variant: %s\n", arch);
    printf("Pointer bits: %u\n", (unsigned)(sizeof(void *) * 8u));
    printf("Checksum: 0x%016llX\n", (unsigned long long)mix(arch));
    return 0;
}
